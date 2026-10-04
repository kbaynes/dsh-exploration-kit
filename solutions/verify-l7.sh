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
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
source "$(dirname "${BASH_SOURCE[0]}")/lib-llm.sh"
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
# Readiness here is the web app's URL line: this boot has no probe to wait for.
boot_and_wait "$DSH_CHECKOUT" "$PROFILE" "$BOOTLOG" 'dsh web:' 60 "$PATCH" || true
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
boot_and_wait "$DSH_CHECKOUT" "$PROFILE" "$QUERY_LOG" '\[l7-probe\] done' 60 \
  "$KIT/solutions/l7.patch.yml" "$KIT/solutions/l7.probe.patch.yml" || failures=$((failures + 1))

check "listSessions finds the session the probe created" \
  'mine found: true' "$(grep '\[l7-probe\]' "$QUERY_LOG")"
check "readSession returns the log including the marker" \
  'marker present: true' "$(grep '\[l7-probe\]' "$QUERY_LOG")"
# The POSITIVE cases: a first-party log-only event is readable back AND findable by a type
# filter, and the session is findable by full-text search. The caveat gets its own phase below,
# because asserting only the limitation would leave the working path untested.
check "the type filter answers" \
  "filterEvents by type 'sandbox/mode':" "$(grep '\[l7-probe\]' "$QUERY_LOG")"
check "the text filter answers" \
  'filterEvents by text:' "$(grep '\[l7-probe\]' "$QUERY_LOG")"
# Lesson 7 says the five tools register in a live ROOT AGENT's scope - a claim about
# agent.ctx rather than the global registry, and one that would silently stop being true.
check "all five lesson tools register in the agent scope" \
  'lesson tools in the AGENT scope: 5/5' "$(grep '\[l7-probe\]' "$QUERY_LOG")"
rm -f "$QUERY_LOG"

echo
echo "== 6. the CAVEAT: an invented event type is invisible, and it breaks search =="
# The contrast with section 5 is the lesson: readSession returns an invented event, and the query
# layer cannot see it at all. This phase DELIBERATELY creates such a session, so it removes it
# again - a session carrying a type the harness does not know breaks search for the whole home.
POISON_LOG="$(mktemp)"
boot_and_wait "$DSH_CHECKOUT" "$PROFILE" "$POISON_LOG" '\[l7-probe\] done' 60 \
  "$KIT/solutions/l7.patch.yml" "$KIT/solutions/l7.poison.patch.yml" || failures=$((failures + 1))
poison_out="$(grep '\[l7-probe\]' "$POISON_LOG")"
check "readSession still returns the invented event" 'marker present: true' "$poison_out"
check "a type filter cannot see the invented type" \
  "filterEvents by type 'l6/step': 0 match" "$poison_out"
check "a text filter cannot see it either" 'filterEvents by text: 0 match' "$poison_out"
# Full-text search cannot see it either. (A session carrying an unknown type breaks search for the
# whole HOME when it is indexed at startup - demonstrated in ADR-0024 with 37 such sessions - but a
# single one created mid-run is simply absent from the results, which is what is deterministic.)
check "full-text search cannot find it either" 'searchSessions: 0 hit' "$poison_out"

# Clean up: remove the exact session this phase created, parsed from its own output.
poisoned="$(grep -o 'created session-l7-probe-[^ ,]*' "$POISON_LOG" | head -1 | awk '{print $2}')"
if [[ -n "$poisoned" ]]; then
  rm -rf "${DSH_HOME:-$HOME/.dsh}/sessions"/*/"$poisoned" "$HOME/.dsh/sessions"/*/"$poisoned" 2>/dev/null
  # Belt and braces: any probe session whose marker names an invented append is unreadable, so a
  # parse failure must not be able to leave one behind.
  for stale in $(ls -d "${DSH_HOME:-$HOME/.dsh}/sessions"/*/session-l7-probe-* 2>/dev/null); do
    rm -rf "$stale" 2>/dev/null
  done
  echo "PASS  removed the poisoned session it created ($poisoned)"
else
  echo "WARN  could not identify the poisoned session to remove"
fi
rm -f "$POISON_LOG"

echo
echo "== 7. a REAL turn: accounting, statistics, search and /compact =="
# A real turn against the repository's scriptable mock provider: the loop, log and accounting are
# real while the model output is scripted, which is all these claims need (ADR-0027).
MODEL_PATCH="$(mktemp)"
cat > "$MODEL_PATCH" <<'PATCH'
- id: agent-default-model
  config:
    provider: deepseek-official
    model: deepseek-flash
PATCH
TURN_LOG="$(mktemp)"
if start_mock_llm "$DSH_CHECKOUT" 8132 success; then
  ( cd "$DSH_CHECKOUT" && DEEPSEEK_BASE_URL="$MOCK_LLM_BASE_URL" DEEPSEEK_API_KEY=mock-key \
      dsh --profile "$PROFILE" --patch "$KIT/solutions/l7.patch.yml" \
      --patch "$MODEL_PATCH" --patch "$KIT/solutions/l7.turn.patch.yml" \
      --port 0 --no-open >"$TURN_LOG" 2>&1 ) &
  turnpid=$!
  waited=0
  while (( waited < 90 )); do
    grep -q '\[l7-turn\] done' "$TURN_LOG" 2>/dev/null && break
    sleep 1; waited=$((waited + 1))
  done
  kill "$turnpid" 2>/dev/null; wait "$turnpid" 2>/dev/null
  stop_mock_llm

  turn_out="$(grep '\[l7-turn\]' "$TURN_LOG")"
  check "token accounting is exposed with its documented shape" '"totals":' "$turn_out"
  # The mock reports no usage for scripted text, so the numbers are zero; the shape is the claim.
  check "the accounting keys are the documented ones" 'uncachedInputTokens' "$turn_out"
  check "the statistics unit is absent in a base-backed profile" 'sessionStats (web-only): not mounted' "$turn_out"
  # At least one, not exactly one: the verification home accumulates sessions from every run, so
  # a legitimate query matches other turns too. What matters is that the text the ASSISTANT
  # produced is findable.
  hits="$(grep -o "searchSessions('mock response'): [0-9]* hit" <<<"$turn_out" | grep -o '[0-9]*' | head -1)"
  if [[ -n "$hits" && "$hits" -ge 1 ]]; then
    echo "PASS  the trajectory is searchable by the assistant's own text ($hits hit(s))"
  else
    echo "FAIL  the assistant's text was not searchable (hits: ${hits:-none})"
    failures=$((failures + 1))
  fi
  check "/compact settles as a command" '/compact outcome: {"kind":"success"' "$turn_out"
else
  echo "FAIL  could not start the mock LLM server"; failures=$((failures + 1))
fi
rm -f "$MODEL_PATCH" "$TURN_LOG"

echo
if [[ "$failures" -eq 0 ]]; then
  echo "Lesson 7 verified: the store, the query service, the tool scope, the invented-type caveat"
  echo "(with cleanup), and a real turn's accounting, searchability and /compact."
  echo "Still unverified: the workspace-authority refusal (needs a model-driven tool call) and the"
  echo "invariant findings on a fresh profile."
else
  echo "$failures check(s) failed."; exit 1
fi
