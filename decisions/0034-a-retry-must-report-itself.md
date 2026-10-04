---
type: ADR
title: "ADR-0034 — A retry must report itself, or it hides the intermittency it exists for"
description: A retry must report itself, or it hides the intermittency it exists for.
status: Accepted
timestamp: 2026-10-03
---

# ADR-0034 — A retry must report itself, or it hides the intermittency it exists for

## Status

Accepted

## Context

Measuring L8's fan-out cost required a **completed** child turn, because the child's token usage lives in its own session log. A delegated child's turn completes only some of the time:

```
child session (uuid)  events  turn closed
e8862110-…              19    yes
efdfb3f5-…              19    yes
167ca512-…              19    yes
b248ca74-…              19    yes
0aba05c6-…              19    yes
90be2113-…              15    NO
1223c99f-…              15    NO
6a5f4b7c-…              15    NO
06602690-…              15    NO
0863805a-…              15    NO
```

A stalled child ends after `request/context` with no `assistant/message`, no `step/end` and no `turn/end`, while the parent returns a normal answer and exits 0. Re-read after 30 seconds, one stalled log was still stalled, so it is a real stall rather than a slower flush.

The check needs a completed child to measure anything, so it has to retry. The question is what the retry does to the *finding*. A retry that succeeds silently converts a 50% product intermittency into a permanently green check — the failure disappears from the only place anyone would ever see it. That is the same shape as the assertions this repository keeps finding: a check that is green because it stopped asking.

## Decision

**A retry reports itself.** The check retries a bounded number of times and prints how many attempts it needed:

```
[l8-cost] child did not complete; retrying the fan-out (attempt 3)
[l8-cost] fan-out attempts needed: 3
```

Three rules go with it:

- **Bounded, and it fails when the retries run out.** If no attempt produces a completed child, the phase fails. A retry loop is not permission to pass without the thing being measured.
- **The retry is part of the reported evidence**, not an implementation detail, so a rise in attempts is visible in the suite output without anyone reading the script.
- **The finding is recorded where a reader will meet it** — the ledger's L8 evidence, the lesson's own warning to the reader, and a PLAN item to investigate the cause — because the check's job is to measure, not to absorb.

## Consequences

- The cost comparison is deterministic in outcome while remaining honest about the input: it always measures a completed fan-out, and it always says how many tries that took.
- An intermittency that would otherwise have been silently swallowed is now evidence with a rate attached (5 of 10), which is what a future investigation needs.
- A future contributor who "simplifies" the loop by dropping the reporting breaks a rule rather than tidying code; that is why this is written down.
- The cause of the stall is **not** established here. Either the child's teardown is raced by the parent's turn ending, or its response is dropped. That remains open, and the ledger says so.

## Evidence

The retry reporting itself, from a run that needed two attempts:

```
[l8-cost] fan-out parent tokens: 31
[l8-cost] fan-out child tokens: (child turn incomplete; phase 6 retries)
[l8-cost] child did not complete; retrying the fan-out (attempt 2)
[l8-cost] fan-out attempts needed: 2
[l8-cost] fan-out child tokens: 26
[l8-cost] monolith tokens: 26
[l8-cost] fan-out total tokens: 57
PASS  the CHILD's tokens are attributed to the child's own session (26)
PASS  the fan-out costs more tokens than one turn (57 > 26)
```

And the stall it exists for, in a child session that never closed:

```
session, subagent/descriptor, sandbox/mode, approval/policy, agent/inbox/spliced, turn/start,
agent/inbox/spliced, step/start, system/message, user/message, user/message, user/message,
request/header, request/context, session/title
```
