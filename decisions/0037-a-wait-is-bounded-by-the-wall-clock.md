---
type: ADR
title: "ADR-0037 — A wait is bounded by the wall clock, not by a count of polls"
description: A wait is bounded by the wall clock, not by a count of polls.
status: Accepted
timestamp: 2026-10-03
---

# ADR-0037 — A wait is bounded by the wall clock, not by a count of polls

## Status

Accepted

## Context

The verification suite appeared to break. One full run took **13,666 seconds (3.8 hours)** and a single lesson check **17 minutes** — and every check in both passed. Nothing was wrong with the kit:

```
$ s=$(date +%s); sleep 1; echo $(( $(date +%s) - s ))
1021
```

`sleep 1` took **1,021 seconds**. A minute later the same call took 1 second. The machine stalls periodically (load was 3.75 while otherwise idle), and a stalled `sleep` returns only when the stall ends.

That alone would have been an environment problem. What made it a defect in this repository is how the waits were written:

```sh
local waited=0
while (( waited < timeout )); do
  grep -qE "$pattern" "$log" 2>/dev/null && break
  sleep 1
  waited=$((waited + 1))
done
```

The bound is an **iteration count**, so it inherits whatever each `sleep` costs. On a healthy host that is a 60-second timeout; on a stalled host it is sixty sleeps of 1,021 seconds each — seventeen hours of budget for a check that would have finished in seconds. Nothing reports this: the loop simply keeps going, and every check it guards stays green.

This is the sibling of [ADR-0036](0036-never-wait-unboundedly-on-a-process-you-no-longer-need.md), which removed an unbounded `wait`. Both are about a timeout that does not mean what it says.

## Decision

**A wait that sleeps is bounded by the wall clock.** Compute a deadline once and compare against it:

```sh
local deadline=$(( $(date +%s) + timeout ))
while (( $(date +%s) < deadline )); do
  grep -qE "$pattern" "$log" 2>/dev/null && break
  sleep 1
done
```

Applied to every sleeping wait in the kit: `boot_and_wait`, the mock server's readiness poll, `await_child_usage`, the webhook delivery-count wait, the webhook settle loop, and L7's turn wait.

The same rule in plugin code, which is where a reader will meet it next:

```js
const deadline = Date.now() + 20000
while (!settled() && Date.now() < deadline) {
  await new Promise(resolve => setTimeout(resolve, 500))
}
```

**The carve-out is deliberate and narrow.** Grace and reap loops — `while kill -0 "$pid" && (( grace < 20 ))` — stay counted in iterations, because their bodies are cheap signal checks rather than sleeps, so their cost is the host's process-table latency and not its timer behaviour. The rule is about sleeps. A loop that sleeps *and* counts is the one that lies.

## Consequences

- **A stalled host fails a check loudly instead of hanging the suite.** Verified in both directions: the stalled runs failed where they previously passed slowly, and a healthy window gives `verify-l2` in 3s and the full suite 20/20 in 172s.
- **Timeouts now mean what they say**, so they can be reasoned about: 60 seconds is 60 seconds, and raising one is a deliberate choice about how long a boot may take.
- **One sleep's inflation remains.** The deadline is checked between sleeps, so a stall can add at most the cost of the sleep in progress — about 17 minutes in the worst case observed. That is inherent to sleeping; a caller that needs tighter bounds should shorten its interval, and callers here poll every 1–2 seconds.
- **Recorded timings are host-dependent**, and the ledger now says so. A suite measured at 165–214s in a healthy window took 3.8 hours during a stall, so a timing claim is a statement about a host as well as about the kit.
- It also removed a smaller amplification found while chasing this: `await_child_usage` re-walked every session directory in a poll loop, so a scan over a large disposable home was multiplied by the number of polls. It now finds the child's log once and reuses the path (ADR-0032's rule, met a third time).

## Evidence

The measurement, and the loop that ignored it:

```
$ s=$(date +%s); sleep 1; echo $(( $(date +%s) - s ))
1021
$ uptime
 8:42  up 6 days, 20:41, 6 users, load averages: 5.49 4.65 4.64

# the shape that made a 60-second budget unbounded
while (( waited < timeout )); do grep -qE "$pattern" "$log" && break; sleep 1; waited=$((waited + 1)); done
```

Before and after, on the same tree, in different windows:

```
$ bash solutions/verify-l2.sh <checkout>      # during a stall
exit=1 elapsed=1021s passes=7                 # the deadline fired, loudly

$ bash solutions/verify-l2.sh <checkout>      # healthy window
exit=0 elapsed=3s passes=13 fails=0

$ pnpm run check:kit                          # healthy window
20 passed, 0 warned, 0 failed, 0 skipped      # 172s
```
