---
type: ADR
title: "ADR-0024 — A plugin must not invent a session event type for durable state"
description: A plugin must not invent a session event type for durable state.
status: Accepted
timestamp: 2026-10-02
---

# ADR-0024 — A plugin must not invent a session event type for durable state

## Status

Accepted

## Context

Lesson 6 originally taught that a plugin can add durable session state by declaring a new event type and appending it — "extend `SessionEventMap`, append, restart, read it back". The architecture doc lists exactly that as the mechanism for durable session state, so the lesson was written from the documented extension point.

It does not survive a restart. Executed two-boot experiment:

```
BOOT 1 (write)
  [l7-probe] created session-l7-durability with a distinctive marker
  [l7-probe] readSession: 5 event(s); marker present: true

BOOT 2 (fresh process)
  [l7-probe] RE-READ FAILED: failed to read stored session "session-l7-durability":
    session "session-l7-durability" contains event type "l6/step" (seq 4)
    unknown to this harness and not marked ignorable;
    refusing to interpret the log — it was likely written by a newer harness
```

The same event is *writable and foldable* in the process that wrote it, so everything looks correct until a restart. Then the session cannot be opened at all.

The cause is a deliberate safety property, not a bug. `validateStoredEvents` rejects any stored event whose type is outside the harness's known vocabulary, unless the event envelope carries `ignorable: true` — and the persistence catalog states that *"external plugin types require their own declarations and are outside this catalog"*. `KNOWN_SESSION_EVENT_TYPES` is a static, generated set shipped by `dsh-session`; there is no runtime registration, and `session.append()` offers no way to set `ignorable`.

The damage is not confined to that session. Full-text search observes whole sessions, so one unreadable session poisons the corpus:

```
[l7-probe] searchSessions failed: session-search persistence observation failed:
  session "session-l6-probe-…" contains event type "l6/step" …
```

## Decision

**A plugin derives durable state from events the harness already knows.** Inventing an event type is not an available extension point for third-party code, whatever the type-level declaration merging makes possible.

- The supported pattern is a projection that folds a **known** event type (`tool/result`, `turn/end`, …).
- A fold over known events may accumulate, because those events are immutable and appended exactly once; the "complete post-change state" rule governs events that *carry* a value.
- Adding to the vocabulary is a change to the harness, not something a plugin outside it can do.
- This also means **type-checking is not availability**: the merge typechecks, the append succeeds, and the log is still unreadable. Only executing a restart reveals it.

## Consequences

- Lesson 6's Step 4 now teaches the failure as the lesson, with the observed output, and gives the folding-a-known-event replacement.
- Lesson 7 gains a real caveat: search fails for a corpus containing a session with an unknown event type, and the failure names the offending session.
- The shipped L6 plugins still demonstrate the hazard and must be refactored to fold a known event (tracked in [PLAN.md](../PLAN.md)); until then their ledger row is demoted.
- Anything that writes durable plugin state elsewhere in the harness should be audited against the same test: write, restart, read.

## Evidence

[VERIFIED.md](../VERIFIED.md) "Evidence: L6's durability claim is false as written" quotes both boots and the search failure.

**Late addition — the query layer also cannot see such an event.** Found while verifying Lesson 7: `readSession` returns an invented event, and `filterEvents` finds it neither by type nor by literal text.

```
[l7-probe] readSession: 5 event(s); marker present: true
[l7-probe] filterEvents by type: 0 match(es)
[l7-probe] filterEvents by text: 0 match(es) for an invented type's payload
```

So the true cost of inventing a type is threefold: the session becomes unopenable after a restart, full-text search over the corpus breaks, and the events themselves are invisible to the query layer even while present in the log. `solutions/verify-l7.sh` asserts both filter results, so the limitation is checked rather than described. The two-boot experiment is reproducible with `solutions/l7.probe.patch.yml`'s `write` and `read` modes.
