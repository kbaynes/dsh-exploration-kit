---
type: ADR
title: "ADR-0036 — Never wait unboundedly on a process you no longer need"
description: Never wait unboundedly on a process you no longer need.
status: Accepted
timestamp: 2026-10-03
---

# ADR-0036 — Never wait unboundedly on a process you no longer need

## Status

Accepted

## Context

This is the second half of the hang that [ADR-0035](0035-a-background-launch-is-killed-by-the-pid-you-started.md) diagnosed. With the orphan leak fixed, the suite still stopped producing output — this time for 34 minutes inside one lesson, with a live harness process and a `sleep 1` beside it.

The boot was not the problem. Run by hand, the same read-phase boot reached its readiness line in **5 seconds**:

```
t= 5s size=1350 last=[l5-probe] done
t=10s size=1350 last=[l5-probe] done
```

and then the *caller* hung. The harness process had reached its pattern, so `boot_and_wait` had moved on to cleanup:

```sh
kill "$pid"                 # TERM
…
kill -9 "$pid"              # insist
wait "$pid"                 # <-- no timeout, and it never returned
```

The process **survived `SIGKILL`**:

```
$ kill -0 70300 && echo "ALIVE after kill -9"
ALIVE after kill -9
```

`SIGKILL` cannot be caught, blocked or ignored by a process in a normal state. A process that outlives it is stuck in an uninterruptible kernel wait — and whatever the cause, `wait` on it blocks forever. `wait` has no timeout, so the helper that was supposed to protect the suite became the thing that hung it.

The lesson generalises past this one cause: **a cleanup path must never be able to block indefinitely**, because it runs at the moment something has already gone wrong.

## Decision

Reaping is bounded, and a survivor is reported rather than waited for:

```sh
kill "$pid"                 # ask
# …bounded grace…
kill -9 "$pid"              # insist
local reap=0
while kill -0 "$pid" 2>/dev/null && (( reap < 10 )); do sleep 0.5; reap=$((reap + 1)); done
if kill -0 "$pid" 2>/dev/null; then
  echo "      (boot $pid survived SIGKILL and is not reapable; continuing without waiting)" >&2
else
  wait "$pid" 2>/dev/null
fi
```

`wait` is called only once the process is known to be gone, which makes it a reap rather than a gamble. The same bound was applied to every other place that reaps a process it started: `stop_mock_llm` and L7's turn phase.

## Consequences

- A stuck harness can no longer hang the suite. The worst case is a reported survivor and a live process that the next run may notice through its lock — which is exactly what the lock is for ([ADR-0030](0030-verification-owns-the-harness-home.md)).
- The check now says what happened. "survived SIGKILL and is not reapable" is a much better diagnostic than a suite that stops printing.
- A residual, invisible cost remains: such a process may still hold the harness home. The suite cannot fix that, so the rule stands that the home is owned by one run at a time and a survivor must be found by hand.
- The cause of the uninterruptible stall is **not** established. It has been seen once, on a resumed-session boot, in a nested-sandboxed environment. What is fixed is the consequence; the cause is recorded here as open.

## Sibling

[ADR-0037](0037-a-wait-is-bounded-by-the-wall-clock.md) removes the other half of the same defect: this record bounds a `wait` on a process, and that one bounds a *sleeping poll*, which was counted in iterations and therefore inherited whatever `sleep` cost on the host.

## Follow-up — a survivor answers the NEXT run, which is worse than a port error

A verification that had been aborted mid-phase left a harness holding a fixed port. The next run failed with `EADDRINUSE`, which at least names the problem. Then the same thing happened again and the symptom changed: the POSTs **were answered**, by the stray, which had its own session baseline — so the new run's delivery count lagged by exactly one delivery and the phase looked like it was measuring asynchronously.

Two rules came out of it, both now in the L9 webhook phase:

- **Pick a free port at run time.** A fixed port converts any survivor from an earlier run into a failure of the *next* run, and a survivor that outlives `SIGKILL` cannot be cleaned up by hand.
- **Reap on ANY exit.** The teardown lived at the end of the phase, so an abort earlier — a `set -u` violation on a typo did it — skipped it entirely. A trap on `EXIT` covers the paths you did not plan for.

## Evidence

The reproduction, run by hand rather than through the suite:

```
$ ( cd <checkout> && exec dsh --profile kitdemo --patch …/l5.read.patch.yml --port 0 --no-open ) >> log 2>&1 &
$ pid=$!
t= 5s size=1350 last=[l5-probe] done      # readiness reached, fast
t=15s size=1350 last=[l5-probe] done      # nothing more to say
$ kill -0 $pid && echo alive
alive
$ kill -9 $pid; wait $pid                 # ... and this never returned
```

Before the bound, the suite's own symptom was silence: 34 minutes with the last printed line six checks earlier, and `sleep 1` — not a grace sleep — sitting under the stuck harness.
