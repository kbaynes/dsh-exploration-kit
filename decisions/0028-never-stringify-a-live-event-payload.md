---
type: ADR
title: "ADR-0028 — Never JSON.stringify a live event payload; the Cordis proxy throws on toJSON"
description: Never JSON.stringify a live event payload; the Cordis proxy throws on toJSON.
status: Accepted
timestamp: 2026-10-03
---

# ADR-0028 — Never JSON.stringify a live event payload; the Cordis proxy throws on toJSON

## Status

Accepted

## Context

Lesson 5's turn observer logged the `agent/pre-step` payload the lazy way:

```js
ctx.on('agent/pre-step', async (payload, next) => {
  console.log('[l5-observer] pre-step', JSON.stringify(payload).slice(0, 160))
  return next()
})
```

Every real turn in the kit's composition then died two milliseconds after `turn/start`, with the session recording only:

```
turn/end  {"reason": {"kind": "error", "error": {"message": "cannot get property \"toJSON\" without inject", "code": "UNKNOWN"}}}
```

No `step/start`, no model request, no assistant message. The observer's own log line never printed, because the throw happened inside the `JSON.stringify` call that was building it.

The payload type explains it. `agent/pre-step` carries a **live** payload, not durable data:

```ts
'agent/pre-step'(this: Scoped<Agent>, payload: {
  agent: Agent; messages: UserMessage[]; turn: number; step: number; signal: AbortSignal
}, next: () => Promise<PreStepDecision>): Promise<PreStepDecision>
```

`payload.agent` is reached through a Cordis context proxy. `JSON.stringify` probes a value for a `toJSON` method before serializing it, and that property read lands on the proxy, which Cordis answers with `cannot get property "toJSON" without inject` — the caller never declared `toJSON` as an injected service. The error is a property-access failure, not a serialization failure, which is why the message names `toJSON` and says nothing about the payload.

Two properties made this expensive to find:

- **It was misattributed upstream, twice.** The error message names a harness-internal property, and the kit's `settings`-adjacent code does call `schema.toJSON()`, so the failure was recorded as an upstream defect in `VERIFIED.md` and pinned as such in `solutions/verify-l7.sh`. Two rounds of auditing 119 entry Config schemas went into a bug that was in the kit's own observer.
- **A thrown listener aborts the turn.** The dispatch is not defensive: an exception in one `agent/pre-step` listener ends the turn with an error, so a logging statement in a *lesson* plugin can silently take out the whole composition.

## Decision

Never `JSON.stringify` a value that came from a live event payload, a service, or an `Agent`. Log the fields you need, by name:

```js
ctx.on('agent/pre-step', async (payload, next) => {
  console.log(`[l5-observer] pre-step turn=${payload.turn} step=${payload.step} messages=${payload.messages?.length ?? '?'}`)
  return next()
})
```

Durable data — session events read back through `sessionQuery`, `session.log.events` — is plain lossless JSON and is safe to stringify; that distinction is the rule, not "never serialize".

When a diagnostic is needed for a live value, project explicitly (`{ id: agent.session.id }`) or use a harness renderer, rather than handing an object graph to `JSON.stringify`.

## Consequences

- Turns in the kit's composition complete: `step/start`, `assistant/message`, `step/end`, `turn/end`, with real mock-provider requests. This unblocked L5's catalogue claim, L7's real turn, L9's delivery, and every other "a turn is involved" gap at once.
- A claim that names `toJSON` is now a prompt to grep *the kit* first. The upstream `schema.toJSON()` call in `packages/settings/...` remains real, but it was not this failure.
- Lesson 5's observer is also a better teaching example for this: it shows that a listener must treat a payload as live, opaque, and potentially proxied.

## Evidence

Before the fix (`solutions/verify-l5.sh` composition, mock provider, `DSH_HOME=/tmp/dsh-reloc`):

```
[l5-cat] event types: ...turn/start,agent/inbox/spliced,agent/inbox/spliced,turn/end
[l5-cat] catalogue mentions 'repo-onboarding': false
mock requests: 0
```

After the fix, the same command:

```
[l5-observer] pre-step turn=1 step=1 messages=2
[l5-cat] event types: ...turn/start,...,step/start,system/message,user/message,...,request/header,
         request/context,session/title,assistant/message,step/end,turn/end
[l5-cat] catalogue mentions 'repo-onboarding': true
[l5-cat] body loaded into the log: false
mock requests: 2
```

`repo-onboarding: true` is Lesson 5's headline claim — the skill catalogue reaches the model's context as durable data — and `body loaded: false` is its pair, the on-demand body.
