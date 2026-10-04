---
type: ADR
title: "ADR-0029 — A delivery receipt records admission, not completion; never assert on it"
description: A delivery receipt records admission, not completion; never assert on it.
status: Accepted
timestamp: 2026-10-03
---

# ADR-0029 — A delivery receipt records admission, not completion; never assert on it

## Status

Accepted

## Context

Lesson 9's delivery phase reads the schedule's delivery history, then reads the session log to ask what the delivered turn did:

```js
if (deliveries > 0) break          // receipt observed
...
const log = await ctx.sessionQuery.readSession(session.id)
const assistant = types.filter(type => type === 'assistant/message').length
console.log(`[l9-fire] assistant messages in the session: ${assistant}`)
```

It passed while being developed and failed in a full-suite run:

```
FAIL  the scheduled work ran: a second assistant message in the session
      expected: assistant messages in the session: 2
PASS  and the delivered turn COMPLETED rather than failing
```

The receipt is appended when the reminder is **admitted to the inbox**, which is before the agent has run a single step. The log read raced the delivered turn, so it saw only the warm-up turn's assistant message. The companion assertion passed for a worse reason: with the delivered turn still open, the *last* `turn/end` in the log was the warm-up turn's `{"kind":"completed"}`. So it reported success while describing the wrong turn — the same false-green shape as L7's search that matched other sessions, and just as invisible from the check's output.

Two properties make this general rather than a quirk of `ctx.schedule`:

- **An acknowledgment is an event about admission.** A receipt, a queue record, or an accepted delivery proves the work was *taken*, not that it *finished*. The gap is unbounded: it is the whole duration of the work.
- **A "most recent closed turn" is not a label.** If the observer counts turns rather than identifying them, one previously closed turn is indistinguishable from the delivered one.

## Decision

Never assert completion from an acknowledgment record. Poll for the state that completion implies, and state the baseline that distinguishes it:

```js
const warmupTurns = warmed.filter(event => event.type === 'turn/end').length
...
while (endsOf(log) <= warmupTurns && Date.now() < settleDeadline) {
  await new Promise(resolve => setTimeout(resolve, 1000))
  log = await ctx.sessionQuery.readSession(session.id)
}
```

The baseline is the load-bearing part. This probe deliberately runs a warm-up turn first, so an absolute count of assistant messages is not a count of *delivered* messages.

## Consequences

- L9's delivery phase measures the delivery it claims to measure. The flake is explained rather than recorded as "not reproduced", which is where it would otherwise have sat.
- The rule generalises to every acknowledgment-shaped API in the kit's orbit — delivery receipts, inbox admissions, `delivery-accepted` log events. All of them are permission to *wait*, not evidence to *assert*.
- It is the third instance of one failure mode in this repository: an assertion that passes while measuring something other than its claim. The first two are recorded in ADR-0028 and in the L7 evidence. Naming the pattern is more useful than fixing three instances.

## Evidence

The full-suite run that caught it:

```
FAIL  solution: lesson 9
        PASS  the receipt records when it was delivered
        FAIL  the scheduled work ran: a second assistant message in the session
              expected: assistant messages in the session: 2
        PASS  and the delivered turn COMPLETED rather than failing
```

`solutions/verify-l9.sh` phase 8 asserts the three lines and passes on repeat runs with the wait in place.
