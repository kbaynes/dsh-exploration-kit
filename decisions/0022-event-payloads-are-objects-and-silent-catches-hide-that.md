---
type: ADR
title: "ADR-0022 — Event payloads are objects, and a catch-all catch hides getting that wrong"
description: Event payloads are objects, and a catch-all catch hides getting that wrong.
status: Accepted
timestamp: 2026-10-02
---

# ADR-0022 — Event payloads are objects, and a catch-all catch hides getting that wrong

## Status

Accepted

## Context

Two of the kit's own shipped plugins were wrong, and the bug survived until a probe
created a real session:

```js
ctx.on('agent/created', (agent) => {
  counts.set(agent.session, 0)          // payload.session is undefined
})
```

The declaration is
`'agent/created'(payload: { agent: Agent; source: SessionStartSource; signal?: AbortSignal })`
— the listener receives an **object**, not the agent. Consequences differed by lesson:

- **Lesson 6's counter crashed** on the first real session:
  `Invalid value used as weak map key`, thrown from `WeakMap.set`, with a stack pointing
  into the kit's own `counter.js`.
- **Lesson 5's inject plugin did nothing, silently.** Its `try`/`catch` swallowed the
  `TypeError` and logged `skipped: ...`, so the plugin reported success while injecting no
  context at all. That is worse than a crash: nothing surfaces, and the lesson's central
  claim becomes false without anyone noticing.

Both were invisible because **an `agent/created` listener that never fires looks
identical to one that works**. No lesson boot before this created a session.

## Decision

1. **Listener signatures are taken from the event declaration**, not from the event name.
   A payload that carries the subject is destructured: `({ agent }) => …`.
2. **A catch-all `catch` around event handling must not swallow a programming error.**
   Where a plugin catches to tolerate teardown races, the message says so plainly
   (`FAILED to inject: …`), so a wrong payload cannot present as a benign skip.
3. **An agent-scoped listener is verified by creating a session**, which
   `ctx.agents.create()` does without a model. This is what surfaced both bugs and is now
   part of `solutions/verify-l6.sh`.

## Consequences

- Creating a session is cheap and model-free, so "does this listener actually run?" is
  answerable offline for any agent-scoped plugin in this kit.
- The `try`/`catch` guidance changes the kit's own style: tolerate teardown, never
  tolerate your own mistakes.
- Both lessons now document the payload shape as a trap, because it is the kind of error
  a reader will make while adapting the example.

## Evidence

[VERIFIED.md](../VERIFIED.md) "Evidence: L6 executed" quotes the crash stack naming
`kit-plugins/l6/counter.js`, and the post-fix probe output showing the projection folding
appended events. `solutions/verify-l6.sh` fails if any plugin throws on session creation.
