# Lesson 2 verification — overlay composition and the specifier trap
#
# Verifies, without needing a model provider:
#   1. a valid overlay composes and resolves the module to the right file
#   2. the module specifier does not silently double a path segment
#   3. the config value is carried into the composed row
#   4. the plugin declares a closed-union Schemastery Config
#   5. two stacked --patch overlays give last-write-wins on the config row
#
# NOT verified here: that a schema-invalid value is rejected at load.
# `--dump-config` composes rows and does not run Schemastery validation; that
# requires booting the harness with the plugin actually mounting.
#
# Usage:  bash solutions/verify-l2.sh /path/to/deepseek-harness
set -uo pipefail

DSH_CHECKOUT="${1:-}"
if [[ -z "$DSH_CHECKOUT" || ! -d "$DSH_CHECKOUT" ]]; then
  echo "usage: bash solutions/verify-l2.sh /path/to/deepseek-harness" >&2
  exit 2
fi

KIT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"  # solutions/ -> repo root
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

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

dump() { # dump <extra patch args...>
  (cd "$DSH_CHECKOUT" && dsh --profile web "$@" --dump-config 2>&1)
}

echo "== 1. valid overlay composes =="
out="$(dump --patch "$KIT/solutions/l2.patch.yml")"
check "overlay row present" "id: l2-wordcount" "$out"
check "module resolves to the kit file" "solutions/l2/wordcount.ts" "$out"
# The specifier is relative to the PATCH FILE; a workspace-relative path silently
# doubles a path segment. Guard the trap explicitly.
if grep -q "solutions/l2/l2/wordcount" <<<"$out"; then
  echo "FAIL  module specifier doubled a path segment"
  failures=$((failures + 1))
else
  echo "PASS  no doubled path segment"
fi
check "config value carried" "defaultUnit: lines" "$out"

echo
echo "== 2. schema declares defaultUnit as a closed union =="
# NOTE: `--dump-config` composes config rows; it does NOT run Schemastery
# validation, so an invalid value cannot be observed here. Validation runs when
# the plugin loads, which requires booting the harness. This check only confirms
# the schema is declared; boot the plugin to see the rejection.
if grep -q "Schema.union(\['words', 'lines', 'chars'\])" "$KIT/solutions/l2/wordcount.ts"; then
  echo "PASS  Config declares a closed union for defaultUnit"
else
  echo "FAIL  Config union not found in wordcount.ts"
  failures=$((failures + 1))
fi
if grep -q "export const Config: Schema<Config>" "$KIT/solutions/l2/wordcount.ts"; then
  echo "PASS  Config is exported as both a type and a runtime schema"
else
  echo "FAIL  Config export shape not found"
  failures=$((failures + 1))
fi

echo
echo "== 3. stacked overlays, last write wins =="
out2="$(dump --patch "$KIT/solutions/l2.patch.yml" --patch "$KIT/solutions/l2.override.patch.yml")"
check "override value wins" "defaultUnit: chars" "$out2"

echo
if [[ "$failures" -eq 0 ]]; then
  echo "Lesson 2 verified: overlay composition, correct module resolution, closed-union"
  echo "schema declaration, and last-write-wins across stacked overlays."
  echo "NOT verified here: that an invalid value is rejected at load — that needs a"
  echo "harness boot with the plugin actually mounting (see VERIFIED.md)."
else
  echo "$failures check(s) failed."
  exit 1
fi
