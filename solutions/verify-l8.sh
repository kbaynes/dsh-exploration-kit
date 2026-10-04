# Lesson 8 verification — orchestration primitives, the workflow's pure core, fork heredity,
# a real delegation, a measured cost comparison, and (opt-in, with a real provider) the two
# claims that need model judgement.
#
# Verifies:
#   1. the base bundle provides the subagent and workflow tools (no kit plugin needed)
#   2. the workflow's pure core has unit tests, and they pass
#   3. the workflow script is shaped for the tool (exports, not top-level code)
#   4. fork heredity, through derived state
#   5. a real end-to-end delegation against the scriptable mock, with its child's turn closed
#   6. the monolith-versus-fan-out token comparison
#   7. OPT-IN: a spawned child does not share the parent's conversation
#   8. OPT-IN: send_message reaches a live child, and interrupt_agent stops it
#
# Usage: bash solutions/verify-l8.sh /path/to/deepseek-harness
# Prereq: dsh plugin --profile kitdemo add link:<kit>/kit-plugins
#
# Phases 7 and 8 need a REAL provider and print SKIP unless DSH_REAL_PROVIDER_PATCH names a patch
# that registers one; solutions/README.md has the recipe.
set -uo pipefail

DSH_CHECKOUT="${1:-}"
PROFILE="${PROFILE:-kitdemo}"
if [[ -z "$DSH_CHECKOUT" || ! -d "$DSH_CHECKOUT" ]]; then
  echo "usage: bash solutions/verify-l8.sh /path/to/deepseek-harness" >&2
  exit 2
fi
KIT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
source "$(dirname "${BASH_SOURCE[0]}")/lib-llm.sh"
failures=0
check() {
  if grep -qF -- "$2" <<<"$3"; then echo "PASS  $1"
  else echo "FAIL  $1"; echo "      expected: $2"; failures=$((failures + 1)); fi
}

echo "== 1. orchestration primitives come from the base bundle =="
base="$DSH_CHECKOUT/packages/bundle/base/cordis.patch.yml"
check "subagent tool mounted" "id: tool-subagent" "$(cat "$base")"
check "workflow tool mounted" "id: tool-workflow" "$(cat "$base")"
check "workflow provider configured" "id: workflow-ptc" "$(cat "$base")"

out="$(cd "$DSH_CHECKOUT" && dsh --profile "$PROFILE" --dump-config 2>&1)"
check "subagent row composes" "id: tool-subagent" "$out"
check "workflow row composes" "id: tool-workflow" "$out"
check "fork row composes" "id: tool-subagent-fork" "$out"

echo
echo "== 2. the workflow's pure core is unit-tested =="
if (cd "$KIT/kit-plugins" && node --test l8/audit-workflow.test.mjs >/dev/null 2>&1); then
  echo "PASS  l8/audit-workflow.test.mjs passes"
else
  echo "FAIL  the workflow unit tests do not pass"; failures=$((failures + 1))
fi

echo
echo "== 3. the workflow script is shaped for the tool =="
wf="$KIT/kit-plugins/l8/audit-workflow.js"
check "exports the result schema" "export const capabilityRowsSchema" "$(cat "$wf")"
check "exports a normalize step" "export function normalizeResults" "$(cat "$wf")"
check "schema forbids extra properties" "additionalProperties: false" "$(cat "$wf")"

echo
echo "== 4. fork heredity: a seeded child inherits the cut =="
# Lesson 8 claims a forked child is seeded from its parent, records the lineage, and exposes
# the exact inherited prefix so a projection reads the cut rather than inferring it. All of
# that is testable WITHOUT a model - creating sessions is not a model call.
#
# l7.patch.yml is applied too: the probe reads the parent's log through ctx.sessionQuery, and
# that overlay is what opens the store.
FORK_LOG="$(mktemp)"
boot_and_wait "$DSH_CHECKOUT" "$PROFILE" "$FORK_LOG" '\[l8-probe\] done' 60 \
  "$KIT/solutions/l7.patch.yml" "$KIT/solutions/l8.probe.patch.yml" || failures=$((failures + 1))

probe_out="$(grep '\[l8-probe\]' "$FORK_LOG")"
check "the child records the exact inherited prefix" 'child inheritedEventCount: 5' "$probe_out"
check "the child header marks it as seeded" 'child header isSeeded: true' "$probe_out"
check "the child records its parent" 'child parentSession: session-l8-parent-' "$probe_out"
# Heredity observed through DERIVED state, not just the header: Lesson 6's projection folds
# `sandbox/mode`, and the child reports the mode carried by the inherited event.
check "the child's projection reflects the inherited event" 'child projection: {"mode":"read-only"}' "$probe_out"
rm -f "$FORK_LOG"

echo
echo "== 5. a REAL delegation, end to end, with no provider key =="
# The lesson's central claim is that a delegation runs a CHILD agent with its own context. That
# needs a provider, and the repository ships a scriptable one (ADR-0027): the mock is told to
# answer the first request with a `subagent` tool call, and every later request with plain text.
# What follows is a genuine fan-out - the parent calls the tool, a child runs its own turn, the
# child reports back, the parent finishes - visible in the mock's request count and in the session
# log's parent link.
# `run_in_background: false` is LOAD-BEARING, not decoration. The base bundle's `subagent` uses the
# `continuable` background mode, and the tool's own default is therefore to schedule the child and
# return immediately ("Continuable work is independently scheduled unless the caller explicitly
# needs the result before its next action"). In a headless run the process then exits while the
# child is still working, and the child's session is left open with no `assistant/message` and no
# `turn/end` - which is exactly the stall this check used to report as an intermittent harness
# problem. Asking for the result in the same turn makes the child finish deterministically.
SUBAGENT_ARGS='{"description":"fan-out check","prompt":"Report the answer in one short line.","run_in_background":false}'
MODEL_PATCH="$(mktemp)"
cat > "$MODEL_PATCH" <<'PATCH'
- id: agent-default-model
  config:
    provider: deepseek-official
    model: deepseek-flash
PATCH

# One fan-out attempt: run the delegation, then read the parent's usage from the stream and the
# child's from its own log. Sets FAN_PARENT / FAN_CHILD / parent_session.
#
# It is a FUNCTION so the cost phase can retry, which is now a guard: the child completes
# deterministically because the scripted call asks for its result in the same turn.
#   fanout_once <port> <stream-file>
fanout_once() {
  local port="$1" out="$2"
  FAN_PARENT=0; FAN_CHILD=0; parent_session=""
  if ! start_mock_llm "$DSH_CHECKOUT" "$port" tool_call_success,success,success,success \
       --tool-name subagent --tool-arguments "$SUBAGENT_ARGS"; then
    return 1
  fi
  ( cd "$DSH_CHECKOUT" && DEEPSEEK_BASE_URL="$MOCK_LLM_BASE_URL" DEEPSEEK_API_KEY=mock-key \
      dsh --profile headless --patch "$MODEL_PATCH" --json "delegate the fan-out check" \
      >"$out" 2>/dev/null )
  local status=$?
  stop_mock_llm
  parent_session="$(grep -o '"type":"session","sessionId":"[^"]*"' "$out" | head -1 | sed 's/.*"sessionId":"//; s/"$//')"
  FAN_PARENT="$(sum_stream_usage "$out")"
  if [[ -n "$parent_session" ]]; then
    IFS=$'\t' read -r FAN_CHILD child_log <<<"$(await_child_usage "$parent_session" 25)"
  fi
  return "$status"
}

# Count parent-linked child sessions before, so the assertion is about THIS run. The session log
# is compressed, so this decompresses recent sessions rather than grepping them.
BEFORE="$(count_recent_parent_linked_sessions 5)"

FAN_OUT="$(mktemp)"; FAN_ERR="$(mktemp)"
# `--json` as well as the human answer: the stream carries the parent's per-step token usage,
# which is what makes the cost comparison in phase 6 measurable.
fanout_once 8133 "$FAN_OUT"
fan_status=$?
if [[ "$fan_status" -eq 0 || -s "$FAN_OUT" ]]; then
  AFTER="$(count_recent_parent_linked_sessions 5)"

  check_exit "the delegating turn exits 0" 0 "$fan_status"
  check "the parent prints the model's answer" 'mock response recovered' "$(cat "$FAN_OUT")"
  # Three requests: the parent's tool call, the CHILD's own turn, then the parent's final answer.
  # `grep -c` PRINTS 0 when there are no matches (and exits 1), so `|| echo 0` appends a second 0 -
  # which turns the value into "0\n0" and makes the arithmetic test below a syntax error.
  requests="$(grep -c '"type":"request"' "$MOCK_LLM_LOG" 2>/dev/null)"
  requests="${requests:-0}"
  if [[ "$requests" -ge 3 ]]; then
    echo "PASS  a child agent ran its own turn (model requests served: $requests)"
  else
    echo "FAIL  expected at least 3 model requests (parent call, child turn, parent finish); saw $requests"
    failures=$((failures + 1))
  fi
  # And the child is durably recorded with a link to its parent.
  if [[ "$AFTER" -gt "$BEFORE" ]]; then
    echo "PASS  a child session was recorded with a parent link ($BEFORE -> $AFTER)"
  else
    echo "FAIL  no parent-linked child session appeared ($BEFORE -> $AFTER)"
    failures=$((failures + 1))
  fi
  # ... and the child's turn CLOSED. Counting model requests alone was too weak: the count was
  # satisfied by a child that was spawned and then abandoned when the process exited. A child with
  # recorded usage has an `assistant/message` and a `turn/end`.
  if [[ "${FAN_CHILD:-0}" -gt 0 ]]; then
    echo "PASS  the child's turn CLOSED, with usage recorded in its own session"
  else
    echo "FAIL  the child's turn did not close (no usage in its session)"
    failures=$((failures + 1))
  fi

  # The fan-out's cost is the sum across the sessions it created: the parent's own steps from the
  # stream, and the child's turn from its own log.
  echo "[l8-cost] parent session: ${parent_session:-unknown}"
  echo "[l8-cost] fan-out parent tokens: $FAN_PARENT"
  # The child's share is reported by phase 6, AFTER any retry: printing it here would show 0 for a
  # run whose child did not complete, next to a total that then includes a later attempt's child.
  if [[ "$FAN_CHILD" -gt 0 ]]; then
    echo "[l8-cost] fan-out child tokens: $FAN_CHILD"
  else
    echo "[l8-cost] fan-out child tokens: (child turn incomplete; phase 6 retries)"
  fi
  rm -f "$FAN_OUT" "$FAN_ERR"
else
  echo "FAIL  could not start the mock LLM server"; failures=$((failures + 1))
fi

echo
echo "== 6. the COST COMPARISON: one turn vs a fan-out, measured in tokens =="
# The lesson asks the reader to run the same task monolithically and as a fan-out and compare token
# totals. That is measurable because the mock reports real usage and the harness records it per
# session. What is NOT claimed: that the numbers are economically realistic. The mock's input is a
# constant 3 tokens and its output is the character count of a scripted reply, so the comparison
# shows the harness ATTRIBUTING cost correctly across agents - the magnitude still needs a real
# provider.
MONO_TOKENS=0
if start_mock_llm "$DSH_CHECKOUT" 8135 success; then
  MONO_OUT="$(mktemp)"; MONO_ERR="$(mktemp)"
  ( cd "$DSH_CHECKOUT" && DEEPSEEK_BASE_URL="$MOCK_LLM_BASE_URL" DEEPSEEK_API_KEY=mock-key \
      dsh --profile headless --patch "$MODEL_PATCH" --json "do the check in one turn" \
      >"$MONO_OUT" 2>"$MONO_ERR" )
  mono_status=$?
  stop_mock_llm
  MONO_TOKENS="$(sum_stream_usage "$MONO_OUT")"
  check_exit "the monolith run exits 0" 0 "$mono_status"
  rm -f "$MONO_OUT" "$MONO_ERR"
else
  echo "FAIL  could not start the mock LLM server"; failures=$((failures + 1))
fi

# Retry the fan-out if the child's turn did not complete. The cause is now KNOWN - a background
# child outliving a headless process - and `run_in_background: false` above prevents it, so this is
# a guard rather than the mechanism. It is still reported, because a check that quietly retries
# until it is green hides exactly the signal that would tell us the fix stopped working
# (ADR-0034).
fan_attempts=1
while [[ "${FAN_CHILD:-0}" -eq 0 && "$fan_attempts" -lt 4 ]]; do
  fan_attempts=$((fan_attempts + 1))
  echo "[l8-cost] child did not complete; retrying the fan-out (attempt $fan_attempts)"
  : > "$FAN_OUT"
  fanout_once $((8133 + fan_attempts)) "$FAN_OUT"
done
echo "[l8-cost] fan-out attempts needed: $fan_attempts"

fan_total=$(( FAN_PARENT + FAN_CHILD ))
echo "[l8-cost] fan-out child tokens: $FAN_CHILD"
echo "[l8-cost] monolith tokens: $MONO_TOKENS"
echo "[l8-cost] fan-out total tokens: $fan_total"

# Each half has to be real for the comparison to mean anything: a zero would make every sum
# vacuously small.
if [[ "$MONO_TOKENS" -gt 0 ]]; then
  echo "PASS  the monolith's tokens are recorded and non-zero ($MONO_TOKENS)"
else
  echo "FAIL  the monolith recorded no tokens ($MONO_TOKENS)"; failures=$((failures + 1))
fi
if [[ "$FAN_CHILD" -gt 0 ]]; then
  echo "PASS  the CHILD's tokens are attributed to the child's own session ($FAN_CHILD)"
else
  echo "FAIL  the child's turn recorded no tokens ($FAN_CHILD)"; failures=$((failures + 1))
fi
if [[ "$fan_total" -gt "$MONO_TOKENS" ]]; then
  echo "PASS  the fan-out costs more tokens than one turn ($fan_total > $MONO_TOKENS)"
else
  echo "FAIL  expected the fan-out to cost more ($fan_total vs $MONO_TOKENS)"
  failures=$((failures + 1))
fi

echo
if [[ "$failures" -eq 0 ]]; then
  echo "Lesson 8 verified: orchestration primitives, fake-engine logic, fork heredity through"
  echo "derived state, a real end-to-end delegation, and a measured monolith-versus-fan-out cost"
  echo "comparison."
  echo "The MAGNITUDE of that comparison is not a harness property: under the mock the input is a"
  echo "constant 3 tokens and the output is a scripted reply's character count, so the totals prove"
  echo "correct attribution across agents rather than a realistic price. A realistic total is a"
  echo "property of a provider's price list, not of anything this repository can assert."
  echo "Phases 7 and 8 need a REAL provider and print SKIP without DSH_REAL_PROVIDER_PATCH; see"
  echo "solutions/README.md for the patch that runs them."
else
  echo "$failures check(s) failed."; exit 1
fi
rm -f "$MODEL_PATCH"

echo
echo "== 7. a spawned child does NOT share the parent's context (needs a REAL provider) =="
# Lesson 8's item 4. The mock cannot show this - scripted output does not depend on what the child
# was given - which is why it was recorded as provider-bound.
#
# OPT-IN, like lesson 7's token phase: set DSH_REAL_PROVIDER_PATCH to a patch registering a real
# route. The assertion is mechanical rather than judgemental: a passphrase goes into the parent, the
# child is asked for it, and the check asserts the passphrase is ABSENT from the child's session log
# while present in the parent's. What the child SAYS is printed for the reader, not asserted.
if [[ -z "${DSH_REAL_PROVIDER_PATCH:-}" ]]; then
  echo "SKIP  set DSH_REAL_PROVIDER_PATCH to a real-provider patch to run this"
else
  REAL_MODEL_PATCH="$(mktemp)"
  cat > "$REAL_MODEL_PATCH" <<PATCH
- id: agent-default-model
  config:
    provider: ${DSH_REAL_PROVIDER:-openrouter}
    model: ${DSH_REAL_MODEL:-deepseek/deepseek-chat}
PATCH
  CONTEXT_LOG="$(mktemp)"
  boot_and_wait "$DSH_CHECKOUT" "$PROFILE" "$CONTEXT_LOG" '\[l8-context\] done' 180 \
    "$KIT/solutions/l7.patch.yml" "$DSH_REAL_PROVIDER_PATCH" "$REAL_MODEL_PATCH" \
    "$KIT/solutions/l8.context.patch.yml" || failures=$((failures + 1))
  ctx_out="$(grep '\[l8-context\]' "$CONTEXT_LOG")"
  check "the passphrase reaches the parent's own conversation" "the parent's own log contains the passphrase: true" "$ctx_out"
  check "the delegation created a child session" 'child session: ' "$ctx_out"
  check "the child's session is a real conversation" "the child's log is non-empty: true" "$ctx_out"
  check "the child's turn closed" "the child's turn closed: true" "$ctx_out"
  # The claim: the parent's passphrase is not in the child's conversation.
  check "the child does NOT have the parent's passphrase" "the child's log contains the passphrase: false" "$ctx_out"
  check "and the child says it was not told" "the child replied NOT-TOLD: true" "$ctx_out"
  rm -f "$CONTEXT_LOG" "$REAL_MODEL_PATCH"
fi

echo
echo "== 8. send_message reaches a LIVE child, and interrupt_agent stops it (needs a REAL provider) =="
# Lesson 8's item 7, and the only claim in the lesson that needs the MODEL to choose: the child's
# session id exists only after the spawn, so a scripted call could never name it. OPT-IN via
# DSH_REAL_PROVIDER_PATCH, like the phases above.
if [[ -z "${DSH_REAL_PROVIDER_PATCH:-}" ]]; then
  echo "SKIP  set DSH_REAL_PROVIDER_PATCH to a real-provider patch to run this"
else
  CONTROL_MODEL_PATCH="$(mktemp)"
  cat > "$CONTROL_MODEL_PATCH" <<PATCH
- id: agent-default-model
  config:
    provider: ${DSH_REAL_PROVIDER:-openrouter}
    model: ${DSH_REAL_MODEL:-deepseek/deepseek-chat}
PATCH
  CONTROL_LOG="$(mktemp)"
  boot_and_wait "$DSH_CHECKOUT" "$PROFILE" "$CONTROL_LOG" '\[l8-control\] done' 240 \
    "$KIT/solutions/l7.patch.yml" "$DSH_REAL_PROVIDER_PATCH" "$CONTROL_MODEL_PATCH" \
    "$KIT/solutions/l8.control.patch.yml" || failures=$((failures + 1))
  control_out="$(grep '\[l8-control\]' "$CONTROL_LOG")"
  # The calls are counted structurally: a substring search is satisfied by the tool CATALOGUE in the
  # request header, which lists every tool name.
  check "the model called subagent" "the parent called subagent: true" "$control_out"
  check "the model called list_agents" "the parent called list_agents: true" "$control_out"
  check "the model called send_message" "the parent called send_message: true" "$control_out"
  check "the model called interrupt_agent" "the parent called interrupt_agent: true" "$control_out"
  check "a live child session existed" "the delegation created a child session: true" "$control_out"
  check "the message REACHED the live child" "the message reached the child: true" "$control_out"
  check "the child's turn closed" "the child's turn closed: true" "$control_out"
  check "and it was INTERRUPTED rather than completing" "the child was interrupted rather than completing: true" "$control_out"
  rm -f "$CONTROL_LOG" "$CONTROL_MODEL_PATCH"
fi
