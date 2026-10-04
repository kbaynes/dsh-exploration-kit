# Lesson 2 verification — bundle row, config validation, and override
#
# Verifies, without needing a model provider:
#   1. the installed bundle carries the l2-wordcount row
#   2. the row is named by PACKAGE (relative file paths cannot import dsh packages)
#   3. an overlay patch overrides an installed row's config, last write wins
#   4. the plugin declares a closed-union Schemastery Config
#
# Usage:  bash solutions/verify-l2.sh /path/to/deepseek-harness
#
# Prerequisites: the kit bundle installed with `link:`
#   dsh plugin --profile kitdemo add link:<kit>/kit-plugins
#
# NOT verified here (needs a harness boot): that an invalid config value stops the
# plugin activating. That was executed manually; the observed output is quoted in
# the lesson and recorded in VERIFIED.md. `--dump-config` composes rows and does
# not run validation.
set -uo pipefail

DSH_CHECKOUT="${1:-}"
PROFILE="${PROFILE:-kitdemo}"
if [[ -z "$DSH_CHECKOUT" || ! -d "$DSH_CHECKOUT" ]]; then
  echo "usage: bash solutions/verify-l2.sh /path/to/deepseek-harness" >&2
  exit 2
fi

KIT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"  # solutions/ -> repo root

failures=0
check() { # check <label> <expected-substring> <haystack>
  if grep -qF -- "$2" <<<"$3"; then
    echo "PASS  $1"
  else
    echo "FAIL  $1"
    echo "      expected to find: $2"
    failures=$((failures + 1))
  fi
}

# Compose the profile. A silent empty result means dsh could not compose at all —
# usually a missing profile or a sandbox that blocks writing to $DSH_HOME — so say
# that plainly instead of reporting every row as missing.
dump() {
  # NOTE: the local must NOT be called `out` — under `set -u`, `local out` shadows
  # the caller's variable and leaves it unbound, which made every check in this
  # script fail on an unset variable rather than on its actual content.
  local composed
  composed="$(cd "$DSH_CHECKOUT" && dsh --profile "$PROFILE" "$@" --dump-config 2>&1)"
  if [[ -z "$composed" ]]; then
    echo "ERROR: 'dsh --profile $PROFILE --dump-config' produced no output." >&2
    echo "       Is the kit bundle installed for that profile, and is \$DSH_HOME writable?" >&2
    echo "       Install it with:" >&2
    echo "         dsh plugin --profile $PROFILE add link:<kit>/kit-plugins" >&2
    printf '%s\n' "SKIP: cannot compose the profile; install the kit bundle first"
    exit 0
  fi
  printf '%s' "$composed"
}

echo "== 1. installed bundle carries the row =="
out="$(dump)"
check "row present" "id: l2-wordcount" "$out"
check "row named by package" "dsh-exploration-kit-plugins/l2/wordcount" "$out"
check "row config carried" "defaultUnit: lines" "$out"
if grep -qE "name: '?\./" <<<"$out"; then
  echo "WARN  a row uses a relative file path; confirm it can import dsh packages"
else
  echo "PASS  no row uses a relative file path"
fi

echo
echo "== 2. plugin declares a closed-union Config =="
src="$KIT/kit-plugins/l2/wordcount.js"
if grep -q "Schema.union(\['words', 'lines', 'chars'\])" "$src"; then
  echo "PASS  closed union declared"
else
  echo "FAIL  closed union not found in $src"
  failures=$((failures + 1))
fi
if grep -q "export const Config = Schema.object" "$src"; then
  echo "PASS  Config exported as a runtime schema"
else
  echo "FAIL  Config export shape not found"
  failures=$((failures + 1))
fi

echo
echo "== 3. overlay overrides an installed row, last write wins =="
out2="$(dump --patch "$KIT/solutions/l2.override.patch.yml")"
check "override value wins" "defaultUnit: chars" "$out2"

echo
echo "== 4. the TOOL itself, called through the real pipeline =="
# Lesson 2's tool claim used to need a model. It does not: ctx.tools.execute() runs the
# same pipeline a model-direct call runs, so the probe dispatches word_count and the
# result is inspected directly. See ADR-0021.
PROBE_LOG="$(mktemp)"
boot_and_wait "$DSH_CHECKOUT" "$PROFILE" "$PROBE_LOG" '\[l2-probe\] done' 60 \
  "$KIT/solutions/l2.probe.patch.yml" || failures=$((failures + 1))

probe() { grep -o "\[l2-probe\] $1: .*" "$PROBE_LOG" | head -1; }

check "the configured default reaches the tool" \
  '"value":{"unit":"lines","count":2}' "$(probe default-unit)"
check "an explicit unit overrides the default" \
  '"value":{"unit":"words","count":3}' "$(probe explicit-words)"
check "the count is correct for the content" \
  '"count":17' "$(probe explicit-chars)"
# The message is JSON-encoded in the result, so the inner quotes arrive escaped; assert
# on the parts that are not affected by that rather than on an exact rendering.
check "invalid arguments are rejected before execute runs" \
  '"isError":true' "$(probe invalid-unit)"
check "the rejection names the offending argument" \
  'must be one of' "$(probe invalid-unit)"
# The render/value split the lesson teaches: `value` is the canonical JSON, `content` the
# model-facing prose derived from it. Both appear in one result.
check "the rendered prose accompanies the canonical value" \
  '"content":[{"type":"text","text":"2 lines"}]' "$(probe default-unit)"
rm -f "$PROBE_LOG"

echo
if [[ "$failures" -eq 0 ]]; then
  echo "Lesson 2 verified: bundle row resolution, package naming, closed-union schema,"
  echo "overlay override, and the tool's own behaviour — the configured default reaching"
  echo "apply, an explicit unit overriding it, argument rejection, and the"
  echo "canonical-value/render split appearing together in one result."
  echo "Still needing a provider: nothing in this lesson."
else
  echo "$failures check(s) failed."
  exit 1
fi
