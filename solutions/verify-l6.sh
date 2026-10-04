# Lesson 6 verification — durable derived state, proved across a RESTART.
#
# The lesson's central claim is that state derived from the log survives a restart. This
# script tests exactly that, in TWO processes, which is the only way to test it: the
# original lesson's claim looked true in one process and was false across two.
#
# Verifies without a model:
#   1. the projection's pure core passes its unit tests
#   2. the fold uses a KNOWN event type (not a plugin-declared one)
#   3. a session's mode is derived at creation, and changes when the preset changes
#   4. after a RESTART, resuming the session reconstructs that mode from the persisted log
#   5. no plugin invented an event type (a log containing one is unreadable, so 4 would fail)
#
# Usage: bash solutions/verify-l6.sh /path/to/deepseek-harness
# Prereq: dsh plugin --profile kitdemo add link:<kit>/kit-plugins
set -uo pipefail

DSH_CHECKOUT="${1:-}"
PROFILE="${PROFILE:-kitdemo}"
if [[ -z "$DSH_CHECKOUT" || ! -d "$DSH_CHECKOUT" ]]; then
  echo "usage: bash solutions/verify-l6.sh /path/to/deepseek-harness" >&2
  exit 2
fi
KIT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
failures=0
check() {
  if grep -qF -- "$2" <<<"$3"; then echo "PASS  $1"
  else echo "FAIL  $1"; echo "      expected: $2"; failures=$((failures + 1)); fi
}

echo "== 1. the projection's pure core =="
if (cd "$KIT/kit-plugins" && node --test l6/fold.test.mjs >/dev/null 2>&1); then
  echo "PASS  fold.test.mjs passes"
else
  echo "FAIL  the projection unit tests do not pass"; failures=$((failures + 1))
fi

echo
echo "== 2. the fold uses a known event type =="
if grep -q "FOLDED_EVENT = 'sandbox/mode'" "$KIT/kit-plugins/l6/fold.js"; then
  echo "PASS  folds 'sandbox/mode', a first-party log-only event"
else
  echo "FAIL  the folded type is not a known first-party event"; failures=$((failures + 1))
fi

# Sessions persist, so a fixed id would make the SECOND run fail with "already exists".
export L6_SESSION_ID="session-l6-verify-$RANDOM$RANDOM"

# Wait for the probe's own completion line rather than for a fixed sleep: the probe's work
# is the thing being waited for, and a short sleep here is silent rather than loud.
boot() { # boot <overlay> <logfile>
  boot_and_wait "$DSH_CHECKOUT" "$PROFILE" "$2" '\[l6-probe\] done' 60 "$1" \
    || failures=$((failures + 1))
}

echo
echo "== 3. phase one: derive the mode, then change it =="
LOG1="$(mktemp)"
boot "$KIT/solutions/l6.probe.patch.yml" "$LOG1"
check "the mode is derived at creation" '"mode":"workspace-write"' "$(grep '\[l6-probe\]' "$LOG1")"
check "changing the preset changes the derived mode" '"mode":"danger-full-access"' "$(grep '\[l6-probe\]' "$LOG1")"

echo
echo "== 4. phase two: a FRESH process reconstructs it from the log =="
LOG2="$(mktemp)"
boot "$KIT/solutions/l6.resume.patch.yml" "$LOG2"
check "the resumed session reports the mode it ended with" \
  'RESUMED mode: {"mode":"danger-full-access"}' "$(grep '\[l6-probe\]' "$LOG2")"

# A log the harness cannot interpret would make the resume fail outright — which is exactly
# what a plugin-declared event type does (ADR-0024).
if grep -qE 'unknown to this harness|refusing to interpret' "$LOG2"; then
  echo "FAIL  the persisted log is unreadable — an invented event type is present"
  failures=$((failures + 1))
else
  echo "PASS  the persisted log is readable after the restart"
fi
rm -f "$LOG1" "$LOG2"

echo
if [[ "$failures" -eq 0 ]]; then
  echo "Lesson 6 verified: durable derived state, reconstructed across a restart."
else
  echo "$failures check(s) failed."; exit 1
fi
