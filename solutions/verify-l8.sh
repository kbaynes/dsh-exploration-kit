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
if [[ "$failures" -eq 0 ]]; then
  echo "Lesson 8 wiring verified. Model-dependent claims are unverified; see VERIFIED.md."
else
  echo "$failures check(s) failed."; exit 1
fi
