# Lesson 5 verification — context plumbing is wired and the skill overlay composes
#
# Verifies without a session:
#   1. the bundle carries the three L5 rows
#   2. each plugin declares the services it uses (agents, commands)
#   3. agent.inject() is called with a real UserMessage, not a loose object
#   4. the skills overlay composes customSkillDirs onto the existing base row
#   5. the skill's frontmatter satisfies the provider's rules
#
# Usage: bash solutions/verify-l5.sh /path/to/deepseek-harness
# Prereq: dsh plugin --profile kitdemo add link:<kit>/kit-plugins
#
# NOT asserted, because each needs a model-driven tool call of its own: the model
# INVOKING the skill once the catalogue has announced it.
set -uo pipefail

DSH_CHECKOUT="${1:-}"
PROFILE="${PROFILE:-kitdemo}"
if [[ -z "$DSH_CHECKOUT" || ! -d "$DSH_CHECKOUT" ]]; then
  echo "usage: bash solutions/verify-l5.sh /path/to/deepseek-harness" >&2
  exit 2
fi
KIT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
source "$(dirname "${BASH_SOURCE[0]}")/lib-llm.sh"

failures=0
check() {
  if grep -qF -- "$2" <<<"$3"; then echo "PASS  $1"
  else echo "FAIL  $1"; echo "      expected: $2"; failures=$((failures + 1)); fi
}

out="$(cd "$DSH_CHECKOUT" && dsh --profile "$PROFILE" --dump-config 2>&1)"
echo "== 1. bundle carries the L5 rows =="
check "observer row" "id: l5-observer" "$out"
check "inject row" "id: l5-inject" "$out"
check "command row" "id: l5-commands" "$out"

echo
echo "== 2. services declared =="
grep -q "inject = \['agents'\]" "$KIT/kit-plugins/l5/inject.js" \
  && echo "PASS  inject plugin declares agents" \
  || { echo "FAIL  inject plugin missing agents"; failures=$((failures + 1)); }
grep -q "inject = \['commands'\]" "$KIT/kit-plugins/l5/commands.js" \
  && echo "PASS  command plugin declares commands" \
  || { echo "FAIL  command plugin missing commands"; failures=$((failures + 1)); }

echo
echo "== 3. agent.inject gets a real UserMessage =="
if grep -q 'createUserMessage' "$KIT/kit-plugins/l5/inject.js"; then
  echo "PASS  uses createUserMessage"
else
  echo "FAIL  injects a loose object; that is not a UserMessage"
  failures=$((failures + 1))
fi
if grep -q "kind: 'plugin'" "$KIT/kit-plugins/l5/inject.js"; then
  echo "FAIL  uses the stale catch-all 'plugin' source kind"
  failures=$((failures + 1))
else
  echo "PASS  declares its own source kind"
fi

echo
echo "== 4. skills overlay composes onto the existing row =="
sk="$(cd "$DSH_CHECKOUT" && KIT_ROOT="$KIT" dsh --profile "$PROFILE" --patch "$KIT/solutions/l5.skills.patch.yml" --dump-config 2>&1)"
check "skill row present" "id: skill-filesystem" "$sk"
check "customSkillDirs carried" "customSkillDirs" "$sk"
check "default roots disabled" "includeDefaultRoots: false" "$sk"
if grep -qE "^- id: skill-filesystem" "$KIT/solutions/l5.skills.patch.yml"; then
  echo "PASS  overlay is an override (no insert/name)"
else
  echo "FAIL  overlay should target the existing row"; failures=$((failures + 1))
fi

echo
echo "== 5. skill frontmatter satisfies the provider =="
skill="$KIT/kit-plugins/l5/skills/repo-onboarding/SKILL.md"
if grep -q '^name: repo-onboarding$' "$skill"; then
  echo "PASS  name is kebab-case and matches the directory"
else
  echo "FAIL  name missing or mismatched"; failures=$((failures + 1))
fi
if grep -q '^description: .\{20,\}' "$skill"; then
  echo "PASS  description present and substantive"
else
  echo "FAIL  description missing or too short"; failures=$((failures + 1))
fi

echo
echo "== 6. injected context survives a RESTART =="
# Lesson 5's durability claim. It cannot be checked in one process: `agent/created` fires
# while the session is being built, so an in-process assertion measures the queue rather
# than the log. Two processes, like Lesson 6's restart test.
#
# The kit bundle carries the inject plugin, so it needs no overlay of its own; the probe
# only creates the session in phase one and reads it in phase two.
export L5_SESSION_ID="session-l5-verify-$RANDOM$RANDOM"

phase() { # phase <overlay> <logfile>
  boot_and_wait "$DSH_CHECKOUT" "$PROFILE" "$2" '\[l5-probe\] done' 60 "$1" \
    || failures=$((failures + 1))
}

L5LOG1="$(mktemp)"; L5LOG2="$(mktemp)"
phase "$KIT/solutions/l5.probe.patch.yml" "$L5LOG1"
check "phase one reports the injection happened" \
  'context appended' "$(grep '\[l5-inject\]' "$L5LOG1")"
phase "$KIT/solutions/l5.read.patch.yml" "$L5LOG2"
check "the injected text is in the log after a restart" \
  'injected text present after restart: true' "$(grep '\[l5-probe\]' "$L5LOG2")"
check "it is carried by a first-party event type" \
  'carried by: agent/inbox/spliced' "$(grep '\[l5-probe\]' "$L5LOG2")"
# The persistence contract refuses a log containing an unknown type (ADR-0024), so a
# readable log here is further evidence no plugin invented one.
if grep -qE 'unknown to this harness|refusing to interpret' "$L5LOG2"; then
  echo "FAIL  the persisted log is unreadable"
  failures=$((failures + 1))
else
  echo "PASS  the persisted log is readable"
fi
rm -f "$L5LOG1" "$L5LOG2"

echo
echo "== 7. the command runs from plain code, with NO model turn =="
# Lesson 5 claims /l5-facts answers without a model turn. ctx.commands.execute is the dispatch
# path the composer uses and it takes an Agent, which ctx.agents.create provides without
# running a turn - so the claim is testable, and the session log is the evidence: command
# lifecycle events, and zero model-request events.
CMD_LOG="$(mktemp)"
boot_and_wait "$DSH_CHECKOUT" "$PROFILE" "$CMD_LOG" '\[l5-cmd\] done' 60 \
  "$KIT/solutions/l7.patch.yml" "$KIT/solutions/l5.cmd.patch.yml" || failures=$((failures + 1))
cmd_out="$(grep '\[l5-cmd\]' "$CMD_LOG")"

check "the command resolves" 'resolved: true' "$cmd_out"
check "the handler returns its text" '"kind":"success","text":"content/' "$cmd_out"
check "the session logs the command lifecycle" 'command/run, command/done' "$cmd_out"
check "no model request was made" 'model-request events in the log: 0' "$cmd_out"
rm -f "$CMD_LOG"

echo
echo "== 8. the model-visible skill CATALOGUE, against a real turn =="
# The catalogue only exists once a request is assembled, so this needs a provider - not a model:
# the repository's scriptable mock endpoint runs the real loop and request assembly (ADR-0027).
# The catalogue is durable, which is what makes it checkable: it lands in the session log as a
# user message. The BODY must NOT be there, because a skill body loads on demand, after the model
# chooses it. That pair is the lesson's actual claim.
CAT_MODEL_PATCH="$(mktemp)"
cat > "$CAT_MODEL_PATCH" <<'PATCH'
- id: agent-default-model
  config:
    provider: deepseek-official
    model: deepseek-flash
PATCH
if start_mock_llm "$DSH_CHECKOUT" 8137 success; then
  CAT_LOG="$(mktemp)"
  # boot_and_wait runs `dsh` from the checkout, so the mock route must be exported, not inlined.
  # KIT_ROOT is load-bearing too: the skills overlay computes customSkillDirs from it at load
  # time, so without it the skill directory resolves to undefined and the catalogue is empty -
  # a silent no-op that looks exactly like the claim being false.
  export DEEPSEEK_BASE_URL="$MOCK_LLM_BASE_URL" DEEPSEEK_API_KEY=mock-key KIT_ROOT="$KIT"
  boot_and_wait "$DSH_CHECKOUT" "$PROFILE" "$CAT_LOG" '\[l5-cat\] done' 90 \
    "$KIT/solutions/l7.patch.yml" "$KIT/solutions/l5.skills.patch.yml" \
    "$KIT/solutions/l5.cat.patch.yml" "$CAT_MODEL_PATCH" || failures=$((failures + 1))
  unset DEEPSEEK_BASE_URL DEEPSEEK_API_KEY KIT_ROOT
  stop_mock_llm

  cat_out="$(grep '\[l5-cat\]' "$CAT_LOG")"
  check "the turn itself completed (a request was assembled)" 'assistant/message' "$cat_out"
  check "the catalogue announces the skill to the model" "catalogue mentions 'repo-onboarding': true" "$cat_out"
  # The pair matters more than either half: a catalogue in the log proves announcement, and an
  # absent body proves the body is loaded on demand rather than shipped with it.
  check "the skill BODY is NOT shipped with the catalogue" 'body loaded into the log: false' "$cat_out"
  rm -f "$CAT_LOG"
else
  echo "FAIL  could not start the mock LLM server"; failures=$((failures + 1))
fi

echo
echo "== 9. the model CALLS the skill, and only then does the body load =="
# Phase 8 proves the catalogue arrives with the body absent. This phase proves the other half of
# the same design: when the model actually calls the `skill` tool, the body arrives. The mock
# scripts the CALL while the harness executes the tool for real (ADR-0027), so this is the whole
# mechanism - announce, choose, load - with no key.
if start_mock_llm "$DSH_CHECKOUT" 8140 tool_call_success,success \
    --tool-name skill --tool-arguments '{"name":"repo-onboarding"}'; then
  BODY_LOG="$(mktemp)"
  export DEEPSEEK_BASE_URL="$MOCK_LLM_BASE_URL" DEEPSEEK_API_KEY=mock-key KIT_ROOT="$KIT"
  boot_and_wait "$DSH_CHECKOUT" "$PROFILE" "$BODY_LOG" '\[l5-cat\] done' 90 \
    "$KIT/solutions/l7.patch.yml" "$KIT/solutions/l5.skills.patch.yml" \
    "$KIT/solutions/l5.cat.patch.yml" "$CAT_MODEL_PATCH" || failures=$((failures + 1))
  unset DEEPSEEK_BASE_URL DEEPSEEK_API_KEY KIT_ROOT
  stop_mock_llm

  body_out="$(grep '\[l5-cat\]' "$BODY_LOG")"
  check "the catalogue is still announced" "catalogue mentions 'repo-onboarding': true" "$body_out"
  check "the call ran through the real tool pipeline" 'tool/result' "$body_out"
  # The same marker phase 8 asserts is ABSENT is now present: the body is loaded on demand.
  check "the skill BODY loads once the model calls it" 'body loaded into the log: true' "$body_out"
  rm -f "$BODY_LOG"
else
  echo "FAIL  could not start the mock LLM server"; failures=$((failures + 1))
fi
rm -f "$CAT_MODEL_PATCH"

echo
if [[ "$failures" -eq 0 ]]; then
  echo "Lesson 5 verified: injection durability, the command path, the skills overlay, and the"
  echo "model-visible skill catalogue end to end - announced without its body, then loaded when the"
  echo "model calls the skill through the real tool pipeline."
else
  echo "$failures check(s) failed."; exit 1
fi
