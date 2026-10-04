#!/bin/bash
# Assert the opt-in packages are installed in the profiles kit.target.json names,
# pinned to the recorded harness version.
#
# Usage: bash scripts/verify-target.sh
# Prereqs (see the lesson overlays):
#   dsh plugin --profile kitdemo add @deepseek-ai/dsh-tool-session-query@<version>
#   dsh plugin --profile web     add @deepseek-ai/dsh-schedule@<version>
#   dsh plugin --profile web     add @deepseek-ai/dsh-webhook@<version>
set -uo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TARGET_JSON="$REPO/kit.target.json"
[[ -f "$TARGET_JSON" ]] || { echo "missing $TARGET_JSON" >&2; exit 2; }

VERSION="$(node -e "console.log(require('$TARGET_JSON').dsh.version)")"
BASE_PROFILE="$(node -e "console.log(require('$TARGET_JSON').profiles.base)")"
WEB_PROFILE="$(node -e "console.log(require('$TARGET_JSON').profiles.web)")"

failures=0
assert_pin() { # assert_pin <profile> <package> <version>
  local profile="$1" pkg="$2" want="$3"
  local manifest="${DSH_HOME:-$HOME/.dsh}/profiles/$profile/package.json"
  if [[ ! -f "$manifest" ]]; then
    echo "FAIL  no manifest for profile '$profile' at $manifest"; failures=$((failures + 1)); return
  fi
  if grep -q "\"$pkg\": \"$want\"" "$manifest"; then
    echo "PASS  $pkg@$want in profile '$profile'"
  else
    echo "FAIL  $pkg is not pinned to $want in profile '$profile'"
    grep -o "\"$pkg\": \"[^\"]*\"" "$manifest" | head -1 | sed 's/^/        found: /'
    failures=$((failures + 1))
  fi
}

echo "== pinned opt-in packages, at dsh $VERSION =="
assert_pin "$BASE_PROFILE" "@deepseek-ai/dsh-tool-session-query" "$VERSION"
assert_pin "$WEB_PROFILE"  "@deepseek-ai/dsh-schedule" "$VERSION"
assert_pin "$WEB_PROFILE"  "@deepseek-ai/dsh-webhook" "$VERSION"

echo
echo "== the kit bundle is installed and linked, not copied =="
for profile in "$BASE_PROFILE" "$WEB_PROFILE"; do
  manifest="${DSH_HOME:-$HOME/.dsh}/profiles/$profile/package.json"
  [[ -f "$manifest" ]] || continue
  if grep -q '"dsh-exploration-kit-plugins": "link:' "$manifest"; then
    echo "PASS  kit bundle linked in profile '$profile'"
  elif grep -q 'dsh-exploration-kit-plugins' "$manifest"; then
    echo "WARN  kit bundle present in '$profile' but not as a link: install — edits will not take effect live"
  else
    echo "SKIP  kit bundle not installed in '$profile'"
  fi
done

echo
if [[ "$failures" -eq 0 ]]; then
  echo "Pinned harness state verified in the live profiles."
else
  echo "$failures check(s) failed."; exit 1
fi
