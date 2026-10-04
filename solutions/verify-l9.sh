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
# NOT asserted, because each needs a model: a headless run and its exit codes,
# `--json` events, an SDK round trip, a schedule firing, and a webhook delivery.
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
boot_and_wait "$DSH_CHECKOUT" "$PROFILE" "$BOOTLOG" 'dsh web:|\[l1-hello\] apply' 60 "$PATCH" || true
if grep -qE 'did not activate' "$BOOTLOG"; then
  echo "FAIL  an entry did not activate:"
  grep -A3 'did not activate' "$BOOTLOG" | head -5
  echo "      A base-backed profile strands these in PENDING — apply to a web profile."
  failures=$((failures + 1))
else
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
  check "a successful turn exits 0" '0' "$hl_status"
  check "the final answer reaches stdout" 'mock response recovered' "$(cat "$HL_OUT")"

  HLJ_OUT="$(mktemp)"; HLJ_ERR="$(mktemp)"
  run_headless "$HLJ_OUT" "$HLJ_ERR" --json; hlj_status=$?
  json_types="$(json_types_of "$HLJ_OUT")"
  check "a --json turn still exits 0" '0' "$hlj_status"
  check "the --json stream opens with a session" 'session,' "$json_types,"
  check "the model text arrives as a text event" 'text' "$json_types"
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
  check "a failing turn exits 1" '1' "$hlf_status"
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

  check "the SDK run exits 0" '0' "$sdk_status"
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

    check "the tool-calling SDK run exits 0" '0' "$tool_status"
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

  check "a tool-call run exits 0" '0' "$tc_status"
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
if [[ "$failures" -eq 0 ]]; then
  echo "Lesson 9 verified: opt-in activation, schedule durability, DELIVERY (a due task resumes the"
  echo "session, the receipt is recorded, and the agent completes the scheduled work), a real headless"
  echo "turn (exit codes, stdout/stderr separation, the --json event stream including a real tool"
  echo "call and its correlated result) and a real SDK round trip that loads a PATCHES FILE and"
  echo "executes an earlier lesson's tool - all keyless."
  echo "Still needs a credential: a webhook delivery, which is a different transport."
else
  echo "$failures check(s) failed."; exit 1
fi
