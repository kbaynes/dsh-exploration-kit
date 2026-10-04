# Lesson 7 verification — opt-in session history and invariants compose and activate
#
# Verifies without a session:
#   1. the overlay overrides the existing session-query-sqlite row (not an insert)
#   2. the overlay inserts tool-session-query and the two invariants rows
#   3. every entry activates when the overlay is applied
#   4. the pinned optional package is actually installed in the profile
#
# Usage: bash solutions/verify-l7.sh /path/to/deepseek-harness
#
# Prereq (the lesson's step 1):
#   dsh plugin --profile kitdemo add link:<kit>/kit-plugins
#   dsh plugin --profile kitdemo add @deepseek-ai/dsh-tool-session-query@<dsh version>
#
# NOT asserted, because each needs a session or model: session_search,
# session_trace, the workspace-authority refusal, token deltas, /compact, and the
# invariant sweep's findings. Recorded as unverified in VERIFIED.md.
set -uo pipefail

DSH_CHECKOUT="${1:-}"
PROFILE="${PROFILE:-kitdemo}"
VERSION="${DSH_VERSION:-0.2.0-rc.2}"
if [[ -z "$DSH_CHECKOUT" || ! -d "$DSH_CHECKOUT" ]]; then
  echo "usage: bash solutions/verify-l7.sh /path/to/deepseek-harness" >&2
  exit 2
fi
KIT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PATCH="$KIT/solutions/l7.patch.yml"

failures=0
check() {
  if grep -qF -- "$2" <<<"$3"; then echo "PASS  $1"
  else echo "FAIL  $1"; echo "      expected: $2"; failures=$((failures + 1)); fi
}

echo "== 1-2. overlay shape =="
# The store row already exists, so it is an override; the tool row does not, so it is
# an insert. Getting this backwards is silently ineffective (ADR: patch semantics).
python3 - "$PATCH" <<'PY'
import re, sys, pathlib
text = pathlib.Path(sys.argv[1]).read_text()
top_ids = re.findall(r'^- id: (\S+)', text, re.M)
inserted = re.findall(r'^\s+- id: (\S+)', text, re.M)
ok = True
if 'session-query-sqlite' not in top_ids:
    print('FAIL  session-query-sqlite should be an override (top-level - id:)'); ok = False
else:
    print('PASS  session-query-sqlite overridden in place')
for name in ('tool-session-query', 'invariants', 'session-invariant'):
    if name not in inserted or name in top_ids:
        print(f'FAIL  {name} should be inserted (not an override)'); ok = False
    else:
        print(f'PASS  {name} inserted')
if 'openAt: startup' not in text:
    print('FAIL  openAt: startup is required; the web bundle ships openAt: never'); ok = False
else:
    print('PASS  the store is opened at startup')
sys.exit(0 if ok else 1)
PY
[[ $? -ne 0 ]] && failures=$((failures + 1))

echo
echo "== 3. the composition activates cleanly =="
# `timeout` is GNU coreutils and absent on macOS, so bound the boot by hand.
BOOTLOG="$(mktemp)"
( cd "$DSH_CHECKOUT" && dsh --profile "$PROFILE" --patch "$PATCH" --port 0 --no-open >"$BOOTLOG" 2>&1 ) &
bootpid=$!
sleep 20
kill "$bootpid" 2>/dev/null
wait "$bootpid" 2>/dev/null
log="$(cat "$BOOTLOG")"
rm -f "$BOOTLOG"
if grep -qE 'warning: [0-9]+ entr(y|ies) did not activate' <<<"$log"; then
  echo "FAIL  an entry did not activate:"
  grep -A2 'did not activate' <<<"$log" | head -4
  failures=$((failures + 1))
else
  echo "PASS  no activation warnings"
fi

echo
echo "== 4. the pinned optional package is installed =="
manifest="${DSH_HOME:-$HOME/.dsh}/profiles/$PROFILE/package.json"
if [[ -f "$manifest" ]]; then
  if grep -q 'dsh-tool-session-query' "$manifest"; then
    echo "PASS  installed in the profile manifest"
    if grep -q "@deepseek-ai/dsh-tool-session-query\": \"$VERSION\"" "$manifest"; then
      echo "PASS  pinned to $VERSION (npm's 'latest' tag is stale at 0.0.1-rc.1)"
    else
      echo "WARN  installed, but not obviously pinned to $VERSION — check for a stale tag resolution"
    fi
  else
    echo "FAIL  @deepseek-ai/dsh-tool-session-query is not installed; a row naming an"
    echo "      uninstalled package fails to import"
    failures=$((failures + 1))
  fi
else
  echo "SKIP  no profile manifest at $manifest"
fi

echo
echo "== 5. the query service itself, and where the tools register =="
# ctx.sessionQuery is the service behind the five model-facing tools. The tools add schema,
# prompt, and workspace authorization; the service is what a code caller uses, so the same
# store and reads can be exercised WITHOUT a model.
QUERY_LOG="$(mktemp)"
( cd "$DSH_CHECKOUT" && dsh --profile "$PROFILE" \
    --patch "$KIT/solutions/l7.patch.yml" \
    --patch "$KIT/solutions/l7.probe.patch.yml" --port 0 --no-open >"$QUERY_LOG" 2>&1 ) &
querypid=$!
sleep 27
kill "$querypid" 2>/dev/null
wait "$querypid" 2>/dev/null

check "listSessions finds the session the probe created" \
  'mine found: true' "$(grep '\[l7-probe\]' "$QUERY_LOG")"
check "readSession returns the log including the marker event" \
  'marker present: true' "$(grep '\[l7-probe\]' "$QUERY_LOG")"
# A second consequence of ADR-0024, asserted rather than glossed: readSession returns the
# invented event, and filterEvents cannot see it AT ALL - not by type, and not by text.
# The query layer indexes documents it can interpret, and it cannot interpret a type the
# harness does not know.
check "filterEvents cannot see an invented type, by type" \
  'filterEvents by type: 0 match' "$(grep '\[l7-probe\]' "$QUERY_LOG")"
check "filterEvents cannot see it by text either" \
  'filterEvents by text: 0 match' "$(grep '\[l7-probe\]' "$QUERY_LOG")"
# Lesson 7 says the five tools register in a live ROOT AGENT's scope - a claim about
# agent.ctx rather than the global registry, and one that would silently stop being true.
check "all five lesson tools register in the agent scope" \
  'lesson tools in the AGENT scope: 5/5' "$(grep '\[l7-probe\]' "$QUERY_LOG")"
rm -f "$QUERY_LOG"

echo
echo "NOTE  full-text search is not asserted. It observes whole sessions, so a single"
echo "      session carrying an event type the harness does not know makes searchSessions"
echo "      fail for the entire corpus (ADR-0024). That is documented in the lesson."

echo
if [[ "$failures" -eq 0 ]]; then
  echo "Lesson 7 verified: the store opens, the query service lists and reads, and the five"
  echo "tools register in an agent scope. Still needs a provider: the workspace-authority"
  echo "refusal, token deltas, /compact, and the invariant findings."
else
  echo "$failures check(s) failed."; exit 1
fi
