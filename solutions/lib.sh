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
  ( cd "$checkout" && dsh --profile "$profile" "${args[@]}" --port 0 --no-open >>"$log" 2>&1 ) &
  local pid=$!

  local waited=0
  while (( waited < timeout )); do
    grep -qE "$pattern" "$log" 2>/dev/null && break
    sleep 1
    waited=$((waited + 1))
  done

  kill "$pid" 2>/dev/null
  wait "$pid" 2>/dev/null

  if grep -qE "$pattern" "$log" 2>/dev/null; then
    return 0
  fi
  echo "      (boot did not reach /$pattern/ within ${timeout}s)" >&2
  return 1
}
