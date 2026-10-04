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
# NOT asserted, because each needs a session/model: the pre-step payload shape, the
# injected text surviving replay, the model's skill catalog, and /l5-facts.
set -uo pipefail

DSH_CHECKOUT="${1:-}"
PROFILE="${PROFILE:-kitdemo}"
if [[ -z "$DSH_CHECKOUT" || ! -d "$DSH_CHECKOUT" ]]; then
  echo "usage: bash solutions/verify-l5.sh /path/to/deepseek-harness" >&2
  exit 2
fi
KIT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

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
if [[ "$failures" -eq 0 ]]; then
  echo "Lesson 5 verified, including that injected context survives a restart."
  echo "Still unverified (needs a provider): whether a model's skill catalog shows the"
  echo "skill, and whether /l5-facts answers in a real composer."
else
  echo "$failures check(s) failed."; exit 1
fi
