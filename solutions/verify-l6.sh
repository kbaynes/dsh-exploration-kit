# Lesson 6 verification — the durable event, and the projection that folds it.
#
# Verifies without a model:
#   1. the plugins load, and no plugin throws on a real session
#   2. `session.append('l6/step', …)` is accepted for a log-only event
#   3. the registered projection folds it, readable through stateOf
#   4. the event carries the COMPLETE post-change state (the fold replaces, not adds)
#   5. the projection's pure core passes its unit tests
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
echo "== 2-4. a real session, a real append, a real fold =="
# ctx.agents.create() makes a session and runs no turn, so no provider is involved.
PROBE_LOG="$(mktemp)"
( cd "$DSH_CHECKOUT" && dsh --profile "$PROFILE" \
    --patch "$KIT/solutions/l6.probe.patch.yml" --port 0 --no-open >"$PROBE_LOG" 2>&1 ) &
probepid=$!
sleep 26
kill "$probepid" 2>/dev/null
wait "$probepid" 2>/dev/null

check "the projection is registered and starts at zero" \
  'projection before any event: {"total":0}' "$(grep '\[l6-probe\]' "$PROBE_LOG")"
check "an appended log-only event is folded" \
  'after append count=1: {"total":1}' "$(grep '\[l6-probe\]' "$PROBE_LOG")"
# The rule the lesson teaches: the event carries the complete post-change state, so a
# second event saying 9 yields 9 — not 1 + 9.
check "the event carries complete state, so the fold replaces rather than adds" \
  'after append count=9: {"total":9}' "$(grep '\[l6-probe\]' "$PROBE_LOG")"

# A plugin that throws on agent/created is the failure mode this probe was written for:
# the kit's counter did exactly that, and an agent-created listener that never fires is
# invisible until a session exists.
if grep -q 'Invalid value used as weak map key' "$PROBE_LOG"; then
  echo "FAIL  a plugin threw on agent/created (it is treating the payload as the agent)"
  failures=$((failures + 1))
else
  echo "PASS  no plugin threw on session creation"
fi
check "the counter registered the new session" \
  'tracking a new session' "$(grep '\[l6-counter\]' "$PROBE_LOG")"
rm -f "$PROBE_LOG"

echo
if [[ "$failures" -eq 0 ]]; then
  echo "Lesson 6 verified: a log-only event is appended, committed, and folded by the"
  echo "registered projection, with complete-state semantics."
else
  echo "$failures check(s) failed."; exit 1
fi
