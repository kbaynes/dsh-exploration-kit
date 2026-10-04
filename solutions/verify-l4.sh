# Lesson 4 verification — policy listeners register on the live composition
#
# Verifies without a harness boot:
#   1. the bundle carries both L4 rows
#   2. both plugins declare `inject = ['tools']` (without it the load throws)
#   3. the waterfall listener delegates with next() rather than vetoing everything
#   4. the confinement root comes from config, not process.cwd()
#
# Usage: bash solutions/verify-l4.sh /path/to/deepseek-harness
# Prereq: dsh plugin --profile kitdemo add link:<kit>/kit-plugins
#
# NOT asserted here, because it needs a model tool call: that a write outside the
# root is denied and one inside succeeds. Recorded as unverified in VERIFIED.md.
set -uo pipefail

DSH_CHECKOUT="${1:-}"
PROFILE="${PROFILE:-kitdemo}"
if [[ -z "$DSH_CHECKOUT" || ! -d "$DSH_CHECKOUT" ]]; then
  echo "usage: bash solutions/verify-l4.sh /path/to/deepseek-harness" >&2
  exit 2
fi
KIT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

failures=0
check() {
  if grep -qF -- "$2" <<<"$3"; then echo "PASS  $1"
  else echo "FAIL  $1"; echo "      expected: $2"; failures=$((failures + 1)); fi
}

out="$(cd "$DSH_CHECKOUT" && dsh --profile "$PROFILE" --dump-config 2>&1)"

echo "== 1. bundle carries the L4 rows =="
check "waterfall gate row" "id: l4-write-scope" "$out"
check "guard row" "id: l4-guard" "$out"

echo
echo "== 2. both plugins declare the tools service =="
for f in write-scope guard; do
  if grep -q "inject = \['tools'\]" "$KIT/kit-plugins/l4/$f.js"; then
    echo "PASS  $f declares inject = ['tools']"
  else
    echo "FAIL  $f is missing inject"; failures=$((failures + 1))
  fi
done

echo
echo "== 3. the waterfall delegates instead of vetoing =="
if grep -q 'return next()' "$KIT/kit-plugins/l4/write-scope.js"; then
  echo "PASS  gate delegates with next()"
else
  echo "FAIL  gate never delegates; it would veto every call"; failures=$((failures + 1))
fi

echo
echo "== 4. confinement root is configured, not cwd-relative =="
if grep -q 'allowedRoot' "$KIT/kit-plugins/l4/write-scope.js"; then
  echo "PASS  root comes from config"
else
  echo "FAIL  root is not configurable"; failures=$((failures + 1))
fi
if grep -q 'ALLOWED_ROOT' "$KIT/kit-plugins/l4/write-scope.js"; then
  echo "WARN  a stale cwd-based constant may remain"
else
  echo "PASS  no cwd-based constant"
fi

echo
if [[ "$failures" -eq 0 ]]; then
  echo "Lesson 4 wiring verified. The allow/deny decisions need a model tool call"
  echo "and are recorded as unverified in VERIFIED.md."
else
  echo "$failures check(s) failed."; exit 1
fi
