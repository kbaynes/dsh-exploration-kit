---
type: ADR
title: "ADR-0032 — Do not drive a turn before skill discovery reports a complete catalog"
description: Do not drive a turn before skill discovery reports a complete catalog.
status: Accepted
timestamp: 2026-10-03
---

# ADR-0032 — Do not drive a turn before skill discovery reports a complete catalog

## Status

Accepted

## Context

Lesson 5's catalogue probes assert that a skill is announced to the model before its first request. They passed on some runs and failed on others, from the same command in the same harness home:

```
[l5-cat] registry: 1 skill(s), complete=true: repo-onboarding
[l5-cat] skill-catalog messages: 0
[l5-cat] catalogue mentions 'repo-onboarding': false
```

The registry could see the skill, the `skill` tool was visible to the agent, and the skill was model-invocable — and the catalogue still did not appear.

The cause is in `tool-skill`'s pre-step listener:

```js
const snapshot = toolVisible
  ? await ctx.skills.snapshot({ cwd: agent.session.header.cwd, signal, scope: agent })
  : { skills: [], complete: true }
if (!snapshot.complete) return decision
```

Discovery is **incomplete while a watched root is still settling**, and the listener then injects nothing at all — no catalogue, no error, no warning. The prompts for lessons 5 and 9 were driving the first turn immediately after creating the agent, which races that settling window. The failing runs were not a regression in the kit or the harness: the same content passed as soon as the turn started later.

Two details made this expensive:

- **The scoped and unscoped observations differ.** The listener asks with `scope: agent`. Waiting on `ctx.skills.snapshot({ cwd })` alone still raced, because that is a *different* observation; the first fix therefore did not fix anything. Both must be waited on, and the agent-scoped one cannot be observed until the agent exists, so the wait belongs *after* `agents.create` and *before* the first `followup`.
- **A missing catalogue made a companion assertion pass for the wrong reason.** The body check is a negative one ("the body is NOT shipped"), which is trivially true against an empty log, and the "is the catalogue still announced" check searched the whole log for the skill's name — which the mock's own `skill` tool-call arguments satisfy. So the phase that looked greenest was measuring nothing.

## Decision

A verification that depends on discovered skills waits for a **complete** catalog — on both the plain and the agent-scoped view, after the agent exists — before it drives a turn:

```js
let { plain, scoped } = await observeRegistry()
while ((!plain.complete || !scoped.complete) && Date.now() < settleDeadline) {
  await new Promise(resolve => setTimeout(resolve, 500))
  ;({ plain, scoped } = await observeRegistry())
}
```

Two rules follow, and they generalise beyond skills:

- **Never assert on an absence without proving the thing was observed at all.** The negative body check now requires a non-empty log, and the catalogue is read from the message that *carries* it (`source.kind === 'skill-catalog'`) rather than by substring search. A text search over a session log will match the model's own arguments, and then it is measuring the mock, not the harness.
- **Wait on the observation you are actually going to depend on.** The listener's scoped view was the one that mattered; the unscoped view was merely convenient.

## Consequences

- L5's catalogue phases are deterministic: two consecutive runs and a full suite report exactly one `skill-catalog` message and `true` for the announcement.
- The probes now print the registry's state and the catalogue message count, so a future miss says *why* instead of looking like a content bug.
- The wait is on the harness's own readiness signal, not a fixed sleep, so it costs nothing when discovery is already settled.
- This is the fourth instance in this repository of a check that was green or red for a reason other than its claim. The pattern is now named in four ADRs rather than rediscovered four times: [ADR-0029](0029-an-acknowledgment-is-not-a-completion.md) (admission is not completion), [ADR-0028](0028-never-stringify-a-live-event-payload.md) (a misattributed failure), this one, and the L7 search that matched other sessions.

## Evidence

The failure and the fix, same command, same home:

```
# before: the turn raced the settling window
[l5-cat] registry: 1 skill(s), complete=true, agent-scoped complete=true
[l5-cat] skill-catalog messages: 0
[l5-cat] catalogue mentions 'repo-onboarding': false

# after: waiting for both views before the first followup
[l5-cat] registry: 1 skill(s), complete=true, agent-scoped complete=true: repo-onboarding
[l5-cat] skill-catalog messages: 1
[l5-cat] catalogue mentions 'repo-onboarding': true
```

`solutions/verify-l5.sh` phases 8–10 pass, and `check:kit` reports 20 passed, 0 failed.
