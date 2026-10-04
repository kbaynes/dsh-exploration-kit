# Lesson 8 verification — orchestration primitives are mounted and the workflow
# logic is unit-tested without a model.
#
# Verifies:
#   1. the base bundle provides the subagent and workflow tools (no kit plugin needed)
#   2. the workflow's pure core has unit tests, and they pass
#   3. the workflow script is shaped for the tool (exports, not top-level code)
#
# Usage: bash solutions/verify-l8.sh /path/to/deepseek-harness
# Prereq: dsh plugin --profile kitdemo add link:<kit>/kit-plugins
#
# NOT asserted, because each needs a provider: a spawned child lacking parent context,
# a forked child inheriting the cut, a real fan-out, and the cost comparison.
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
SUBAGENT_ARGS='{"description":"fan-out check","prompt":"Report the answer in one short line."}'
MODEL_PATCH="$(mktemp)"
cat > "$MODEL_PATCH" <<'PATCH'
- id: agent-default-model
  config:
    provider: deepseek-official
    model: deepseek-flash
PATCH

# Count parent-linked child sessions before, so the assertion is about THIS run. The session log
# is compressed, so this decompresses recent sessions rather than grepping them.
BEFORE="$(count_recent_parent_linked_sessions 5)"

if start_mock_llm "$DSH_CHECKOUT" 8133 tool_call_success,success,success,success \
     --tool-name subagent --tool-arguments "$SUBAGENT_ARGS"; then
  FAN_OUT="$(mktemp)"; FAN_ERR="$(mktemp)"
  ( cd "$DSH_CHECKOUT" && DEEPSEEK_BASE_URL="$MOCK_LLM_BASE_URL" DEEPSEEK_API_KEY=mock-key \
      dsh --profile headless --patch "$MODEL_PATCH" "delegate the fan-out check" \
      >"$FAN_OUT" 2>"$FAN_ERR" )
  fan_status=$?
  stop_mock_llm
  AFTER="$(count_recent_parent_linked_sessions 5)"

  check "the delegating turn exits 0" '0' "$fan_status"
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
  rm -f "$FAN_OUT" "$FAN_ERR"
else
  echo "FAIL  could not start the mock LLM server"; failures=$((failures + 1))
fi
rm -f "$MODEL_PATCH"

echo
if [[ "$failures" -eq 0 ]]; then
  echo "Lesson 8 verified: orchestration primitives, fake-engine logic, fork heredity through"
  echo "derived state, and a real end-to-end delegation."
  echo "Still needs a credential: the monolith-versus-fan-out cost comparison, which needs real"
  echo "token usage (the mock reports none for scripted text)."
else
  echo "$failures check(s) failed."; exit 1
fi
