# Lesson 9 verification — the opt-in automation packages compose and activate.
#
# Verifies:
#   1. the overlay inserts both rows
#   2. no shipped bundle already provides them (they are opt-in)
#   3. on a WEB-backed profile with both packages installed, nothing is left PENDING
#   4. the pinned versions are installed, not npm's stale `latest`
#
# Usage: bash solutions/verify-l9.sh /path/to/deepseek-harness
#
# Prereq (the lesson's step 4):
#   dsh plugin --profile web add @deepseek-ai/dsh-schedule@<dsh version>
#   dsh plugin --profile web add @deepseek-ai/dsh-webhook@<dsh version>
#
# Everything this lesson claims is asserted, and NONE of it needs a credential: activation,
# schedule durability, delivery that completes the scheduled work, the headless contract (exit
# codes, `--json` phases, a tool call and its correlated result), an SDK round trip that loads a
# patches file and runs an earlier lesson's tool, and a signed webhook delivery.
set -uo pipefail

DSH_CHECKOUT="${1:-}"
PROFILE="${PROFILE:-web}"
VERSION="${DSH_VERSION:-0.2.0-rc.2}"
if [[ -z "$DSH_CHECKOUT" || ! -d "$DSH_CHECKOUT" ]]; then
  echo "usage: bash solutions/verify-l9.sh /path/to/deepseek-harness" >&2
  exit 2
fi
KIT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
source "$(dirname "${BASH_SOURCE[0]}")/lib-llm.sh"
PATCH="$KIT/solutions/l9.patch.yml"
failures=0
check() {
  if grep -qF -- "$2" <<<"$3"; then echo "PASS  $1"
  else echo "FAIL  $1"; echo "      expected: $2"; failures=$((failures + 1)); fi
}

echo "== 1. the overlay inserts both rows =="
check "schedule inserted" "name: '@deepseek-ai/dsh-schedule'" "$(cat "$PATCH")"
check "webhook inserted" "name: '@deepseek-ai/dsh-webhook'" "$(cat "$PATCH")"

echo
echo "== 2. they are genuinely opt-in (no shipped bundle provides them) =="
found=0
for f in "$DSH_CHECKOUT"/packages/bundle/*/cordis.patch.yml; do
  grep -qE "name: '@deepseek-ai/dsh-(schedule|webhook)'" "$f" && found=1
done
if [[ "$found" -eq 0 ]]; then
  echo "PASS  neither is mounted by a shipped bundle"
else
  echo "FAIL  a shipped bundle already mounts one; the lesson's premise is wrong"
  failures=$((failures + 1))
fi

echo
echo "== 3. the composition activates cleanly on a web-backed profile =="
BOOTLOG="$(mktemp)"
# No probe on this boot. Accept either readiness signal, so the pattern survives a profile change:
# the web app prints its URL, and a base-backed profile prints the kit plugin's apply line.
# Readiness is REQUIRED: this phase's only assertions are about absence, so a boot that never
# started would pass them on an empty log (lib.sh names the hazard).
boot_ok=true
boot_and_wait "$DSH_CHECKOUT" "$PROFILE" "$BOOTLOG" 'dsh web:|\[l1-hello\] apply' 60 "$PATCH" || boot_ok=false
if [[ "$boot_ok" != "true" ]]; then
  echo "FAIL  the web composition did not reach readiness, so an empty log proves nothing"
  failures=$((failures + 1))
fi
if grep -qE 'did not activate' "$BOOTLOG"; then
  echo "FAIL  an entry did not activate:"
  grep -A3 'did not activate' "$BOOTLOG" | head -5
  echo "      A base-backed profile strands these in PENDING — apply to a web profile."
  failures=$((failures + 1))
elif [[ "$boot_ok" == "true" ]]; then
  # Only claim the absence when the boot actually happened.
  echo "PASS  no activation warnings on the '$PROFILE' profile"
fi
rm -f "$BOOTLOG"

echo
echo "== 4. the pinned versions are installed =="
manifest="${DSH_HOME:-$HOME/.dsh}/profiles/$PROFILE/package.json"
for pkg in dsh-schedule dsh-webhook; do
  if [[ -f "$manifest" ]] && grep -q "@deepseek-ai/$pkg\": \"$VERSION\"" "$manifest"; then
    echo "PASS  $pkg pinned to $VERSION"
  else
    echo "WARN  $pkg not obviously pinned to $VERSION in $manifest"
  fi
done

echo
echo "== 5. a scheduled task SURVIVES A RESTART =="
# Lesson 9 claims schedules are Host-owned and survive restarts. That needs two processes,
# like every other durability claim in this kit, and no model: creating a task is a service
# call. Delivery is the part that needs a provider - a due task resumes the session and the
# agent then works on it.
#
# The web profile does not surface a plugin's stdout, so the probe writes its result to a
# file named by L9_PROBE_OUT.
export L9_SESSION_ID="session-l9-verify-$RANDOM$RANDOM"
probe_phase() { # probe_phase <overlay> <outfile> <logfile>
  local overlay="$1" out="$2" log="$3"
  rm -f "$out"
  # The web profile does not surface plugin stdout, so the probe writes here as well.
  export L9_PROBE_OUT="$out"
  boot_and_wait "$DSH_CHECKOUT" "$PROFILE" "$log" '\[l9-probe\] done' 60 \
    "$KIT/solutions/l9.patch.yml" "$overlay" || failures=$((failures + 1))
}

OUT1="$(mktemp)"; OUT2="$(mktemp)"; LOG="$(mktemp)"
probe_phase "$KIT/solutions/l9.probe.patch.yml" "$OUT1" "$LOG"
check "phase one creates and lists a task" 'listed 1 task(s)' "$(cat "$OUT1")"

probe_phase "$KIT/solutions/l9.read.patch.yml" "$OUT2" "$LOG"
check "the task is still there in a FRESH process" \
  'after restart, tasks for the session: 1' "$(cat "$OUT2")"
check "deleting it works" 'after deleting: 0 task(s)' "$(cat "$OUT2")"
rm -f "$OUT1" "$OUT2" "$LOG"

echo
echo "== 6. a REAL headless turn, with no provider key =="
# Lesson 9's headless contract - exit codes, stdout vs stderr, and the --json stream - needs a
# PROVIDER, not a model pack: the repository's scriptable mock endpoint runs the real agent
# loop against scripted output.
#
# One behavior per mock instance, with `--repeat-last`: the mock consumes one scripted entry
# per REQUEST, and a turn does not necessarily make exactly one, so sequencing entries across
# runs couples the assertions to an implementation detail. A mock that always succeeds, then
# one that always fails, is deterministic.
MODEL_PATCH="$(mktemp)"
cat > "$MODEL_PATCH" <<'PATCH'
- id: agent-default-model
  config:
    provider: deepseek-official
    model: deepseek-flash
PATCH

run_headless() { # run_headless <outfile> <errfile> [extra args...]
  local out="$1" err="$2"; shift 2
  ( cd "$DSH_CHECKOUT" && DEEPSEEK_BASE_URL="$MOCK_LLM_BASE_URL" DEEPSEEK_API_KEY=mock-key \
      dsh --profile headless --patch "$MODEL_PATCH" "$@" "say hi" >"$out" 2>"$err" )
}

json_types_of() { # json_types_of <stream file>
  python3 -c "
import json,pathlib
types=[]
for line in pathlib.Path('$1').read_text().split(chr(10)):
    line=line.strip()
    if line:
        try: types.append(json.loads(line).get('type'))
        except Exception: pass
print(','.join(types))
"
}

echo
echo "-- a mock that always succeeds --"
if start_mock_llm "$DSH_CHECKOUT" 8129 success; then
  HL_OUT="$(mktemp)"; HL_ERR="$(mktemp)"
  run_headless "$HL_OUT" "$HL_ERR"; hl_status=$?
  check_exit "a successful turn exits 0" 0 "$hl_status"
  check "the final answer reaches stdout" 'mock response recovered' "$(cat "$HL_OUT")"

  HLJ_OUT="$(mktemp)"; HLJ_ERR="$(mktemp)"
  run_headless "$HLJ_OUT" "$HLJ_ERR" --json; hlj_status=$?
  json_types="$(json_types_of "$HLJ_OUT")"
  check_exit "a --json turn still exits 0" 0 "$hlj_status"
  check "the --json stream opens with a session" 'session,' "$json_types,"
  # `,text,` against `"$json_types,"`: a bare 'text' also matches a `context` type, so a stream
  # with no text event could pass.
  check "the model text arrives as a text event" ',text,' "$json_types,"
  # `turn_end` is a PHASE inside a `status` event, not an event type — asserting on the type
  # string tested nothing. The phases are the documented content of the stream.
  check "the stream carries turn_start" '"phase":"turn_start"' "$(cat "$HLJ_OUT")"
  check "the stream carries turn_end" '"phase":"turn_end"' "$(cat "$HLJ_OUT")"
  check "the stream closes with final" 'final' "$json_types"
  rm -f "$HL_OUT" "$HL_ERR" "$HLJ_OUT" "$HLJ_ERR"
  stop_mock_llm
else
  echo "FAIL  could not start the mock LLM server"; failures=$((failures + 1))
fi

echo
echo "-- a mock that always fails --"
if start_mock_llm "$DSH_CHECKOUT" 8130 server_error; then
  HLF_OUT="$(mktemp)"; HLF_ERR="$(mktemp)"
  run_headless "$HLF_OUT" "$HLF_ERR" --json; hlf_status=$?
  check_exit "a failing turn exits 1" 1 "$hlf_status"
  check "the failure is reported on stderr, not stdout" 'dsh:' "$(cat "$HLF_ERR")"
  check "the --json stream still terminates with final" 'final' "$(json_types_of "$HLF_OUT")"
  rm -f "$HLF_OUT" "$HLF_ERR"
  stop_mock_llm
else
  echo "FAIL  could not start the failing mock LLM server"; failures=$((failures + 1))
fi
rm -f "$MODEL_PATCH"

echo
echo "== 7. a real turn through the TypeScript SDK, keyless =="
# The SDK spawns its own runtime and drives a turn over JSON-RPC, so this exercises the integration
# path L9's step 2 describes rather than the CLI's.
#
# It gets its OWN harness home, and that is not tidiness: the sdk-minimal profile's persistence
# expects UNCOMPRESSED session logs, while the profiles the other checks use write `.jsonl.zstd`.
# Reusing one home fails with "uses .jsonl.zstd, but this backend is configured for compression
# none" - a real property of sharing a home across profiles, and a useful one for a reader to know.
SDK_HOME="$(mktemp -d)"
if start_mock_llm "$DSH_CHECKOUT" 8134 success; then
  SDK_OUT="$(cd "$DSH_CHECKOUT" && DSH_HOME="$SDK_HOME" \
      DEEPSEEK_BASE_URL="$MOCK_LLM_BASE_URL" DEEPSEEK_API_KEY=mock-key \
      node "$KIT/solutions/sdk-roundtrip.mjs" "$DSH_CHECKOUT" 2>&1)"
  sdk_status=$?
  stop_mock_llm

  check_exit "the SDK run exits 0" 0 "$sdk_status"
  check "the SDK receives the model's answer" 'finalResponse="mock response recovered"' "$SDK_OUT"
  check "the SDK reports the session it drove" 'sessionId=session-' "$SDK_OUT"
  # Notifications are the SDK's event feed; a turn that produced none would mean the stream is not
  # wired, even if the final text arrived.
  notifications="$(grep -o 'notifications=[0-9]*' <<<"$SDK_OUT" | head -1 | cut -d= -f2)"
  if [[ -n "$notifications" && "$notifications" -gt 0 ]]; then
    echo "PASS  the SDK observed session notifications ($notifications)"
  else
    echo "FAIL  the SDK reported no notifications (got: ${notifications:-none})"
    failures=$((failures + 1))
  fi
  # Its own home, so nothing here can disturb the shared verification home.
  if find "$SDK_HOME/sessions" -name 'session.v*.jsonl' 2>/dev/null | grep -q .; then
    echo "PASS  the SDK's home holds an UNCOMPRESSED session log (its profile's compression mode)"
  else
    echo "WARN  no uncompressed session log found in the SDK home"
  fi
else
  echo "FAIL  could not start the mock LLM server"; failures=$((failures + 1))
fi
rm -rf "$SDK_HOME"

echo
echo "-- and it loads a PATCHES FILE and executes an earlier lesson's tool --"
# Lesson 9's item 6: an SDK run that loads a patches file and executes a tool from an earlier
# lesson. The patch used here is Lesson 2's own override (`l2-wordcount` with `defaultUnit: chars`),
# and the mock scripts a `word_count` call that OMITS `unit` - so the unit that comes back proves
# whether the patch was loaded. The expected count is computed from the real file, so the result
# proves the tool read it rather than that a string was echoed.
#
# The profile needs the kit bundle in ITS home: the SDK spawns `dsh` with DSH_HOME here, and a
# fresh home has only the shipped `sdk-minimal` template. Installing a bundle creates the profile.
TOOL_HOME="$(mktemp -d)"
if DSH_HOME="$TOOL_HOME" dsh plugin --profile sdk-minimal add "link:$KIT/kit-plugins" >/dev/null 2>&1; then
  EXPECTED_CHARS="$(python3 -c "print(len(open('$KIT/README.md', encoding='utf-8').read()))")"
  if start_mock_llm "$DSH_CHECKOUT" 8144 tool_call_success,success,success \
       --tool-name word_count --tool-arguments "{\"path\":\"$KIT/README.md\"}"; then
    TOOL_OUT="$(cd "$DSH_CHECKOUT" && DSH_HOME="$TOOL_HOME" \
        DEEPSEEK_BASE_URL="$MOCK_LLM_BASE_URL" DEEPSEEK_API_KEY=mock-key \
        SDK_PATCH="$KIT/solutions/l2.override.patch.yml" \
        SDK_PROMPT="count the characters in the kit README" \
        node "$KIT/solutions/sdk-roundtrip.mjs" "$DSH_CHECKOUT" 2>&1)"
    tool_status=$?
    stop_mock_llm

    check_exit "the tool-calling SDK run exits 0" 0 "$tool_status"
    check "the SDK reports that it loaded a patches file" 'patches=1' "$TOOL_OUT"
    TOOL_LOG="$(find "$TOOL_HOME/sessions" -name 'session.v*.jsonl' 2>/dev/null | head -1)"
    tool_log="$(cat "$TOOL_LOG" 2>/dev/null)"
    check "an earlier lesson's tool RAN inside the SDK run" '"name":"word_count"' "$tool_log"
    # `chars` is the PATCHED unit; the plugin's own default is `words`. The count is the file's.
    check "the result comes from the real file, in the PATCHED unit" "\"text\":\"$EXPECTED_CHARS chars\"" "$tool_log"
    check "and the tool reported success" '"isError":false' "$tool_log"
  else
    echo "FAIL  could not start the mock LLM server"; failures=$((failures + 1))
  fi
else
  echo "FAIL  could not create the sdk-minimal profile in a fresh home"
  failures=$((failures + 1))
fi
rm -rf "$TOOL_HOME"

echo
echo "== 8. DELIVERY: a due task resumes the session and the agent DOES the work =="
# The half that needs a provider. Two details are load-bearing, and both were learned by failing:
#   - The session must have talked to the model BEFORE the task fires. Delivery resumes the session
#     and restores provider/model from the session's logged request header; a session that never
#     made a request resumes with no model at all and dies on
#     `prompt variable "{{model}}" has no value`. The probe's warm-up turn creates that header.
#   - The receipt is under `records` in ctx.schedule.history(), not `receipts`/`entries`.
FIRE_MODEL_PATCH="$(mktemp)"
cat > "$FIRE_MODEL_PATCH" <<'PATCH'
- id: agent-default-model
  config:
    provider: deepseek-official
    model: deepseek-flash
PATCH
if start_mock_llm "$DSH_CHECKOUT" 8136 success; then
  FIRE_LOG="$(mktemp)"
  # boot_and_wait runs `dsh` from the checkout, so the mock route has to be exported, not inlined.
  export DEEPSEEK_BASE_URL="$MOCK_LLM_BASE_URL" DEEPSEEK_API_KEY=mock-key
  boot_and_wait "$DSH_CHECKOUT" "$PROFILE" "$FIRE_LOG" '\[l9-fire\] done' 90 \
    "$KIT/solutions/l9.patch.yml" "$KIT/solutions/l9.fire.patch.yml" "$FIRE_MODEL_PATCH" \
    || failures=$((failures + 1))
  unset DEEPSEEK_BASE_URL DEEPSEEK_API_KEY
  stop_mock_llm

  fire_out="$(grep '\[l9-fire\]' "$FIRE_LOG")"
  check "a due task reports a DELIVERY receipt" 'deliveries reported: 1' "$fire_out"
  check "the receipt records when it was delivered" '"deliveredAt"' "$fire_out"
  check "the scheduled work ran: a second assistant message in the session" \
    'assistant messages in the session: 2' "$fire_out"
  check "and the delivered turn COMPLETED rather than failing" '"kind":"completed"' "$fire_out"
  rm -f "$FIRE_LOG"
else
  echo "FAIL  could not start the mock LLM server"; failures=$((failures + 1))
fi
rm -f "$FIRE_MODEL_PATCH"

echo
echo "== 9. the --json stream carries a TOOL CALL and its correlated result =="
# The lesson's remaining headless claim: a real tool call, not just text, appears in the stream.
# The mock scripts the CALL (`tool_call_success`) while the harness validates and dispatches the
# tool for real (ADR-0027).
#
# The RESULT's status is deliberately NOT asserted as "completed": whether a tool can actually run
# depends on the host. On this machine the sandbox backend is unusable ("sandbox-exec:
# sandbox_apply: Operation not permitted"), so the call is refused at execution - correctly, and
# the refusal is itself useful evidence. What is host-independent, and what the lesson claims, is
# the stream CONTRACT: a `tool_call` event naming the tool with its parsed input, and a
# `tool_result` event carrying the same callId.
# Its own model patch: the phase-6 `$MODEL_PATCH` is deleted well before this point, and pointing
# `--patch` at a removed file fails the boot with no obvious cause.
TOOLCALL_MODEL_PATCH="$(mktemp)"
cat > "$TOOLCALL_MODEL_PATCH" <<'PATCH'
- id: agent-default-model
  config:
    provider: deepseek-official
    model: deepseek-flash
PATCH
TOOLCALL_LOG="$(mktemp)"; TOOLCALL_ERR="$(mktemp)"
if start_mock_llm "$DSH_CHECKOUT" 8141 tool_call_success,success \
    --tool-name bash --tool-arguments '{"command":"echo l9-tool-call-ok","description":"prove a tool call reaches the JSON stream"}'; then
  # run_headless hardcodes $MODEL_PATCH, so drive the CLI directly with this phase's patch.
  ( cd "$DSH_CHECKOUT" && DEEPSEEK_BASE_URL="$MOCK_LLM_BASE_URL" DEEPSEEK_API_KEY=mock-key \
      dsh --profile headless --patch "$TOOLCALL_MODEL_PATCH" --json "use the bash tool" \
      >"$TOOLCALL_LOG" 2>"$TOOLCALL_ERR" )
  tc_status=$?
  stop_mock_llm

  check_exit "a tool-call run exits 0" 0 "$tc_status"
  check "the stream carries a tool_call event" '"type":"tool_call"' "$(cat "$TOOLCALL_LOG")"
  check "the event names the tool the model asked for" '"tool":"bash"' "$(cat "$TOOLCALL_LOG")"
  check "and carries the parsed input, not a raw string" '"input":{"command":"echo l9-tool-call-ok"' "$(cat "$TOOLCALL_LOG")"
  check "the stream carries the matching tool_result" '"type":"tool_result"' "$(cat "$TOOLCALL_LOG")"

  # Correlation is the substance: a result that cannot be tied to its call is not observable.
  call_ids="$(grep -o '"callId":"[^"]*"' "$TOOLCALL_LOG" | sort -u)"
  if [[ "$(wc -l <<<"$call_ids" | tr -d ' ')" == "1" && -n "$call_ids" ]]; then
    echo "PASS  the call and its result share one callId ($(tr -d '"' <<<"$call_ids" | cut -d: -f2))"
  else
    echo "FAIL  the call and result do not share a callId: $call_ids"
    failures=$((failures + 1))
  fi
  rm -f "$TOOLCALL_LOG" "$TOOLCALL_ERR"
else
  echo "FAIL  could not start the mock LLM server"; failures=$((failures + 1))
fi
rm -f "$TOOLCALL_MODEL_PATCH"

echo
echo "== 10. a SIGNED webhook delivery creates one Session - and a duplicate runs the rule again =="
# Lesson 9's last claim, and the one the ledger called credential-bound. It is not: the GitHub
# adapter takes a credential REFERENCE, and credential resolution reads the inherited process
# environment first, so the check supplies its own secret and signs its own payload. Nothing
# external is involved - no GitHub account, no tunnel, no network.
#
# The rule is registered by a probe, because `ctx.webhookRuntime` is a registry of TRUSTED
# PROGRAMMATIC rules; returning a `WebhookSessionRequest` makes the runtime perform its one
# built-in action, creating an ordinary root Session in a Web Workspace.
#
# The claim has two halves, and the second is the interesting one: `deliveryId` is recorded but is
# NEVER used for built-in deduplication, so a repeated delivery runs the rules AGAIN. The check
# therefore posts the same delivery id twice and asserts the session count goes 1, then 2.
# A FREE port, chosen at run time. A fixed port turns any stray harness from an earlier aborted run
# into `EADDRINUSE` on the next one, which reads like a webhook fault and is not one; and a stray
# that outlives SIGKILL (ADR-0036) cannot be cleaned up by hand.
WEBHOOK_PORT="$(node -e 'const s=require("node:net").createServer();s.listen(0,"127.0.0.1",()=>{process.stdout.write(String(s.address().port));s.close()})')"
WEBHOOK_WS="$(mktemp -d)"
export L9_WEBHOOK_SECRET="l9-local-secret-$RANDOM"
export L9_WEBHOOK_WORKSPACE="$WEBHOOK_WS"
WEBHOOK_MODEL_PATCH="$(mktemp)"
cat > "$WEBHOOK_MODEL_PATCH" <<'PATCH'
- id: agent-default-model
  config:
    provider: deepseek-official
    model: deepseek-flash
PATCH

# The latest count the probe reported. It counts DELIVERED sessions created since the probe started,
# so earlier runs sharing this home cannot inflate it.
webhook_count() {
  grep -o 'delivered sessions created since the probe started: [0-9]*' "$1" | tail -1 | grep -o '[0-9]*$'
}

# Wait for the count to reach an expected value, and PRINT how long it took. A POST returns 202 as
# soon as the delivery is ACCEPTED; the rule then creates the Session asynchronously, so a fixed
# sleep either flakes or wastes time - the same lesson as ADR-0032.
#
# The first delivery is slow for a reason worth knowing: creating a delivered Session needs the
# host's workspace and storage infrastructure, which is still initialising just after the route
# appears. In this composition the first Session took ~35s to become visible while later ones took
# under 5s, so the first wait is given a longer bound than the rest.
webhook_wait_for_count() { # webhook_wait_for_count <log> <expected> <timeout-seconds>
  local log="$1" expected="$2" timeout="${3:-30}" count=""
  # Wall-clock deadline: an iteration count inherits whatever `sleep` costs on the host.
  local deadline=$(( $(date +%s) + timeout ))
  while (( $(date +%s) < deadline )); do
    count="$(webhook_count "$log")"
    [[ "$count" == "$expected" ]] && break
    sleep 1
  done
  echo "${count:-}"
}

if start_mock_llm "$DSH_CHECKOUT" 8146 success; then
  WH_LOG="$(mktemp)"
  export DEEPSEEK_BASE_URL="$MOCK_LLM_BASE_URL" DEEPSEEK_API_KEY=mock-key
  # A fixed port is required here, and boot_and_wait cannot be used: this phase must POST to the
  # running server BETWEEN readiness and teardown. `exec` plus a bounded reap, for the reasons in
  # ADR-0035 and ADR-0036.
  ( cd "$DSH_CHECKOUT" && exec dsh --profile "$PROFILE" \
      --patch "$KIT/solutions/l9.patch.yml" --patch "$KIT/solutions/l9.webhook.patch.yml" \
      --patch "$WEBHOOK_MODEL_PATCH" --port "$WEBHOOK_PORT" --no-open ) >>"$WH_LOG" 2>&1 &
  wh_pid=$!
  # The teardown below is at the END of the phase, so anything that aborts earlier - `set -u` on a
  # typo did exactly this - leaves the harness holding a FIXED port, and the next run then fails
  # with `EADDRINUSE`, which reads like a webhook problem and is not one. Reap on ANY exit.
  trap 'kill -9 "$wh_pid" 2>/dev/null' EXIT
  waited=0
  while (( waited < 90 )); do grep -q '\[l9-webhook\] ACTIVE' "$WH_LOG" 2>/dev/null && break; sleep 1; waited=$((waited + 1)); done
  waited=0
  while (( waited < 30 )); do grep -q "127.0.0.1:$WEBHOOK_PORT" "$WH_LOG" 2>/dev/null && break; sleep 1; waited=$((waited + 1)); done

  check "the webhook adapter registered a route on the web server" "127.0.0.1:$WEBHOOK_PORT" "$(cat "$WH_LOG")"
  check "the trusted rule registered" 'rule registered for kind=github' "$(cat "$WH_LOG")"

  BODY='{"action":"opened","issue":{"number":1,"title":"l9 webhook delivery"}}'
  SIG="sha256=$(SECRET="$L9_WEBHOOK_SECRET" BODY="$BODY" node -e \
    'const c=require("node:crypto");process.stdout.write(c.createHmac("sha256",process.env.SECRET).update(process.env.BODY).digest("hex"))')"
  post_delivery() { # post_delivery <signature> <delivery-id> <outfile>
    curl -s -o "$3" -w '%{http_code}' -X POST "http://127.0.0.1:$WEBHOOK_PORT/hooks/l9-github" \
      -H 'content-type: application/json' -H "x-hub-signature-256: $1" \
      -H "x-github-delivery: $2" -H 'x-github-event: issues' --data "$BODY"
  }

  # Refusals are specific, and the difference is worth asserting rather than blurring: a request
  # with NO signature header is malformed (400), while a request that carries a WRONG signature is
  # authenticated-and-rejected (401). Provider authentication belongs to the adapter, not the rule.
  unsigned_status="$(curl -s -o /dev/null -w '%{http_code}' -X POST "http://127.0.0.1:$WEBHOOK_PORT/hooks/l9-github" \
      -H 'content-type: application/json' -H 'x-github-delivery: l9-unsigned' -H 'x-github-event: issues' --data "$BODY")"
  check "a delivery with NO signature is refused as malformed" '400' "$unsigned_status"
  forged_status="$(curl -s -o /dev/null -w '%{http_code}' -X POST "http://127.0.0.1:$WEBHOOK_PORT/hooks/l9-github" \
      -H 'content-type: application/json' -H 'x-hub-signature-256: sha256=0000' -H 'x-github-delivery: l9-forged' -H 'x-github-event: issues' --data "$BODY")"
  check "a delivery with a WRONG signature is refused as unauthenticated" '401' "$forged_status"

  # Let the host finish initialising before the first delivery: the route is registered before the
  # workspace and storage services are ready, and a delivery arriving too early waits on all of it.
  settle_deadline=$(( $(date +%s) + 60 ))
  while (( $(date +%s) < settle_deadline )); do
    [[ "$(grep -c 'created since the probe started' "$WH_LOG" 2>/dev/null)" -ge 3 ]] && break
    sleep 1
  done

  first_status="$(post_delivery "$SIG" 'l9-delivery-1' /dev/null)"
  check "a signed delivery is accepted" '202' "$first_status"
  wait_started="$(date +%s)"
  after_first="$(webhook_wait_for_count "$WH_LOG" 1 75)"
  echo "      (the first delivered Session became visible after $(( $(date +%s) - wait_started ))s)"
  if [[ "$after_first" == "1" ]]; then
    echo "PASS  the first delivery created exactly one Session"
  else
    echo "FAIL  expected 1 delivered Session after the first delivery; saw ${after_first:-none}"
    echo "      probe reported:"; grep '\[l9-webhook\]' "$WH_LOG" | tail -4 | sed 's/^/        /'
    echo "      response bodies:"; tail -2 "$WH_LOG" | sed 's/^/        /'
    failures=$((failures + 1))
  fi

  second_status="$(post_delivery "$SIG" 'l9-delivery-1' /dev/null)"
  check "the duplicate delivery is also accepted" '202' "$second_status"
  wait_started="$(date +%s)"
  after_second="$(webhook_wait_for_count "$WH_LOG" 2 30)"
  echo "      (the duplicate's Session became visible after $(( $(date +%s) - wait_started ))s)"
  if [[ "$after_second" == "2" ]]; then
    echo "PASS  a REPEATED delivery id runs the rule AGAIN (not deduplicated): 2 Sessions"
  else
    echo "FAIL  expected 2 delivered Sessions after the duplicate; saw ${after_second:-none}"
    echo "      probe reported:"; grep '\[l9-webhook\]' "$WH_LOG" | tail -4 | sed 's/^/        /'
    failures=$((failures + 1))
  fi
  check "and the rule reports both runs" 'rule ran for delivery=l9-delivery-1 source=l9-primary total=2' "$(cat "$WH_LOG")"

  # Teardown, bounded.
  kill "$wh_pid" 2>/dev/null
  grace=0
  while kill -0 "$wh_pid" 2>/dev/null && (( grace < 20 )); do sleep 0.5; grace=$((grace + 1)); done
  kill -9 "$wh_pid" 2>/dev/null
  reap=0
  while kill -0 "$wh_pid" 2>/dev/null && (( reap < 10 )); do sleep 0.5; reap=$((reap + 1)); done
  kill -0 "$wh_pid" 2>/dev/null && echo "      (webhook harness $wh_pid survived SIGKILL; continuing)" >&2
  trap - EXIT
  stop_mock_llm
  rm -f "$WH_LOG"
else
  echo "FAIL  could not start the mock LLM server"; failures=$((failures + 1))
fi
unset DEEPSEEK_BASE_URL DEEPSEEK_API_KEY L9_WEBHOOK_SECRET L9_WEBHOOK_WORKSPACE
rm -rf "$WEBHOOK_WS"; rm -f "$WEBHOOK_MODEL_PATCH"

echo
if [[ "$failures" -eq 0 ]]; then
  echo "Lesson 9 verified: opt-in activation, schedule durability, DELIVERY (a due task resumes the"
  echo "session, the receipt is recorded, and the agent completes the scheduled work), a real headless"
  echo "turn (exit codes, stdout/stderr separation, the --json event stream including a real tool"
  echo "call and its correlated result), a real SDK round trip that loads a PATCHES FILE and"
  echo "executes an earlier lesson's tool, and a SIGNED webhook delivery that creates one Session per"
  echo "delivery while a repeated delivery id runs the rule again - all keyless."
else
  echo "$failures check(s) failed."; exit 1
fi
