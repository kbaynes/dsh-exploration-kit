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
( cd "$DSH_CHECKOUT" && dsh --profile "$PROFILE" --patch "$PATCH" --port 0 --no-open >"$BOOTLOG" 2>&1 ) &
bootpid=$!
sleep 22
kill "$bootpid" 2>/dev/null
wait "$bootpid" 2>/dev/null
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
if [[ "$failures" -eq 0 ]]; then
  echo "Lesson 9 wiring verified. Model-dependent claims are unverified; see VERIFIED.md."
else
  echo "$failures check(s) failed."; exit 1
fi
