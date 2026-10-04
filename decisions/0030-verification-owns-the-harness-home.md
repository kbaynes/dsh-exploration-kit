---
type: ADR
title: "ADR-0030 — Verification owns the harness home; one run at a time"
description: Verification owns the harness home; one run at a time.
status: Accepted
timestamp: 2026-10-03
---

# ADR-0030 — Verification owns the harness home; one run at a time

## Status

Accepted

## Context

Every per-lesson check boots `dsh` against **one** `$DSH_HOME` and creates sessions in it. During this project a suite run reported:

```
FAIL  solution: lesson 7
        PASS  the JSON block is the target seq
        PASS  a BEFORE neighbour is summarised
        PASS  AFTER neighbours are summarised
        PASS  and the turn completed

        5 check(s) failed.
```

Lesson 7 passed when run on its own, immediately afterwards, with 40 passing checks and no failures. The difference was not in the kit: a **manual `dsh` boot had been pointed at the same `$DSH_HOME` while the suite was running**. Two harnesses against one home share the session store, the profile locks and the browser-less server ports, and the resulting breakage lands on whichever check happens to be running.

This is the second time a collision was misread as a flake. The first is recorded in PLAN as "flake investigated, not reproduced" — a single 18/1 observation that stayed unexplained for several rounds. That entry was later traced to a real bug ([ADR-0029](0029-an-acknowledgment-is-not-a-completion.md)), but the *reason it was easy to misread* is the same: a red suite has no way to say "something else was using the home".

Two facts make this a design constraint rather than a habit:

- **The home is shared state by construction.** `DSH_HOME` holds the profiles, the session store, and the locks. Nothing in the suite isolates one check's home from another check's, because re-installing the kit bundle per check would dominate the runtime.
- **A session id is not enough to avoid it.** Checks use distinct session ids, which is why this looked safe. The collision is in the *store* — the profile's lock files and storage handles — not in the identifiers.

## Decision

`scripts/check-kit.mjs` takes a **lock** in the harness home before the first harness-booting check, and refuses to start if another run holds it:

```
$ node scripts/check-kit.mjs /path/to/deepseek-harness
Another check:kit run (pid 4711) is using /tmp/dsh-reloc.
Two suites against one harness home corrupt each other's sessions, so this
run stops rather than reporting the collision as a lesson failure (ADR-0030).
```

Details that matter:

- The lock is taken **lazily**, only when a checkout is supplied, because the environment-free checks boot nothing and must stay runnable in parallel.
- It is taken **exactly once per run**. The first implementation called `takeLock()` before every check; the second check then found *its own* lock, concluded another run was active, and the suite exited 2 about a second in. A lock that counts the holder as a competitor is worse than no lock.
- It records a **pid**, and a lock whose process is gone is replaced with a warning — a killed run must not block the next one forever.
- Liveness is a **bare pid check**, and the limitation is stated rather than hidden: pids are reused, so a dead run's number can belong to an unrelated live process and block this one. The obvious hardening — ask the OS for the holder's command line — was tried and **removed**: `ps` is blocked outright under some sandboxes (`/bin/ps: Operation not permitted`), where the check silently decided every lock was stale. A false "held" is visible and the message names the file to remove; a silently ignored lock is not.
- It is released on normal exit and on `SIGINT`/`SIGTERM`, so Ctrl-C does not leave it behind.
- It does **not** try to detect a stray manual `dsh`. No lock can see that; the runbook and this record are what tell a human not to do it.

## Consequences

- The collision now fails with its own message and exit code 2, which is distinguishable from a lesson failure. A future contributor sees the cause instead of a flaky lesson.
- Two *humans* cannot run the suite concurrently against one home. That is the intended trade: the suite already needs a private home, and the alternative is silent corruption.
- A manual `dsh` against the same `$DSH_HOME` is still possible and still harmful. The rule is stated in `dsh-exploration-kit/AGENTS.md` and here: while the suite is running, the home is owned by it.
- The stale-lock path is deliberately forgiving, which means a genuine reuse of a *live* pid could in principle block a run. The message names the pid and the file to remove, so the failure is actionable rather than mysterious.
- The lock's own first bug is the reason this record exists in the shape it does. It was found by running the suite, not by reading the code — the same rule the curriculum applies to everything else ([ADR-0001](0001-verify-by-running.md)).

## Evidence

The failure above, and the clean run that followed it with nothing else touching the home:

```
$ bash solutions/verify-l7.sh /path/to/deepseek-harness
… 40 PASS, 0 FAIL, exit 0
```

`scripts/check-kit.mjs` exits 2 with the message above when the lock is held, and removes the lock on exit. Both paths were exercised:

```
$ echo $$ > /tmp/dsh-reloc/.check-kit.lock        # a live holder
$ DSH_CHECKOUT=… node scripts/check-kit.mjs
Another check:kit run (pid 9598) is using /tmp/dsh-reloc.
… exit 2

$ echo 999999 > /tmp/dsh-reloc/.check-kit.lock    # a dead holder
$ DSH_CHECKOUT=… node scripts/check-kit.mjs
WARN  replacing a stale check:kit lock from pid 999999 (that process is gone)
PASS  harness-state records
```
