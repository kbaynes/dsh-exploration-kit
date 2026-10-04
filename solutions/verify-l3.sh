# Lesson 3 verification — service provision, PENDING stranding, HMR wiring
#
# Verifies without a harness boot:
#   1. the bundle carries the three l3 rows
#   2. the consumer declares the required service via `inject`
#   3. the diagnose plugin avoids the erased `FiberState` const enum
#   4. the diagnose row is scoped by config so it does not cry wolf
#
# Usage:  bash solutions/verify-l3.sh /path/to/deepseek-harness
# Prereq: dsh plugin --profile kitdemo add link:<kit>/kit-plugins
#
# Executed manually (quoted in the lesson and VERIFIED.md), not asserted here:
#   - the consumer prints a stamp when the provider is present
#   - disabling the provider strands it and the scoped sweep names it
#   - editing a plugin file reloads it live under the hmr overlay
set -uo pipefail

DSH_CHECKOUT="${1:-}"
PROFILE="${PROFILE:-kitdemo}"
if [[ -z "$DSH_CHECKOUT" || ! -d "$DSH_CHECKOUT" ]]; then
  echo "usage: bash solutions/verify-l3.sh /path/to/deepseek-harness" >&2
  exit 2
fi
KIT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

failures=0
check() {
  if grep -qF -- "$2" <<<"$3"; then echo "PASS  $1"
  else echo "FAIL  $1"; echo "      expected: $2"; failures=$((failures + 1)); fi
}

out="$(cd "$DSH_CHECKOUT" && dsh --profile "$PROFILE" --dump-config 2>&1)"
if [[ -z "$out" ]]; then
  echo "ERROR: dsh --profile $PROFILE --dump-config produced no output." >&2
  echo "       Install the kit bundle: dsh plugin --profile $PROFILE add link:<kit>/kit-plugins" >&2
  exit 3
fi

echo "== 1. bundle carries the L3 rows =="
check "service provider row" "id: l3-clock" "$out"
check "consumer row" "id: l3-uses-clock" "$out"
check "diagnose row" "id: l3-diagnose" "$out"
check "diagnose is scoped" "match: l3-" "$out"

echo
echo "== 2. consumer declares the dependency =="
if grep -q "inject = \['lessonClock'\]" "$KIT/kit-plugins/l3/uses-clock.js"; then
  echo "PASS  consumer injects lessonClock"
else
  echo "FAIL  consumer does not declare inject"; failures=$((failures + 1))
fi

echo
echo "== 3. diagnose avoids the erased const enum =="
# Only a real import/use matters; the comment explaining the trap necessarily names it.
if grep -vE '^\s*(//|\*|/\*)' "$KIT/kit-plugins/l3/diagnose.js" | grep -q 'FiberState'; then
  echo "FAIL  diagnose references FiberState, which is not a runtime export"
  failures=$((failures + 1))
else
  echo "PASS  no FiberState runtime reference"
fi
if grep -q 'fiber.state === 0' "$KIT/kit-plugins/l3/diagnose.js"; then
  echo "PASS  compares the stable numeric state"
else
  echo "FAIL  numeric state comparison not found"; failures=$((failures + 1))
fi

echo
echo "== 4. diagnose uses a real schema =="
if grep -q '@deepseek-ai/schemastery' "$KIT/kit-plugins/l3/diagnose.js"; then
  echo "PASS  Config uses Schemastery"
else
  echo "FAIL  Config is not a Standard Schema"; failures=$((failures + 1))
fi

echo
if [[ "$failures" -eq 0 ]]; then
  echo "Lesson 3 wiring verified. Behavioural claims were executed manually;"
  echo "see VERIFIED.md for the quoted output."
else
  echo "$failures check(s) failed."; exit 1
fi
