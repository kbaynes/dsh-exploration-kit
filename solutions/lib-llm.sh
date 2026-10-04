#!/bin/bash
# A keyless model provider for verification, sourced by scripts that need a real agent turn.
#
# `dsh-llm-mock-server` is the repository's scriptable Messages-compatible endpoint. Pointing
# the shipping DeepSeek adapter at it runs a REAL turn - the agent loop, tool pipeline, session
# log, token accounting - with no provider key. That matters because several lessons' remaining
# claims were recorded as "needs a model" when they needed only a *provider*.
#
#   start_mock_llm <checkout> <port> <sequence>   # sets MOCK_LLM_PID and MOCK_LLM_BASE_URL
#   stop_mock_llm                                 # stops it
#
# The mock's `--sequence` is a FIFO consumed per request, so `success,server_error` gives one
# successful turn and then failures - enough to assert both halves of the headless contract.

MOCK_LLM_PID=""
MOCK_LLM_BASE_URL=""
MOCK_LLM_LOG=""

start_mock_llm() { # start_mock_llm <checkout> <port> <sequence> [extra mock flags...]
  local checkout="$1" port="$2" sequence="$3"
  shift 3
  local log
  log="$(mktemp)"
  MOCK_LLM_LOG="$log"
  # `--repeat-last` keeps the final scripted behavior repeating, so a retry storm cannot
  # exhaust the script and turn an intended failure into an accidental one.
  ( cd "$checkout" && pnpm run mock:llm --port "$port" --api-key mock-key \
      --sequence "$sequence" --repeat-last "$@" >"$log" 2>&1 ) &
  MOCK_LLM_PID=$!

  local waited=0
  while (( waited < 40 )); do
    grep -q '"type":"ready"' "$log" 2>/dev/null && break
    sleep 1
    waited=$((waited + 1))
  done

  MOCK_LLM_BASE_URL="$(grep -o '"baseURL":"[^"]*"' "$log" 2>/dev/null | head -1 | cut -d'"' -f4)"
  if [[ -z "$MOCK_LLM_BASE_URL" ]]; then
    echo "      (mock LLM server did not become ready within 40s)" >&2
    return 1
  fi
  export MOCK_LLM_BASE_URL
  return 0
}

stop_mock_llm() {
  # `pnpm run` spawns node as a CHILD, so killing the pnpm pid leaves the server holding the
  # port - the next run then times out waiting for a `ready` record that cannot bind. Kill both.
  if [[ -n "$MOCK_LLM_PID" ]]; then
    kill "$MOCK_LLM_PID" 2>/dev/null
    wait "$MOCK_LLM_PID" 2>/dev/null
    MOCK_LLM_PID=""
  fi
  pkill -f 'test-support/llm-mock-server/src/bin.ts' 2>/dev/null
  return 0
}

# Count sessions whose header links to a parent, looking only at recently touched files.
#
# The session log is zstd-compressed, so a plain grep cannot see `parentSession` inside it - the
# first version of this counter searched text files and always reported zero. Scoping to recent
# files keeps the decompression cheap.
#
#   count_recent_parent_linked_sessions <minutes>
count_recent_parent_linked_sessions() {
  local minutes="${1:-5}"
  DSH_HOME="${DSH_HOME:-$HOME/.dsh}" SCAN_MINUTES="$minutes" python3 - <<'COUNTEOF'
import os, pathlib, subprocess, time
root = pathlib.Path(os.environ["DSH_HOME"]) / "sessions"
cutoff = time.time() - float(os.environ["SCAN_MINUTES"]) * 60
count = 0
for path in root.rglob("session.v*.jsonl.zstd"):
    try:
        if path.stat().st_mtime < cutoff:
            continue
        body = subprocess.run(["zstd", "-dc", str(path)], capture_output=True, timeout=20).stdout
    except Exception:
        continue
    if b'"parentSession"' in body:
        count += 1
print(count)
COUNTEOF
}
