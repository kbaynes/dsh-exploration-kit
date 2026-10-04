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
| `SessionEventMap` | The event vocabulary, extended by declaration merging |
| Log-only vs surface events | Only message-producing events reach the model; log-only events do not |
| `session.append(type, data)` | The write path, and why message-producing events additionally require `surfaceOp` |
| Complete-state events | A state-carrying event carries the post-change state, never a bare delta |
| Projections | `ctx.sessionProjections.register(definition)` folds committed events into readable state |
| `stateOf` / `snapshot` | Reading one unit versus one consistent cut over all client-visible units |
| Replay | Why projection state is reconstructible from the log alone |

Reference: the repository's
[session subsystem](https://github.com/deepseek-ai/deepseek-harness/blob/main/docs/subsystems/session.md),
[session projection README](https://github.com/deepseek-ai/deepseek-harness/blob/main/packages/session/session-projection/README.md),
and the [persistence catalog](https://github.com/deepseek-ai/deepseek-harness/blob/main/docs/persistence-catalog.md).

## Prerequisites

L1–L5 complete. You need L5's central claim — the log is the source of truth — plus
your reload loop.

## Step 1 — Declare a new event

Open `<kit>/kit-plugins/l6/types.js`:

```js
/**
 * Type-only declarations for the `l6/step` session event.
 *
 * Declaration merging is erased at runtime, so this file contributes nothing when the
 * plugin runs — but it is what makes `session.append('l6/step', ...)` and
 * `event.data.count` typecheck for consumers. Kept beside the producer, because a
 * session event's vocabulary belongs to whoever produces it.
 *
 * In a TypeScript project this is a `.ts` module imported for its types, and the
 * merge itself looks like this:
 *
 *     declare module '@deepseek-ai/dsh-session/types' {
 *       interface SessionEventMap {
 *         'l6/step': { label: string; count: number }
 *       }
 *     }
 *
 * A SessionEventMap entry must NOT carry an `@mode` tag: a log event has no dispatch
 * mode, and the persistence-catalog generator rejects one.
 */
export const name = 'l6-types'
```

The shipped file is JavaScript with the TypeScript merge documented in a comment,
because this kit's plugins run as plain `.js` (L1). The merge block is the part to
carry into your own TypeScript project — put the declaration on the **producer's**
type-only export and import that export for side effects from consumers, which is the
repository's conversation-subsystem convention and matters as soon as a client also
wants to render your event.

## Step 2 — Append durably

Open `<kit>/kit-plugins/l6/counter.js`:

```ts
export const name = 'l6-counter'
export const inject = ['agents']

/** Per-session running count, kept in memory and mirrored into the log. */
const counts = new WeakMap()

export function apply(ctx) {
  // The payload is an OBJECT — `{ agent, source, signal }` — not the agent itself.
  // Reading `payload.session` rather than `payload.agent.session` fails with
  // "Invalid value used as weak map key" the first time a real session is created.
  ctx.on('agent/created', ({ agent }) => {
    counts.set(agent.session, 0)
    console.log('[l6-counter] tracking a new session')
  })

  // `session/event` sees every committed event. A log-only event never reaches the
  // model, but every registered observer sees it.
  ctx.on('session/event', (session, event) => {
    if (event.type !== 'tool/result') return
    const next = (counts.get(session) ?? 0) + 1
    counts.set(session, next)
    // The event carries the COMPLETE post-change state, never a bare delta:
    // replay has no reliable "previous" to accumulate against.
    session.append('l6/step', { label: 'tool-result', count: next })
  })

  console.log('[l6-counter] ACTIVE — appends l6/step on each tool result')
}
```

`session.append(type, data)` is the write path. The third parameter is
**conditionally** present: for a `SurfaceEventType` event you must pass a
`SurfaceIntent` describing how the event joins the surface (`surfaceOp` and, for
non-assistant messages, the cited `sourceEventSeqs`); for a log-only event the
parameter is forbidden at compile time. Let the compiler tell you which kind you
declared — that is the point of the conditional signature.

Note the shape: the event carries `count`, the **complete** post-change state.
The projection doc is explicit that a state-carrying log event must never carry a
bare delta, because replay has no reliable "previous" otherwise.

The row is already in the bundle, so the plugin loads with the rest. Turn on HMR for
the plugin directory (L3, step 4) if you want edits to take effect live.

## Step 3 — Fold it into a projection

Reading raw events everywhere does not scale. Register a projection unit so any
reader gets current state without re-deriving it:

The kit splits this in two so the interesting part is testable without a session:
`<kit>/kit-plugins/l6/fold.js` holds the pure definition, and
`<kit>/kit-plugins/l6/projection.js` registers it.

```js
// fold.js — the pure core
import { z } from 'zod'

export const stateSchema = z.object({ total: z.number() })

export const projection = {
  key: 'l6Steps',
  stateSchema,
  stateVersion: 1,
  init: () => ({ total: 0 }),
  apply: (state, event) =>
    event.type === 'l6/step' ? { total: event.data.count } : state,
  wire: {
    viewSchema: stateSchema,
    view: state => ({ total: state.total }),
  },
}
```

```js
// projection.js — registration
import { projection } from './fold.js'

export const name = 'l6-projection'
export const inject = ['sessionProjections']

export function apply(ctx) {
  ctx.sessionProjections.register(projection)
  console.log('[l6-projection] ACTIVE — registered the l6Steps unit')
}
```

In a TypeScript project, a projection key must also be declared against a
merge-extensible table:

```ts
declare module '@deepseek-ai/dsh-session-projection/types' {
  interface SessionProjectionStateMap { l6Steps: { total: number } }
  interface SessionProjectionMap { l6Steps: { total: number } }
}
```

Without it, `key: 'l6Steps'` fails to typecheck — the key is not a free string.

Both schemas are **Zod** schemas, not raw JSON Schema objects: the registry calls
`.parse()` on them (`packages/llm/token-meter/src/usage-projection.ts` is a real
unit to compare against). And `key` is not a free string — it is
`keyof SessionProjectionStateMap`, an empty merge-extensible table, so an
undeclared key fails to typecheck.

Design constraints that are not optional:

- **`apply` is synchronous** and must return the *same state reference* for
  events that do not concern the unit — an unchanged reference means zero
  downstream work, and the registry compares consecutive `wire.view` results with
  `Object.is`.
- **`stateVersion` bumps whenever state fields or fold semantics change.**
  Registrants with the same key *and* version share cells; an incompatible version
  throws.
- **Registration is an effect on the calling fiber**, so unload removes the key
  and its cached cells. Watch this happen: with HMR on, edit and save this plugin
  and observe that reading the key immediately after the reload is not stale.
- **A unit without a `wire` block stays host-only.** Add yours only when a client
  needs to see it.

Read it back with `stateOf(session, 'l6Steps')` for one unit, or
`snapshot(session)` for a consistent cut — `{ asOfSeq, values }` — where `asOfSeq`
is the seq every value reflects. Checkpoints persist these units through
`session-projection-cache`, so a cold read need not load the whole log.

## Step 4 — The trap: a new event type destroys the session on restart

**Do not skip this step, and do not write the code above into anything real.**

The `l6/step` event you just declared is a **third-party event type**. The harness knows
the event types it ships with — the persistence catalog states plainly that *"external
plugin types require their own declarations and are outside this catalog"* — and the
storage contract refuses to interpret a log containing a type it does not know:

```
failed to read stored session "session-l7-durability":
session "session-l7-durability" contains event type "l6/step" (seq 4)
unknown to this harness and not marked ignorable;
refusing to interpret the log — it was likely written by a newer harness
```

That is not a warning. The session **cannot be reopened at all**.

Execute the proof, because the failure is the lesson:

1. Boot with the counter enabled and let it append at least one `l6/step` event.
2. Confirm the projection reports a count *in that same process* — it will. The event is
   in the live log, so everything looks correct.
3. Stop the process.
4. Boot again and try to read that session — with the L7 query service, or by resuming it.

```
[l7-probe] RE-READ FAILED: … contains event type "l6/step" (seq 4) unknown to this
harness and not marked ignorable; refusing to interpret the log
```

**Step 2 passing and step 4 failing in the same session is the whole point.** An event
type you invent is writable, foldable, and completely non-durable. Worse, it is
*contagious*: full-text search observes whole sessions, so one session carrying an
unknown type makes `searchSessions` fail for the entire corpus.

This corrects an earlier version of this lesson, which claimed the count would come back
after a restart. It does not. See
[ADR-0024](https://github.com/REPLACE_OWNER/dsh-exploration-kit/blob/main/decisions/0024-do-not-invent-session-event-types.md).

### What to do instead

**Derive durable state from events the harness already knows.** That is the part of this
lesson worth keeping, and it needs no new vocabulary:

```js
// Fold a KNOWN event type. `tool/result` is part of the harness's vocabulary, so a log
// containing it stays readable — and therefore stays durable.
export const projection = {
  key: 'l6Steps',
  stateSchema,
  stateVersion: 1,
  init: () => ({ total: 0 }),
  apply: (state, event) =>
    event.type === 'tool/result' ? { total: state.total + 1 } : state,
  wire: { viewSchema: stateSchema, view: state => ({ total: state.total }) },
}
```

Note what changed: the fold now **accumulates**, because a known event does not carry your
state for you. That is legitimate here — the events are immutable and appended exactly
once, so replay is deterministic. The "complete post-change state" rule from step 5 applies
to events that *carry a value*, which is a different situation from counting events that
already exist.

If you genuinely need a new durable fact, the harness channel for it is a *known* event
type or the plugin-owned mechanisms the architecture doc lists — extending the vocabulary
is a change to the harness, not something a third-party plugin can do from outside it.

## Step 5 — Break replay on purpose

A state-carrying event must carry the **complete** post-change state, never a delta,
because replay has nothing reliable to accumulate against. If you keep a value-carrying
event — including a first-party one — make that mistake deliberately and watch the total
come out wrong. This is the rule the harness's own events follow.

## Verification

Testable without a session, and tested in CI:

```sh
pnpm run check:units     # runs kit-plugins/l6/fold.test.mjs
```

1. Folding `l6/step` events yields the reported total.
2. An unrelated event returns the **same state reference** — the contract that keeps
   a projection from recomputing on every event.
3. A relevant event returns a new reference.
4. A delta-shaped event produces a wrong total, which is *why* producers must send
   complete post-change state.

Requires a session, and therefore a provider:

5. `l6/step` rows are visible in the session's JSONL file.
6. `stateOf(session, 'l6Steps').total` matches the number of appended events.
7. After a full restart, the same key still reports the correct total.
8. Removing the projection plugin and re-reading shows the fold is the only thing
   producing state — the events remain.

The split between `fold.js` and `projection.js` exists so items 1–4 are real tests
rather than assertions about code nobody ran. Items 5–8 are recorded as unverified
in [VERIFIED.md](https://github.com/REPLACE_OWNER/dsh-exploration-kit/blob/main/VERIFIED.md).

## Exit check — you should now be able to explain

- Why "model-visible means logged" is a *checked* invariant rather than advice.
- When an event needs a `surfaceOp` and when that parameter is forbidden.
- (Deferred to L8) Why a projection may not use `firstLiveSeq` to infer a fork-inherited cut.
- What breaks if `apply` returns a fresh equal object on irrelevant events.

## Next

[L7 — Operate the harness](./07-operating-the-harness.md),
where your new events become part of a trajectory you can query and audit.
