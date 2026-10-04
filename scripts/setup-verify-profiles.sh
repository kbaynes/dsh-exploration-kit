#!/bin/bash
# Install everything the per-lesson verification scripts need into the profiles they use.
#
# Two things make this non-obvious:
#   - The lessons boot two different profiles. Lessons 2-5, 7 and 8 use a base-backed
#     profile; lesson 9 needs a web-backed one, because schedule/webhook require services
#     only the web bundle provides (ADR-0016).
#   - The opt-in packages must be installed PINNED, because npm's `latest` tag for them is
#     stale and dsh rejects the version it resolves (ADR-0013).
#
# Usage: bash scripts/setup-verify-profiles.sh <cmd-dir-containing-dsh> [kit-version]
set -euo pipefail

BINDIR="${1:-}"
VERSION="${2:-}"

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [[ -z "$VERSION" ]]; then
  VERSION="$(node -e "console.log(require('$REPO/kit.target.json').dsh.version)")"
fi
BASE_PROFILE="$(node -e "console.log(require('$REPO/kit.target.json').profiles.base)")"
WEB_PROFILE="$(node -e "console.log(require('$REPO/kit.target.json').profiles.web)")"

if [[ -n "$BINDIR" ]]; then
  export PATH="$BINDIR:$PATH"
fi
command -v dsh >/dev/null || { echo "dsh not found on PATH" >&2; exit 2; }

echo "== kit bundle into the base-backed profile '$BASE_PROFILE' =="
dsh plugin --profile "$BASE_PROFILE" add "link:$REPO/kit-plugins"

# Lesson 9's probe lives in the kit bundle but must run on the WEB-backed profile, because
# the `schedule` package it tests needs services only the web bundle provides (ADR-0016).
# So the bundle is installed into both profiles.
echo
echo "== kit bundle into the web-backed profile '$WEB_PROFILE' =="
dsh plugin --profile "$WEB_PROFILE" add "link:$REPO/kit-plugins"

echo
echo "== pinned opt-in package for lesson 7 =="
dsh plugin --profile "$BASE_PROFILE" add "@deepseek-ai/dsh-tool-session-query@$VERSION"

echo
echo "== pinned opt-in packages for lesson 9, into the web-backed profile '$WEB_PROFILE' =="
dsh plugin --profile "$WEB_PROFILE" add "@deepseek-ai/dsh-schedule@$VERSION"
dsh plugin --profile "$WEB_PROFILE" add "@deepseek-ai/dsh-webhook@$VERSION"

echo
echo "Profiles provisioned at dsh $VERSION. Verify the pins with: bash scripts/verify-target.sh"
