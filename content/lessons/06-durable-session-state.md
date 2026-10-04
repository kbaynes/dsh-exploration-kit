---
type: Exploration Lesson
title: "L6 — Give the session durable state"
description: Add a new SessionEventMap event, append it durably, fold it into a projection a client can read, and prove it survives a restart.
resource: dsh
tags: [deepseek-harness, lesson, sessions, persistence, projections, session-events]
timestamp: 2026-09-30
---

# L6 — Give the session durable state

**Goal.** By the end of this lesson your plugin has a new kind of durable session
fact, a projection that folds it, and a demonstration that the fact is still
readable after the process restarts.

**Why here.** L5 showed that injected context is durable because it lands in the
log. This lesson makes you the author of that log rather than a passenger,
which is what L7 (replay and cost) and L8 (forked sessions) both assume.

## Concepts taught

| Concept | What you learn |
|---|---|
| Durable derived state | State that survives a restart is *derived from the log*, not stored beside it |
| Known event vocabulary | A plugin may fold first-party event types; inventing one makes the log unreadable |
| Log-only vs surface events | Only message-producing events reach the model; log-only events do not |
| Projections | `ctx.sessionProjections.register(definition)` folds committed events into readable state |
| `stateOf` / `snapshot` | Reading one unit versus one consistent cut over all client-visible units |
| Complete-state events | A state-carrying event carries the post-change state, never a bare delta |
| Restart as the test | In-process behaviour cannot distinguish durable state from a cache |

Reference: the repository's
[session subsystem](https://github.com/deepseek-ai/deepseek-harness/blob/main/docs/subsystems/session.md),
[session projection README](https://github.com/deepseek-ai/deepseek-harness/blob/main/packages/session/session-projection/README.md),
and the [persistence catalog](https://github.com/deepseek-ai/deepseek-harness/blob/main/docs/persistence-catalog.md).

## Prerequisites

L1–L5 complete. You need L5's central claim — the log is the source of truth — plus
your reload loop.

## Step 1 — Durable state is derived, and only from events the harness knows

Two rules decide whether plugin state survives a restart, and the second is the one that
catches people:

1. **Derive it.** State that is reconstructed by folding the session log needs no
   separate storage, and cannot drift from the log it describes.
2. **Fold event types the harness already has.** A plugin-declared event type is writable
   and foldable, and it makes the session **unreadable** after a restart. Step 4
   demonstrates that failure; this step builds the version that works.

The harness does this itself. `@deepseek-ai/dsh-sandbox-policy` keeps a `sandboxMode`
projection unit that folds `sandbox/mode` — a first-party, log-only event recording the
session's permission mode — so the mode the model is told about comes from the log rather
than from out-of-band state. This lesson builds the same shape.

## Step 2 — Fold it into a projection

The kit splits the definition from the registration so the interesting part is testable
without a session. `<kit>/kit-plugins/l6/fold.js`:

```js
import { z } from 'zod'

export const stateSchema = z.object({ mode: z.string() })

/** The event type this unit folds. First-party, therefore known to the harness. */
export const FOLDED_EVENT = 'sandbox/mode'

export const projection = {
  key: 'l6Mode',
  stateSchema,
  stateVersion: 1,
  init: () => ({ mode: 'unknown' }),
  apply: (state, event) =>
    event.type === FOLDED_EVENT ? { mode: event.data.mode } : state,
  wire: {
    viewSchema: stateSchema,
    view: state => ({ mode: state.mode }),
  },
}
```

and `<kit>/kit-plugins/l6/projection.js` registers it:

```js
import { projection } from './fold.js'

export const name = 'l6-projection'
export const inject = ['sessionProjections']

export function apply(ctx) {
  ctx.sessionProjections.register(projection)
  console.log('[l6-projection] ACTIVE — registered the l6Mode unit')
}
```

Both schemas are **Zod**, not raw JSON Schema: the registry calls `.parse()` on them. And
`key` is not a free string — it is `keyof SessionProjectionStateMap`, an empty
merge-extensible table, so an undeclared key fails to typecheck:

```ts
declare module '@deepseek-ai/dsh-session-projection/types' {
  interface SessionProjectionStateMap { l6Mode: { mode: string } }
  interface SessionProjectionMap { l6Mode: { mode: string } }
}
```

Design constraints that are not optional:

- **`apply` is synchronous** and must return the *same state reference* for events that do
  not concern the unit. An unchanged reference means zero downstream work; the registry
  compares consecutive `wire.view` results with `Object.is`.
- **`stateVersion` bumps whenever state fields or fold semantics change.** Registrants with
  the same key *and* version share cells; an incompatible version throws.
- **Registration is an effect on the calling fiber**, so unload removes the key and its
  cached cells.
- **A unit without a `wire` block stays host-only.** Add yours only when a client needs it.

Run the pure tests — the fold's contracts are checked here, without a session:

```sh
pnpm run check:units
```

## Step 3 — Prove it across a RESTART

**In-process behaviour cannot distinguish durable state from a cache.** The projection will
report the right value immediately after an event is appended whether or not it is durable,
so the only test that means anything is a second process.

The kit ships the probe in two phases.

**Phase one** — derive the mode, then change it:

```sh
dsh --profile kitdemo --patch <kit>/solutions/l6.probe.patch.yml --port 0 --no-open
```

```
[l6-probe] created session-l6-verify-…
[l6-probe] mode at creation: {"mode":"workspace-write"}
[l6-probe] mode after switching the preset: {"mode":"danger-full-access"}
```

The preset switch is a real service call — the same one the `/permission` control makes —
and it appends a `sandbox/mode` event. No model is involved.

**Phase two** — a fresh process:

```sh
dsh --profile kitdemo --patch <kit>/solutions/l6.resume.patch.yml --port 0 --no-open
```

```
[l6-probe] resuming session-l6-verify-… in a fresh process
[l6-probe] RESUMED mode: {"mode":"danger-full-access"}
```

That value was not remembered by the projection. On load the session replayed its persisted
log, the registry folded it, and the state was *reconstructed*. That is what makes the log
the source of truth and projections caches.

`ctx.agents.resume({ resumeSessionId })` is what reopens it, and
`solutions/verify-l6.sh` runs both phases and asserts the value survives — generating a
fresh session id each time, because sessions persist and a fixed id would fail the second
run with `already exists`.

## Step 4 — The trap: inventing an event type destroys the session

Lesson 6 originally did this instead: declare a new `SessionEventMap` type, append it, and
fold that. It passed the architecture doc's "extend `SessionEventMap`" description, and it
is wrong in a way that only a restart reveals.

`<kit>/kit-plugins/l6/hazard-custom-event.js` is that plugin, kept deliberately. Enable it
and repeat the two phases:

```sh
dsh --profile kitdemo --patch <kit>/solutions/l6.hazard.patch.yml --port 0 --no-open
```

```
failed to read stored session "…": session "…" contains event type "l6/step" (seq 4)
unknown to this harness and not marked ignorable;
refusing to interpret the log — it was likely written by a newer harness
```

The session **cannot be opened at all**. The event was writable and foldable in the process
that wrote it, so everything looked correct until the restart.

Why: `validateStoredEvents` rejects a stored event outside the harness vocabulary unless its
envelope carries `ignorable: true`; the persistence catalog states that external plugin
types are outside its inventory; `KNOWN_SESSION_EVENT_TYPES` is a static, generated set with
no runtime registration; and `session.append()` cannot set `ignorable`. **A type merge
typechecks, the append succeeds, and the log is still unreadable** — type-checking is not
availability.

It is also contagious: full-text search observes whole sessions, so one session carrying an
unknown type makes `searchSessions` fail for the corpus. See
[ADR-0024](https://github.com/REPLACE_OWNER/dsh-exploration-kit/blob/main/decisions/0024-do-not-invent-session-event-types.md).

If you need a genuinely new durable fact, the vocabulary has to grow in the harness, not in
a plugin outside it.

## Step 5 — Why an event carries complete state

The fold above *replaces*, because `sandbox/mode` carries the complete post-change state:
the mode **is** the value. A second event naming `danger-full-access` yields that mode, not
a combination.

That is the rule for any event that carries a value: **never a bare delta**, because replay
has no reliable "previous" to accumulate against. A delta-shaped event produces silently
wrong state after a restart — the hardest kind of bug to notice, since it looks correct
until the log is replayed.

A fold may legitimately *accumulate* instead, but only over events that are immutable and
appended exactly once, like counting `tool/result` occurrences. Choose deliberately: the
question is whether the event carries your state, or merely tells you that something
happened.

## Verification

```sh
bash <kit>/solutions/verify-l6.sh <path/to/deepseek-harness>
```

All of it runs **without a model**, and the restart is asserted in two processes:

1. The projection's pure core passes its unit tests (`pnpm run check:units`).
2. The fold uses a **known** event type (`sandbox/mode`), not a plugin-declared one.
3. Phase one: the mode is derived at session creation, and changes when the preset changes.
4. Phase two: a **fresh process** resumes the session and reports the mode it ended with —
   reconstructed from the persisted log.
5. The persisted log is readable after the restart, so no plugin invented an event type.

Item 5 is not decoration: it is the check that would have caught the original lesson's
defect, and it is the one that fails if anyone reintroduces an invented type.

Every item above has been executed; the exact output is quoted in
[VERIFIED.md](https://github.com/REPLACE_OWNER/dsh-exploration-kit/blob/main/VERIFIED.md),
which also records what this lesson does *not* verify: the fold's behaviour under a real
model turn, which is a question about the model rather than about durable state.

## Exit check — you should now be able to explain

- Why "model-visible means logged" is a *checked* invariant rather than advice.
- When an event needs a `surfaceOp` and when that parameter is forbidden.
- (Deferred to L8) Why a projection may not use `firstLiveSeq` to infer a fork-inherited cut.
- Why an in-process assertion cannot distinguish durable state from a cache.
- What breaks if `apply` returns a fresh equal object on irrelevant events.

## Next

[L7 — Operate the harness](./07-operating-the-harness.md),
where your new events become part of a trajectory you can query and audit.
