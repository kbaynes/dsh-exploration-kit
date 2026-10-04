---
type: ADR
title: "ADR-0035 — A background launch is killed by the pid you started, so make that pid the thing you care about"
description: A background launch is killed by the pid you started, so make that pid the thing you care about.
status: Accepted
timestamp: 2026-10-03
---

# ADR-0035 — A background launch is killed by the pid you started, so make that pid the thing you care about

## Status

Accepted

## Context

The suite stopped producing output partway through and hung for over an hour. The log's last line was `PASS solution: lesson 4`; a mock server for L5's phase 10 was alive; and the harness home was contended. The cause was not in any lesson:

```
$ pgrep -f 'apps/cli/lib/bin.js' | wc -l
    1166
```

**1166 orphaned harness processes**, each a `node apps/cli/lib/bin.js --profile … --port 0 --no-open`, accumulated over the project's runs. Every one was still holding its composed profile.

They came from the shared boot helper:

```sh
( cd "$checkout" && dsh --profile "$profile" … >>"$log" 2>&1 ) &
local pid=$!
…
kill "$pid" 2>/dev/null
wait "$pid" 2>/dev/null
```

`$!` is the **subshell**, not the harness. `kill "$pid"` terminates the subshell, and `dsh` — its child — is orphaned rather than killed. The helper returned success, the probe's output was read, and the check passed, so nothing ever noticed. One process leaked per boot, and the suite boots the harness roughly 27 times.

The effects compounded quietly before the hang: process count grew every run, the machine slowed, and the shared harness home had more live writers than it should. It also plausibly contributed to earlier mysteries this project recorded — the shared-home corruption behind [ADR-0030](0030-verification-owns-the-harness-home.md) and intermittent behaviour attributed to timing.

## Decision

A background launch is killed by the pid you started, so **make that pid the process you care about**, and verify that it died.

```sh
( cd "$checkout" && exec dsh --profile "$profile" … ) >>"$log" 2>&1 &
local pid=$!          # now the harness itself
…
kill "$pid"           # TERM
for grace in $(seq 1 20); do kill -0 "$pid" 2>/dev/null || break; sleep 0.5; done
kill -9 "$pid" 2>/dev/null
wait "$pid" 2>/dev/null
```

Three parts, and each covers a different failure:

- **`exec`** removes the subshell from the equation, so the pid that is signalled is the harness.
- **A bounded grace, then `kill -9`** covers a CLI that ignores or outlives `TERM`, and reports when it was needed rather than hanging.
- **`wait`** reaps it, so no zombie is left behind either.

The same fix was applied to the one other place that starts a server in the background — L7's turn phase — because the pattern, not the file, was the defect.

## Consequences

- Two consecutive lesson checks now leave **zero** harness processes and zero mock servers behind, where each previously left one per boot. The suite runs in its normal time instead of hanging.
- The suite's resource use is now flat: a run's process count returns to its starting value, so a future leak shows up as a residual count rather than as a slow degradation nobody attributes to anything.
- **The general rule is worth stating because the code looked correct:** in `( … ) &`, `$!` is a subshell. Any cleanup keyed to `$!` must either `exec` so the subshell becomes the target, or kill the process group. This is the verification equivalent of [ADR-0027](0027-most-claims-need-a-provider-not-a-model.md)'s note that killing the `pnpm run` wrapper leaves the node server holding the port — the same mistake, one level up, in this repository's own harness rather than in a lesson's example.
- The leak was invisible for the project's whole life because every check still passed. Nothing in the suite asserts that the machine is left as it was found; this record is the closest thing to that assertion, and a future contributor adding a background launch should add its reaping too.

## Evidence

The diagnosis, on the hung run:

```
$ tail -3 /tmp/kit.log
PASS  solution: lesson 2
PASS  solution: lesson 3
PASS  solution: lesson 4

$ pgrep -f 'apps/cli/lib/bin.js' | wc -l
    1166
$ lsof -nP -iTCP:8143 -sTCP:LISTEN     # the mock whose phase was waiting
node 64307 … TCP 127.0.0.1:8143 (LISTEN)
```

Cleanup, keeping the session's own GUI process:

```
$ for p in $(pgrep -f 'apps/cli/lib/bin.js'); do [ "$p" = 4401 ] && continue; kill -9 "$p"; done
$ pgrep -f 'apps/cli/lib/bin.js' | wc -l
       0
$ lsof -nP -iTCP:3080 -sTCP:LISTEN | tail -1
node    4401 <user>       15u  IPv4 … TCP 127.0.0.1:3080 (LISTEN)
```

And the leak test after the fix — two lesson checks, both of which boot the harness several times:

```
harness processes before=0 after=0 (0 = no leak)
mock servers left: 0
```
