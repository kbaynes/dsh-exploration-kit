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

L1–L5 complete. You need the inbox of concepts from L5 — particularly that the log
is the source of truth — plus your reload loop.

## Step 1 — Declare a new event

Create `<kit>/plugins/l6/types.ts`:

```ts
declare module '@deepseek-ai/dsh-session/types' {
  interface SessionEventMap {
    /** A counted exploration step, recorded so a reader can replay it. */
    'l6/step': { label: string; count: number }
  }
}
```

Put the merge on the **producer's** type-only export and import that export for
side effects from consumers — the repository's conversation subsystem is explicit
about this split, and it matters as soon as a client also wants to render your
event. Unlike a Cordis `Events` declaration, a `SessionEventMap` entry must **not**
carry an `@mode` tag — a log event has no dispatch mode, and the persistence-catalog
generator hard-errors on one.

Two rules about this vocabulary decide whether your feature is durable *and*
replayable:

- **Model-visible means logged.** A runtime invariant checks that model requests
  are reconstructable from the log. If you want the model to see something, it
  needs an event; if you only want *readers* to see it, log-only is correct.
- **Do not extend `SurfaceEventType` casually.** Only message-producing events
  reach the model's history. Compaction is the instructive precedent: it adds four
  log-only events and rides its summary on a separate `user/message` with a
  `surfaceOp: { op: 'replace', startSeq, endSeq }`. The surface mutation is a
  deliberate, separate act.

## Step 2 — Append durably

Create `<kit>/plugins/l6/counter.ts`:

```ts
import type { Context } from '@deepseek-ai/cordis'
import type { Session } from '@deepseek-ai/dsh-session'
import './types.ts'

export const name = 'l6-counter'
export const inject = ['agents']

const counts = new WeakMap<Session, number>()

export function apply(ctx: Context) {
  ctx.on('agent/created', (agent) => {
    const session = agent.session
    counts.set(session, 0)
  })

  // Watch committed events: a log-only event reaches the model never,
  // but every registered observer sees it.
  ctx.on('session/event', (session, event) => {
    if (event.type !== 'tool/result') return
    const next = (counts.get(session) ?? 0) + 1
    counts.set(session, next)
    session.append('l6/step', { label: 'tool-result', count: next })
  })
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

Mount `<kit>/plugins/l6.patch.yml` as usual and turn on HMR for the plugin
directory.

## Step 3 — Fold it into a projection

Reading raw events everywhere does not scale. Register a projection unit so any
reader gets current state without re-deriving it:

```ts
import type { Context } from '@deepseek-ai/cordis'
import { z } from 'zod'

// A projection key is typed against a merge-extensible table, so declare yours.
declare module '@deepseek-ai/dsh-session-projection/types' {
  interface SessionProjectionStateMap {
    l6Steps: { total: number }
  }
  interface SessionProjectionMap {
    l6Steps: { total: number }
  }
}

export const name = 'l6-projection'
export const inject = ['sessionProjections']

const stateSchema = z.object({ total: z.number() })

export function apply(ctx: Context) {
  ctx.sessionProjections.register({
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
  })
}
```

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

## Step 4 — Prove durability

This step is the lesson. Do all four, in order:

1. Run a session that triggers tool results and therefore appends `l6/step` events.
2. Note the final count your projection reports.
3. Stop the process entirely.
4. Restart, reopen that session, and read the same projection key again.

The count comes back — and the honest reason is not "the projection remembered
it". The projection is *derived*: the events are in the JSONL log, and the fold
reproduces the state. That is why the log is the source of truth and projections
are caches.

Now inspect the raw evidence: open the session file under `$DSH_HOME/sessions/`
and find your `l6/step` rows. You will see the persisted framing — the session
format is versioned (`session.vN.jsonl`), committed generations are never renamed
or replaced, and a write open publishes a version-named successor beside the
unchanged source.

## Step 5 — Break replay on purpose

Temporarily make the event carry a delta instead of the complete state — for
example append `{ label: 'tool-result', count: 1 }` every time. Replay will now
produce a wrong total, because the fold has nothing to accumulate against. This is
the concrete failure the "complete post-change state" rule prevents. Revert.

## Verification

1. `l6/step` rows are visible in the session's JSONL file.
2. `stateOf(session, 'l6Steps').total` matches the number of appended events.
3. After a full restart, the same key still reports the correct total.
4. Removing the projection plugin and re-reading shows the fold is the only thing
   producing state — the events remain.
5. A delta-carrying event demonstrably breaks the replay total.

## Exit check — you should now be able to explain

- Why "model-visible means logged" is a *checked* invariant rather than advice.
- When an event needs a `surfaceOp` and when that parameter is forbidden.
- Why a projection may not use `firstLiveSeq` to infer a fork-inherited cut.
- What breaks if `apply` returns a fresh equal object on irrelevant events.

## Next

[L7 — Operate the harness](./07-operating-the-harness.md),
where your new events become part of a trajectory you can query and audit.
