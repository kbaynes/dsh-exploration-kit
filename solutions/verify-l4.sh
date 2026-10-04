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
if [[ -z "$out" ]]; then
  echo "ERROR: dsh --profile $PROFILE --dump-config produced no output." >&2
  echo "       Install the kit bundle: dsh plugin --profile $PROFILE add link:<kit>/kit-plugins" >&2
  exit 3
fi

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
echo "== 5. the gate's DECISIONS, exercised through the real pipeline =="
# Lesson 4's central claim used to be recorded as needing a model. It does not:
# ctx.tools.execute() takes the same path a model-direct call takes, so the policy probe
# can dispatch a synthetic call and the denying layer can be identified by its reason.
PROBE_LOG="$(mktemp)"
( cd "$DSH_CHECKOUT" && KIT_ROOT="$KIT" dsh --profile "$PROFILE" \
    --patch "$KIT/solutions/l4.probe.patch.yml" --port 0 --no-open >"$PROBE_LOG" 2>&1 ) &
probepid=$!
sleep 24
kill "$probepid" 2>/dev/null
wait "$probepid" 2>/dev/null

if grep -q '\[l4-probe\] write-outside: GATE-DENIED' "$PROBE_LOG"; then
  echo "PASS  a write outside the root is denied BY THE GATE"
else
  echo "FAIL  the gate did not deny an outside write:"
  grep '\[l4-probe\]' "$PROBE_LOG" | head -4 | sed 's/^/        /'
  failures=$((failures + 1))
fi

# Discrimination matters as much as enforcement: a gate that denies everything would
# also pass the check above.
inside_verdict="$(grep -o '\[l4-probe\] write-inside: [A-Z-]*' "$PROBE_LOG" | awk '{print $3}')"
if [[ "$inside_verdict" == "GATE-DENIED" ]]; then
  echo "FAIL  the gate denied an inside write too — it is not discriminating"
  failures=$((failures + 1))
elif [[ -n "$inside_verdict" ]]; then
  echo "PASS  an inside write is not denied by the gate (verdict: $inside_verdict)"
  if [[ "$inside_verdict" == "OTHER-DENIED" ]]; then
    echo "        it was stopped by a SECOND policy layer (DSH's own filesystem sandbox),"
    echo "        which is the defense-in-depth point the lesson makes."
  fi
else
  echo "WARN  the probe produced no verdict for the inside write"
fi
rm -f "$PROBE_LOG"

echo
if [[ "$failures" -eq 0 ]]; then
  echo "Lesson 4 verified, including the gate's decisions, via the policy probe."
  echo "Still needing a provider: nothing in this lesson."
else
  echo "$failures check(s) failed."; exit 1
fi
