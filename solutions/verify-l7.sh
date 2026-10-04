# Lesson 7 verification — opt-in session history and invariants compose and activate
#
# Verifies without a session:
#   1. the overlay overrides the existing session-query-sqlite row (not an insert)
#   2. the overlay inserts tool-session-query and the two invariants rows
#   3. every entry activates when the overlay is applied
#   4. the pinned optional package is actually installed in the profile
#
# Usage: bash solutions/verify-l7.sh /path/to/deepseek-harness
#
# Prereq (the lesson's step 1):
#   dsh plugin --profile kitdemo add link:<kit>/kit-plugins
#   dsh plugin --profile kitdemo add @deepseek-ai/dsh-tool-session-query@<dsh version>
#
# Everything this lesson claims is asserted. Phases 8 and 9 drive scripted TOOL CALLS, which need
# no key; phase 10 measures the tool's input-token cost and runs only when
# DSH_REAL_PROVIDER_PATCH names a real-provider patch (solutions/README.md).
set -uo pipefail

DSH_CHECKOUT="${1:-}"
PROFILE="${PROFILE:-kitdemo}"
VERSION="${DSH_VERSION:-0.2.0-rc.2}"
if [[ -z "$DSH_CHECKOUT" || ! -d "$DSH_CHECKOUT" ]]; then
  echo "usage: bash solutions/verify-l7.sh /path/to/deepseek-harness" >&2
  exit 2
fi
KIT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
source "$(dirname "${BASH_SOURCE[0]}")/lib-llm.sh"
PATCH="$KIT/solutions/l7.patch.yml"

failures=0
check() {
  if grep -qF -- "$2" <<<"$3"; then echo "PASS  $1"
  else echo "FAIL  $1"; echo "      expected: $2"; failures=$((failures + 1)); fi
}

echo "== 1-2. overlay shape =="
# The store row already exists, so it is an override; the tool row does not, so it is
# an insert. Getting this backwards is silently ineffective (ADR: patch semantics).
python3 - "$PATCH" <<'PY'
import re, sys, pathlib
text = pathlib.Path(sys.argv[1]).read_text()
top_ids = re.findall(r'^- id: (\S+)', text, re.M)
inserted = re.findall(r'^\s+- id: (\S+)', text, re.M)
ok = True
if 'session-query-sqlite' not in top_ids:
    print('FAIL  session-query-sqlite should be an override (top-level - id:)'); ok = False
else:
    print('PASS  session-query-sqlite overridden in place')
for name in ('tool-session-query', 'invariants', 'session-invariant'):
    if name not in inserted or name in top_ids:
        print(f'FAIL  {name} should be inserted (not an override)'); ok = False
    else:
        print(f'PASS  {name} inserted')
if 'openAt: startup' not in text:
    print('FAIL  openAt: startup is required; the web bundle ships openAt: never'); ok = False
else:
    print('PASS  the store is opened at startup')
sys.exit(0 if ok else 1)
PY
[[ $? -ne 0 ]] && failures=$((failures + 1))

echo
echo "== 3. the composition activates cleanly =="
# `timeout` is GNU coreutils and absent on macOS, so bound the boot by hand.
BOOTLOG="$(mktemp)"
# Readiness for a composition boot with no probe: the web app prints its URL, and a base-backed
# profile prints the kit plugin's own apply line instead. Waiting for only the former made this
# boot sit out the full 60s timeout on kitdemo — and then assert on a half-started log.
# The boot must REACH readiness. `|| true` here meant a boot that never started still produced an
# empty log, and every assertion below is about a string's ABSENCE — so the phase passed while
# measuring nothing. lib.sh names that hazard; this was an instance of it.
if boot_and_wait "$DSH_CHECKOUT" "$PROFILE" "$BOOTLOG" 'dsh web:|\[l1-hello\] apply' 60 "$PATCH"; then
  log="$(cat "$BOOTLOG")"
else
  echo "FAIL  the composition did not reach readiness, so nothing below was measured"
  log="$(cat "$BOOTLOG")"
  failures=$((failures + 1))
fi
rm -f "$BOOTLOG"
if grep -qE 'warning: [0-9]+ entr(y|ies) did not activate' <<<"$log"; then
  echo "FAIL  an entry did not activate:"
  grep -A2 'did not activate' <<<"$log" | head -4
  failures=$((failures + 1))
else
  echo "PASS  no activation warnings"
fi

# The overlay inserts the two invariant rows, so this boot ran the checks. A VIOLATION THROWS an
# InvariantError rather than logging one, so "no violation" is the absence of that error - the
# strongest claim available, since the service exposes `register` and no way to enumerate or run
# checks on demand.
if grep -q 'InvariantError' <<<"$log"; then
  echo "FAIL  the invariant checks reported a violation:"
  grep -B1 -A3 'InvariantError' <<<"$log" | head -6
  failures=$((failures + 1))
else
  # The honest claim, and the ledger says why: `ctx.invariants` exposes `register` and no way to
  # enumerate or run checks on demand, so this is "no violation was REPORTED".
  echo "PASS  no invariant violation was reported"
fi

echo
echo "== 4. the pinned optional package is installed =="
manifest="${DSH_HOME:-$HOME/.dsh}/profiles/$PROFILE/package.json"
if [[ -f "$manifest" ]]; then
  if grep -q 'dsh-tool-session-query' "$manifest"; then
    echo "PASS  installed in the profile manifest"
    if grep -q "@deepseek-ai/dsh-tool-session-query\": \"$VERSION\"" "$manifest"; then
      echo "PASS  pinned to $VERSION (npm's 'latest' tag is stale at 0.0.1-rc.1)"
    else
      echo "WARN  installed, but not obviously pinned to $VERSION — check for a stale tag resolution"
    fi
  else
    echo "FAIL  @deepseek-ai/dsh-tool-session-query is not installed; a row naming an"
    echo "      uninstalled package fails to import"
    failures=$((failures + 1))
  fi
else
  echo "SKIP  no profile manifest at $manifest"
fi

echo
echo "== 5. the query service itself, and where the tools register =="
# ctx.sessionQuery is the service behind the five model-facing tools. The tools add schema,
# prompt, and workspace authorization; the service is what a code caller uses, so the same
# store and reads can be exercised WITHOUT a model.
QUERY_LOG="$(mktemp)"
boot_and_wait "$DSH_CHECKOUT" "$PROFILE" "$QUERY_LOG" '\[l7-probe\] done' 60 \
  "$KIT/solutions/l7.patch.yml" "$KIT/solutions/l7.probe.patch.yml" || failures=$((failures + 1))

check "listSessions finds the session the probe created" \
  'mine found: true' "$(grep '\[l7-probe\]' "$QUERY_LOG")"
check "readSession returns the log including the marker" \
  'marker present: true' "$(grep '\[l7-probe\]' "$QUERY_LOG")"
# The POSITIVE cases: a first-party log-only event is readable back AND findable by a type
# filter, and the session is findable by full-text search. The caveat gets its own phase below,
# because asserting only the limitation would leave the working path untested.
# WHAT THESE FILTERS MAY LEGITIMATELY FIND, and what the earlier version got wrong.
#
# The check used to match only the printed LABEL — `filterEvents by type 'sandbox/mode':` — so
# `0 match(es)` satisfied it, and the ledger claimed "the type filter answers" for rounds without
# that ever being true. Requiring a non-zero count exposed it, and the SOURCE explains it:
# `extractSessionEventText` gives text to user/assistant messages, tool calls and results, todo
# writes and turns that ended with a reason; every other event contributes an empty string and
# `buildSessionEventSearchDocuments` omits it ("structural events are omitted"). A log-only
# STRUCTURAL event such as `sandbox/mode` therefore produces no document at all, and no filter can
# find it — by design.
#
# This session has no messages, so every filter here is legitimately empty. The POSITIVE case lives
# in phase 7, which asserts `searchSessions(<marker>): 1 hit(s)` on a session that HAS a message.
probe_out="$(grep '\[l7-probe\]' "$QUERY_LOG")"
check "a structural event yields no searchable document (0 matches)" \
  "filterEvents by type 'sandbox/mode': 0 match(es)" "$probe_out"
check "and the probe counts how many of its events are indexable at all" \
  'events the query layer can index (semantic-bearing): 0 of' "$probe_out"
check "text search cannot find a session by its ID (an ID is not semantic text)" \
  'searchSessions: 0 hit(s)' "$probe_out"
# What MUST keep working, so a change in either direction is visible.
check "the session is still listed (live-preferred)" 'mine found: true' "$probe_out"
check "and its log is still readable, with the appended event in it" \
  "appended 'sandbox/mode' is in the log: true" "$probe_out"
# Lesson 7 says the five tools register in a live ROOT AGENT's scope - a claim about
# agent.ctx rather than the global registry, and one that would silently stop being true.
check "all five lesson tools register in the agent scope" \
  'lesson tools in the AGENT scope: 5/5' "$(grep '\[l7-probe\]' "$QUERY_LOG")"
rm -f "$QUERY_LOG"

echo
echo "== 6. the CAVEAT: an invented event type, pinned rather than demonstrated =="
# The intended lesson is contrast with section 5: readSession returns an invented event while the
# query layer cannot see it. Section 5 now shows that the query layer sees NOTHING in this
# composition, so "the invented type is invisible" is true of every type and proves nothing here.
# The checks are kept as pinned observations, and the caveat's real evidence is elsewhere: an
# unknown event type makes the session log UNREADABLE after a restart (ADR-0024, where 37 sessions
# left behind by an earlier version of this probe broke search for a whole home).
#
# This phase DELIBERATELY creates such a session, so it removes it again.
POISON_LOG="$(mktemp)"
boot_and_wait "$DSH_CHECKOUT" "$PROFILE" "$POISON_LOG" '\[l7-probe\] done' 60 \
  "$KIT/solutions/l7.patch.yml" "$KIT/solutions/l7.poison.patch.yml" || failures=$((failures + 1))
poison_out="$(grep '\[l7-probe\]' "$POISON_LOG")"
check "readSession still returns the invented event" 'marker present: true' "$poison_out"
check "the type filter shows nothing for it (pinned; see section 5)" \
  "filterEvents by type 'l6/step': 0 match" "$poison_out"
check "and the text filter shows nothing (pinned, same reason)" 'filterEvents by text: 0 match' "$poison_out"
# Full-text search cannot see it either. (A session carrying an unknown type breaks search for the
# whole HOME when it is indexed at startup - demonstrated in ADR-0024 with 37 such sessions - but a
# single one created mid-run is simply absent from the results, which is what is deterministic.)
check "full-text search cannot find it either" 'searchSessions: 0 hit' "$poison_out"

# Clean up: remove the exact session this phase created, parsed from its own output.
poisoned="$(grep -o 'created session-l7-probe-[^ ,]*' "$POISON_LOG" | head -1 | awk '{print $2}')"
if [[ -n "$poisoned" ]]; then
  rm -rf "${DSH_HOME:-$HOME/.dsh}/sessions"/*/"$poisoned" "$HOME/.dsh/sessions"/*/"$poisoned" 2>/dev/null
  # Belt and braces: any probe session whose marker names an invented append is unreadable, so a
  # parse failure must not be able to leave one behind.
  for stale in $(ls -d "${DSH_HOME:-$HOME/.dsh}/sessions"/*/session-l7-probe-* 2>/dev/null); do
    rm -rf "$stale" 2>/dev/null
  done
  echo "PASS  removed the poisoned session it created ($poisoned)"
else
  echo "WARN  could not identify the poisoned session to remove"
fi
rm -f "$POISON_LOG"

echo
echo "== 7. a REAL turn: accounting, statistics, search and /compact =="
# A real turn against the repository's scriptable mock provider: the loop, log and accounting are
# real while the model output is scripted, which is all these claims need (ADR-0027).
MODEL_PATCH="$(mktemp)"
cat > "$MODEL_PATCH" <<'PATCH'
- id: agent-default-model
  config:
    provider: deepseek-official
    model: deepseek-flash
PATCH
TURN_LOG="$(mktemp)"
if start_mock_llm "$DSH_CHECKOUT" 8132 success; then
  # `exec` so `$!` is the harness rather than a subshell that would orphan it (ADR-0035).
  ( cd "$DSH_CHECKOUT" && exec env DEEPSEEK_BASE_URL="$MOCK_LLM_BASE_URL" DEEPSEEK_API_KEY=mock-key \
      dsh --profile "$PROFILE" --patch "$KIT/solutions/l7.patch.yml" \
      --patch "$MODEL_PATCH" --patch "$KIT/solutions/l7.turn.patch.yml" \
      --port 0 --no-open ) >"$TURN_LOG" 2>&1 &
  turnpid=$!
  waited=0
  while (( waited < 90 )); do
    grep -q '\[l7-turn\] done' "$TURN_LOG" 2>/dev/null && break
    sleep 1; waited=$((waited + 1))
  done
  kill "$turnpid" 2>/dev/null
  grace=0
  while kill -0 "$turnpid" 2>/dev/null && (( grace < 20 )); do sleep 0.5; grace=$((grace + 1)); done
  kill -9 "$turnpid" 2>/dev/null
  # Bounded: an unkillable harness must not block the check (ADR-0036).
  reap=0
  while kill -0 "$turnpid" 2>/dev/null && (( reap < 10 )); do sleep 0.5; reap=$((reap + 1)); done
  wait "$turnpid" 2>/dev/null
  stop_mock_llm

  turn_out="$(grep '\[l7-turn\]' "$TURN_LOG")"
  check "token accounting is exposed with its documented shape" '"totals":' "$turn_out"
  check "the accounting keys are the documented ones" 'uncachedInputTokens' "$turn_out"
  # The mock reports REAL usage, so the NUMBERS are asserted too: `input_tokens` is a constant 3,
  # and `output_tokens` is the character count of its scripted reply (23 for "mock response
  # recovered"). An earlier version of this phase asserted only the shape, on the false premise
  # that the mock reported no usage at all.
  check "the totals carry the provider's input tokens" '"uncachedInputTokens":3' "$turn_out"
  check "and a non-zero output count" '"outputTokens":23' "$turn_out"
  check "the statistics unit is absent in a base-backed profile" 'sessionStats (web-only): not mounted' "$turn_out"
  check "/compact settles as a command" '/compact outcome: {"kind":"success"' "$turn_out"
  # Lesson 7's remaining /compact claim: a MEASURABLE reduction, not just a settled command. After
  # a turn there is history to compact, and the command reports how much it removed.
  check "and reports a measurable reduction" 'Compacted' "$turn_out"
  check "naming the token estimate it removed" '(~' "$turn_out"

  # What the turn ACTUALLY did. An earlier version of this phase pinned a failure instead: turns
  # died at `turn/start` with 'cannot get property "toJSON" without inject', which was recorded as
  # an upstream defect for two rounds. It was the kit's own L5 pre-step listener stringifying a
  # live payload (ADR-0028). With that fixed these assertions measure the turn itself.
  check "the turn produced its own assistant message" "this turn's assistant messages: 1" "$turn_out"
  check "the turn completed rather than failed" '"kind":"completed"' "$turn_out"
  # The marker is unique to this run, so a hit proves the search found THIS session rather than
  # another mock run in the same harness home - the wrong-measurement trap from the first version.
  check "the trajectory is searchable and the hit is this session" 'the marker search found this session: true' "$turn_out"
else
  echo "FAIL  could not start the mock LLM server"; failures=$((failures + 1))
fi
rm -f "$MODEL_PATCH" "$TURN_LOG"

echo
echo "== 8. workspace authority: a model-driven call to ANOTHER workspace is refused =="
# The authority check lives in the tool EXECUTOR (`workspace-access.ts`), not in the query
# service, so it is only reachable through a tool call - which is why a model pack was thought to
# be required. It is not: the mock provider scripts the CALL (`tool_call_success`) while the
# harness executes the tool for real (ADR-0027). The probe creates a session under a DIFFERENT
# cwd, so the foreign target genuinely exists and a refusal cannot be confused with "not found".
AUTH_MODEL_PATCH="$(mktemp)"
cat > "$AUTH_MODEL_PATCH" <<'PATCH'
- id: agent-default-model
  config:
    provider: deepseek-official
    model: deepseek-flash
PATCH

# The mock's tool arguments are fixed BEFORE the harness boots, which is why the foreign session
# id is a constant the probe also uses.
run_auth() { # run_auth <port> <target-session-id> <outfile>
  local port="$1" target="$2" out="$3"
  if start_mock_llm "$DSH_CHECKOUT" "$port" tool_call_success,success \
      --tool-name session_trace --tool-arguments "{\"session_id\":\"$target\"}"; then
    export DEEPSEEK_BASE_URL="$MOCK_LLM_BASE_URL" DEEPSEEK_API_KEY=mock-key
    boot_and_wait "$DSH_CHECKOUT" "$PROFILE" "$out" '\[l7-auth\] done' 90 \
      "$KIT/solutions/l7.patch.yml" "$KIT/solutions/l7.auth.patch.yml" "$AUTH_MODEL_PATCH" \
      || failures=$((failures + 1))
    unset DEEPSEEK_BASE_URL DEEPSEEK_API_KEY
    stop_mock_llm
  else
    echo "FAIL  could not start the mock LLM server" >&2
    failures=$((failures + 1))
  fi
}

# Volatile identities differ between the two runs; the refusal must not.
normalize_auth() {
  sed -E 's/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/UUID/g' <<<"$1"
}

FOREIGN_LOG="$(mktemp)"
run_auth 8138 'session-l7-foreign-workspace' "$FOREIGN_LOG"
foreign_out="$(grep '\[l7-auth\]' "$FOREIGN_LOG")"
foreign_result="$(grep '\[l7-auth\] result 0:' "$FOREIGN_LOG")"

check "the cross-workspace target exists (created or resumed)" 'session-l7-foreign-workspace' "$foreign_out"
check "a model-driven tool call really executed" 'tool/result events: 1' "$foreign_out"
check "reading another workspace is REFUSED" 'SESSION_QUERY_TOOL_UNAUTHORIZED' "$foreign_out"
check "and the tool result is marked an error" '"isError":true' "$foreign_out"
check "the turn still completes (a refusal is a tool result, not a crash)" '"kind":"completed"' "$foreign_out"

MISSING_LOG="$(mktemp)"
run_auth 8139 'session-l7-does-not-exist-at-all' "$MISSING_LOG"
missing_out="$(grep '\[l7-auth\]' "$MISSING_LOG")"
missing_result="$(grep '\[l7-auth\] result 0:' "$MISSING_LOG")"

check "a MISSING target is refused too" 'SESSION_QUERY_TOOL_UNAUTHORIZED' "$missing_out"

# The lesson's real claim is that the two are INDISTINGUISHABLE. Asserting only that both are
# refusals would pass for two different error messages, so compare them.
if [[ -n "$foreign_result" && "$(normalize_auth "$foreign_result")" == "$(normalize_auth "$missing_result")" ]]; then
  echo "PASS  an existing foreign target and a nonexistent one are INDISTINGUISHABLE"
else
  echo "FAIL  the two refusals differ, so the target's existence leaks"
  echo "      foreign: $foreign_result"
  echo "      missing: $missing_result"
  failures=$((failures + 1))
fi
echo
echo "== 9. session_event_read returns an event as JSON, with its neighbours =="
# The claim is about tool OUTPUT, so the tool has to run. The mock scripts the call and the
# harness executes it (ADR-0027). `session_id` is optional on this tool, so the call targets the
# caller's own session - no id has to be known before the harness boots.
EVENT_LOG="$(mktemp)"
if start_mock_llm "$DSH_CHECKOUT" 8142 tool_call_success,success \
    --tool-name session_event_read --tool-arguments '{"seq":1,"before":2,"after":2}'; then
  export DEEPSEEK_BASE_URL="$MOCK_LLM_BASE_URL" DEEPSEEK_API_KEY=mock-key
  boot_and_wait "$DSH_CHECKOUT" "$PROFILE" "$EVENT_LOG" '\[l7-event\] done' 90 \
    "$KIT/solutions/l7.patch.yml" "$KIT/solutions/l7.event.patch.yml" "$AUTH_MODEL_PATCH" \
    || failures=$((failures + 1))
  unset DEEPSEEK_BASE_URL DEEPSEEK_API_KEY
  stop_mock_llm

  event_out="$(grep '\[l7-event\]' "$EVENT_LOG")"
  check "the read ran through the real tool pipeline" 'tool/result events: 1' "$event_out"
  check "the tool reported success" 'isError=false' "$event_out"
  check "the target event is returned as JSON" '"type": "sandbox/mode"' "$event_out"
  check "the JSON block is the target seq" 'Target event seq 1:' "$event_out"
  # The neighbours are the half that a shorter read would not show, so assert each direction.
  check "a BEFORE neighbour is summarised" 'Before: | - seq 0 | permission/preset' "$event_out"
  check "AFTER neighbours are summarised" 'After: | - seq 2 | approval/policy' "$event_out"
  check "and the turn completed" '"kind":"completed"' "$event_out"
  rm -f "$EVENT_LOG"
else
  echo "FAIL  could not start the mock LLM server"; failures=$((failures + 1))
fi
rm -f "$FOREIGN_LOG" "$MISSING_LOG" "$AUTH_MODEL_PATCH"

echo
echo "== 10. the token delta from mounting a tool (needs a REAL provider) =="
# Lesson 7's last unexecuted item: you can state the token delta caused by mounting
# `tool-session-query`. It cannot be measured against the mock, whose `input_tokens` is a constant
# 3 whatever the request contains - the delta is an INPUT-side effect, so it needs a provider that
# counts the real prompt.
#
# OPT-IN, because the repository must stay keyless by default: set DSH_REAL_PROVIDER_PATCH to a
# patch file that registers a real provider route (see VERIFIED.md for the OpenRouter one used
# here), and this phase runs; leave it unset and it skips.
#
# The comparison holds the composition still and toggles ONE row: both boots mount the store and the
# turn probe, and only `tool-session-query` differs. The same prompt is sent to the same model, so
# the difference in reported input tokens is the tool's schema.
if [[ -z "${DSH_REAL_PROVIDER_PATCH:-}" ]]; then
  echo "SKIP  set DSH_REAL_PROVIDER_PATCH to a real-provider patch to run this"
else
  OFF_PATCH="$(mktemp)"
  cat > "$OFF_PATCH" <<'PATCH'
- id: tool-session-query
  disabled: true
PATCH
  # The turn probe passes its OWN provider/model to `agents.create`, so a real run must set them on
  # the PROBE as well as on the default-model row. A probe that keeps its defaults sends the turn to
  # the mock route and fails with "no API key for provider route deepseek-official" - which is what
  # the first version of this phase reported, as zero tokens on both sides.
  REAL_MODEL_PATCH="$(mktemp)"
  cat > "$REAL_MODEL_PATCH" <<PATCH
- id: agent-default-model
  config:
    provider: ${DSH_REAL_PROVIDER:-openrouter}
    model: ${DSH_REAL_MODEL:-deepseek/deepseek-chat}

- id: l7-turn-probe
  config:
    enabled: true
    provider: ${DSH_REAL_PROVIDER:-openrouter}
    model: ${DSH_REAL_MODEL:-deepseek/deepseek-chat}
    # A prompt that cannot trigger a tool, so each run is exactly ONE step. A real model's totals
    # otherwise reflect how many steps it chose to take, and the first version of this phase
    # compared 14,533 against 39,201 tokens - a difference in trajectory, not in tool schema.
    prompt: "Do not use any tools. Reply with exactly one word: ready"
PATCH
  token_phase() { # token_phase <extra overlay|-> <logfile>
    local extra="$1" log="$2"
    local args=("$KIT/solutions/l7.patch.yml" "$KIT/solutions/l7.turn.patch.yml" "$DSH_REAL_PROVIDER_PATCH" "$REAL_MODEL_PATCH")
    [[ "$extra" != "-" ]] && args+=("$extra")
    boot_and_wait "$DSH_CHECKOUT" "$PROFILE" "$log" '\[l7-turn\] done' 120 "${args[@]}" \
      || failures=$((failures + 1))
  }
  WITH_LOG="$(mktemp)"; WITHOUT_LOG="$(mktemp)"
  token_phase - "$WITH_LOG"
  token_phase "$OFF_PATCH" "$WITHOUT_LOG"
  with_tokens="$(grep -o '"uncachedInputTokens":[0-9]*' "$WITH_LOG" | head -1 | grep -o '[0-9]*$')"
  without_tokens="$(grep -o '"uncachedInputTokens":[0-9]*' "$WITHOUT_LOG" | head -1 | grep -o '[0-9]*$')"
  echo "[l7-tokens] with tool-session-query:    ${with_tokens:-none} input tokens"
  echo "[l7-tokens] without tool-session-query: ${without_tokens:-none} input tokens"
  # The comparison is only meaningful at one step each: say so rather than assuming it.
  with_steps="$(grep -o "assistant messages: [0-9]*" "$WITH_LOG" | head -1 | grep -o '[0-9]*$')"
  without_steps="$(grep -o "assistant messages: [0-9]*" "$WITHOUT_LOG" | head -1 | grep -o '[0-9]*$')"
  echo "[l7-tokens] steps: with=${with_steps:-none} without=${without_steps:-none}"
  if [[ "$with_steps" != "1" || "$without_steps" != "1" ]]; then
    echo "FAIL  both runs must be a single step for the totals to be comparable"
    failures=$((failures + 1))
  elif [[ -n "$with_tokens" && -n "$without_tokens" && "$with_tokens" -gt "$without_tokens" ]]; then
    echo "PASS  mounting the tool adds $((with_tokens - without_tokens)) input tokens to the request"
  else
    echo "FAIL  expected the tool-mounted run to report MORE input tokens (with=${with_tokens:-none}, without=${without_tokens:-none})"
    failures=$((failures + 1))
  fi
  rm -f "$WITH_LOG" "$WITHOUT_LOG" "$OFF_PATCH" "$REAL_MODEL_PATCH"
fi

echo
if [[ "$failures" -eq 0 ]]; then
  echo "Lesson 7 verified: the store, the query service, the tool scope, the invented-type caveat"
  echo "(with cleanup), a COMPLETED turn with its own assistant message, the trajectory being"
  echo "searchable back to that session, the accounting shape, /compact, session_event_read's JSON"
  echo "with neighbours, and the workspace-authority refusal via REAL model-driven tool calls -"
  echo "including that a foreign target and a nonexistent one are indistinguishable."
else
  echo "$failures check(s) failed."; exit 1
fi
