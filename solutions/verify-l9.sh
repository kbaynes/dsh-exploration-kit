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
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
source "$(dirname "${BASH_SOURCE[0]}")/lib-llm.sh"
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
# No probe on this boot: the web app's URL line is readiness.
boot_and_wait "$DSH_CHECKOUT" "$PROFILE" "$BOOTLOG" 'dsh web:' 60 "$PATCH" || true
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
echo "== 5. a scheduled task SURVIVES A RESTART =="
# Lesson 9 claims schedules are Host-owned and survive restarts. That needs two processes,
# like every other durability claim in this kit, and no model: creating a task is a service
# call. Delivery is the part that needs a provider - a due task resumes the session and the
# agent then works on it.
#
# The web profile does not surface a plugin's stdout, so the probe writes its result to a
# file named by L9_PROBE_OUT.
export L9_SESSION_ID="session-l9-verify-$RANDOM$RANDOM"
probe_phase() { # probe_phase <overlay> <outfile> <logfile>
  local overlay="$1" out="$2" log="$3"
  rm -f "$out"
  # The web profile does not surface plugin stdout, so the probe writes here as well.
  export L9_PROBE_OUT="$out"
  boot_and_wait "$DSH_CHECKOUT" "$PROFILE" "$log" '\[l9-probe\] done' 60 \
    "$KIT/solutions/l9.patch.yml" "$overlay" || failures=$((failures + 1))
}

OUT1="$(mktemp)"; OUT2="$(mktemp)"; LOG="$(mktemp)"
probe_phase "$KIT/solutions/l9.probe.patch.yml" "$OUT1" "$LOG"
check "phase one creates and lists a task" 'listed 1 task(s)' "$(cat "$OUT1")"

probe_phase "$KIT/solutions/l9.read.patch.yml" "$OUT2" "$LOG"
check "the task is still there in a FRESH process" \
  'after restart, tasks for the session: 1' "$(cat "$OUT2")"
check "deleting it works" 'after deleting: 0 task(s)' "$(cat "$OUT2")"
rm -f "$OUT1" "$OUT2" "$LOG"

echo
echo "== 6. a REAL headless turn, with no provider key =="
# Lesson 9's headless contract - exit codes, stdout vs stderr, and the --json stream - needs a
# PROVIDER, not a model pack: the repository's scriptable mock endpoint runs the real agent
# loop against scripted output.
#
# One behavior per mock instance, with `--repeat-last`: the mock consumes one scripted entry
# per REQUEST, and a turn does not necessarily make exactly one, so sequencing entries across
# runs couples the assertions to an implementation detail. A mock that always succeeds, then
# one that always fails, is deterministic.
MODEL_PATCH="$(mktemp)"
cat > "$MODEL_PATCH" <<'PATCH'
- id: agent-default-model
  config:
    provider: deepseek-official
    model: deepseek-flash
PATCH

run_headless() { # run_headless <outfile> <errfile> [extra args...]
  local out="$1" err="$2"; shift 2
  ( cd "$DSH_CHECKOUT" && DEEPSEEK_BASE_URL="$MOCK_LLM_BASE_URL" DEEPSEEK_API_KEY=mock-key \
      dsh --profile headless --patch "$MODEL_PATCH" "$@" "say hi" >"$out" 2>"$err" )
}

json_types_of() { # json_types_of <stream file>
  python3 -c "
import json,pathlib
types=[]
for line in pathlib.Path('$1').read_text().split(chr(10)):
    line=line.strip()
    if line:
        try: types.append(json.loads(line).get('type'))
        except Exception: pass
print(','.join(types))
"
}

echo
echo "-- a mock that always succeeds --"
if start_mock_llm "$DSH_CHECKOUT" 8129 success; then
  HL_OUT="$(mktemp)"; HL_ERR="$(mktemp)"
  run_headless "$HL_OUT" "$HL_ERR"; hl_status=$?
  check "a successful turn exits 0" '0' "$hl_status"
  check "the final answer reaches stdout" 'mock response recovered' "$(cat "$HL_OUT")"

  HLJ_OUT="$(mktemp)"; HLJ_ERR="$(mktemp)"
  run_headless "$HLJ_OUT" "$HLJ_ERR" --json; hlj_status=$?
  json_types="$(json_types_of "$HLJ_OUT")"
  check "a --json turn still exits 0" '0' "$hlj_status"
  check "the --json stream opens with a session" 'session,' "$json_types,"
  check "the model text arrives as a text event" 'text' "$json_types"
  # `turn_end` is a PHASE inside a `status` event, not an event type — asserting on the type
  # string tested nothing. The phases are the documented content of the stream.
  check "the stream carries turn_start" '"phase":"turn_start"' "$(cat "$HLJ_OUT")"
  check "the stream carries turn_end" '"phase":"turn_end"' "$(cat "$HLJ_OUT")"
  check "the stream closes with final" 'final' "$json_types"
  rm -f "$HL_OUT" "$HL_ERR" "$HLJ_OUT" "$HLJ_ERR"
  stop_mock_llm
else
  echo "FAIL  could not start the mock LLM server"; failures=$((failures + 1))
fi

echo
echo "-- a mock that always fails --"
if start_mock_llm "$DSH_CHECKOUT" 8130 server_error; then
  HLF_OUT="$(mktemp)"; HLF_ERR="$(mktemp)"
  run_headless "$HLF_OUT" "$HLF_ERR" --json; hlf_status=$?
  check "a failing turn exits 1" '1' "$hlf_status"
  check "the failure is reported on stderr, not stdout" 'dsh:' "$(cat "$HLF_ERR")"
  check "the --json stream still terminates with final" 'final' "$(json_types_of "$HLF_OUT")"
  rm -f "$HLF_OUT" "$HLF_ERR"
  stop_mock_llm
else
  echo "FAIL  could not start the failing mock LLM server"; failures=$((failures + 1))
fi
rm -f "$MODEL_PATCH"

echo
if [[ "$failures" -eq 0 ]]; then
  echo "Lesson 9 verified: opt-in activation, schedule durability, and a real headless turn"
  echo "including exit codes, stdout/stderr separation, and the --json event stream."
  echo "Still needs a credential: an SDK round trip, a webhook delivery, and a task firing"
  echo "against a real provider."
else
  echo "$failures check(s) failed."; exit 1
fi
