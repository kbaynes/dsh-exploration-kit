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

KIT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"  # solutions/ -> repo root

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

dump() { (cd "$DSH_CHECKOUT" && dsh --profile "$PROFILE" "$@" --dump-config 2>&1); }

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
if [[ "$failures" -eq 0 ]]; then
  echo "Lesson 2 verified: bundle row resolution, package naming, closed-union"
  echo "schema, and overlay override of an installed row."
  echo "NOT verified here: rejection of an invalid value at load — that needs a"
  echo "harness boot; the observed output is quoted in the lesson."
else
  echo "$failures check(s) failed."
  exit 1
fi
