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
echo "== 5. plugin_manager's view of the tree =="
# Lesson 3 says plugin_manager can list and toggle rows. It can - but NOT rows contributed by
# a bundle, which is where this lesson's rows live. Asserted because the lesson's original
# instruction ("disable l3-uses-clock from plugin_manager") cannot work at all.
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
MANAGER_LOG="$(mktemp)"
boot_and_wait "$DSH_CHECKOUT" "$PROFILE" "$MANAGER_LOG" '\[l3-probe\] done' 60 \
  "$KIT/solutions/l3.probe.patch.yml" || failures=$((failures + 1))
manager_out="$(grep '\[l3-probe\]' "$MANAGER_LOG")"

check "the manager lists the profile's rows" 'row(s) total' "$manager_out"
check "it lists the kit bundle" 'kit bundle present: true' "$manager_out"
check "it does NOT see the kit's own rows" 'ids containing "l3-uses-clock": (none)' "$manager_out"
check "toggling such a row fails as an unknown target" '"application":"failed"' "$manager_out"
rm -f "$MANAGER_LOG"

echo
echo "== 6. service ISOLATION: two groups, two instances of one service name =="
# The lesson's last exploration. Two groups isolate `lessonEcho` and each mounts its own
# provider and consumer; if isolation works each consumer sees its own provider.
ISO_LOG="$(mktemp)"
boot_and_wait "$DSH_CHECKOUT" "$PROFILE" "$ISO_LOG" '\[l3-echo\] group B' 60 \
  "$KIT/solutions/l3.isolate.patch.yml" || failures=$((failures + 1))
check "group A sees its own provider" 'group A sees its own provider' "$(cat "$ISO_LOG")"
check "group B sees its own provider" 'group B sees its own provider' "$(cat "$ISO_LOG")"
rm -f "$ISO_LOG"

echo
if [[ "$failures" -eq 0 ]]; then
  echo "Lesson 3 verified: services, PENDING, reload, isolation, and the plugin_manager"
  echo "layer boundary. Nothing in this lesson needs a provider."
else
  echo "$failures check(s) failed."; exit 1
fi
