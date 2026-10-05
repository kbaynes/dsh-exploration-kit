#!/bin/bash
# Shared helpers for the per-lesson verification scripts.
#
# Sourced, not executed:  source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
#
# The reason this exists is the boot wait. Every verification boots the harness, lets a probe
# run, and then reads what the probe logged. A fixed sleep has to be long enough for the
# slowest machine and is wasted time on the fastest — and when it is too short the failure is
# silent, because a killed-too-early boot produces an empty log and a check that asserts on a
# *pattern's absence* still passes. Waiting for the probe's own completion line removes both
# problems: each boot ends when the work is done, and a timeout is reported.
#
# Every probe in this kit prints `[<lesson>-probe] done` as its last line, which is the
# readiness pattern callers pass.

# Boot a profile with overlays and wait until the log matches a pattern.
#
#   boot_and_wait <checkout> <profile> <logfile> <pattern> <timeout-seconds> [overlay...]
#
# Returns 0 when the pattern appeared, 1 on timeout (the log is left for inspection).
boot_and_wait() {
  local checkout="$1" profile="$2" log="$3" pattern="$4" timeout="${5:-60}"
  shift 5
  local args=()
  for overlay in "$@"; do args+=(--patch "$overlay"); done

  : > "$log"
  # `exec` is LOAD-BEARING. Without it, `$!` is a subshell and the TERM below kills the SUBSHELL,
  # orphaning `dsh`: the harness keeps running, keeps holding its profile, and is never reaped.
  # Over many suite runs that accumulated 1166 live processes on one machine and eventually hung
  # the suite (ADR-0035). With `exec`, the subshell BECOMES the harness, so `$!` is the process
  # that must die.
  ( cd "$checkout" && exec dsh --profile "$profile" "${args[@]}" --port 0 --no-open ) >>"$log" 2>&1 &
  local pid=$!

  # Wall-clock deadline, not an iteration count: `sleep 1` can take minutes on a stalled host, and
  # a nominal 60-second timeout must not become hours (see PLAN's performance notes).
  local deadline=$(( $(date +%s) + timeout ))
  while (( $(date +%s) < deadline )); do
    grep -qE "$pattern" "$log" 2>/dev/null && break
    sleep 1
  done

  # Ask politely, then insist, then STOP WAITING.
  #
  # `wait` has no timeout, and a harness process can survive even SIGKILL - observed here: a
  # resumed-session boot reached its readiness line in 5s, then outlived `kill -9` and blocked the
  # caller's `wait` forever, which hung the whole suite with no output for half an hour
  # (ADR-0036). A verification helper must never be able to block indefinitely on a process it no
  # longer needs, so the reap is bounded and a survivor is reported rather than waited for.
  kill "$pid" 2>/dev/null
  local grace=0
  while kill -0 "$pid" 2>/dev/null && (( grace < 20 )); do
    sleep 0.5
    grace=$((grace + 1))
  done
  if kill -0 "$pid" 2>/dev/null; then
    echo "      (boot $pid did not exit within 10s of TERM; killing)" >&2
    kill -9 "$pid" 2>/dev/null
  fi
  local reap=0
  while kill -0 "$pid" 2>/dev/null && (( reap < 10 )); do
    sleep 0.5
    reap=$((reap + 1))
  done
  if kill -0 "$pid" 2>/dev/null; then
    echo "      (boot $pid survived SIGKILL and is not reapable; continuing without waiting)" >&2
  else
    wait "$pid" 2>/dev/null
  fi

  if grep -qE "$pattern" "$log" 2>/dev/null; then
    return 0
  fi
  echo "      (boot did not reach /$pattern/ within ${timeout}s)" >&2
  return 1
}

# Assert an exit status EXACTLY.
#
# `check` in the lesson scripts greps for a substring, so `check "…" '0' "$status"` also passes
# for 10, 20 or 100, and `'1'` also passes for 10, 11 or 21. Exit codes are the whole claim in
# several phases, so they are compared as values. `failures` is the caller's global.
#   check_exit <label> <expected> <actual>
check_exit() {
  if [[ "$3" == "$2" ]]; then
    echo "PASS  $1"
  else
    echo "FAIL  $1"
    echo "      expected exit $2, got ${3:-<empty>}"
    failures=$((failures + 1))
  fi
}
