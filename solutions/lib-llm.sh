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
    # Bounded reap for the same reason as boot_and_wait: an unbounded `wait` is a hang waiting to
    # happen, and the `pkill` below is what actually clears the server (ADR-0036).
    local reap=0
    while kill -0 "$MOCK_LLM_PID" 2>/dev/null && (( reap < 10 )); do
      sleep 0.5
      reap=$((reap + 1))
    done
    kill -9 "$MOCK_LLM_PID" 2>/dev/null
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

# --- Token accounting helpers -------------------------------------------------------------
#
# The mock reports REAL usage: `input_tokens` is a constant 3, and `output_tokens` is the
# character count of its scripted reply (23 for "mock response recovered"). The harness records
# that usage twice, which is what makes a cost comparison verifiable at all:
#
#   * the headless `--json` stream carries it on each `status`/`step_end` event;
#   * each session's log carries it on its `assistant/message` events, per turn and per session.
#
# An earlier round of this kit asserted only the SHAPE of the accounting, on the false premise
# that the mock reported no usage. It always did.

# Sum `usage.totalTokens` across a headless `--json` stream's step_end events.
#   sum_stream_usage <stream-file>
sum_stream_usage() {
  STREAM="$1" python3 - <<'SUMSTREAM'
import json, os
total = 0
for line in open(os.environ["STREAM"], encoding="utf-8", errors="replace"):
    try:
        event = json.loads(line)
    except Exception:
        continue
    if event.get("type") == "status" and event.get("phase") == "step_end":
        total += (event.get("usage") or {}).get("totalTokens", 0)
print(total)
SUMSTREAM
}

# Sum `data.usage.totalTokens` across a compressed session log's assistant messages.
#   sum_log_usage <session.v*.jsonl.zstd>
sum_log_usage() {
  LOG="$1" python3 - <<'SUMLOG'
import json, os, subprocess
path = os.environ["LOG"]
body = subprocess.run(["zstd", "-dc", path], capture_output=True, timeout=30).stdout
total = 0
for line in body.decode("utf-8", "replace").splitlines():
    try:
        event = json.loads(line)
    except Exception:
        continue
    if event.get("type") == "assistant/message":
        total += ((event.get("data") or {}).get("usage") or {}).get("totalTokens", 0)
print(total)
SUMLOG
}

# Print the log path of a recent session whose header names the given parent session.
#   find_child_log <parent-session-id> <minutes>
find_child_log() {
  DSH_HOME="${DSH_HOME:-$HOME/.dsh}" PARENT="$1" SCAN_MINUTES="${2:-5}" python3 - <<'FINDCHILD'
import os, pathlib, subprocess, time
root = pathlib.Path(os.environ["DSH_HOME"]) / "sessions"
cutoff = time.time() - float(os.environ["SCAN_MINUTES"]) * 60
needle = ('"parentSession":"%s"' % os.environ["PARENT"]).encode()
found = []
for path in root.rglob("session.v*.jsonl.zstd"):
    try:
        if path.stat().st_mtime < cutoff:
            continue
        body = subprocess.run(["zstd", "-dc", str(path)], capture_output=True, timeout=20).stdout
    except Exception:
        continue
    if needle in body:
        found.append((path.stat().st_mtime, str(path)))
if found:
    print(max(found)[1])
FINDCHILD
}

# Wait for a child's usage, retrying the LOOKUP as well as the read.
#
# A child session is durably recorded when it is announced, but two asynchronous steps stand
# between the parent finishing and its usage being readable: the child's log must appear with its
# header (which carries `parentSession`), and its tail - including the assistant message that
# carries `usage` - must be flushed. The first version of this waited only on the read, so when the
# log was not yet visible the lookup returned nothing and the check reported 0 tokens without
# waiting at all; it passed standalone and failed in the suite (ADR-0032's rule, again).
#
# Prints "<tokens><TAB><log-path>", with 0 tokens on timeout.
#   await_child_usage <parent-session-id> [timeout-seconds]
await_child_usage() {
  local parent="$1" timeout="${2:-25}" waited=0 log="" tokens=0
  while (( waited < timeout )); do
    log="$(find_child_log "$parent" 5)"
    if [[ -n "$log" ]]; then
      tokens="$(sum_log_usage "$log")"
      if (( tokens > 0 )); then
        printf '%s\t%s\n' "$tokens" "$log"
        return
      fi
    fi
    sleep 1
    waited=$((waited + 1))
  done
  printf '0\t%s\n' "$log"
}
