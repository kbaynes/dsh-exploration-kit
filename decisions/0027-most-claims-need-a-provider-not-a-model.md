---
type: ADR
title: "ADR-0027 — Most 'needs a model' claims need a provider, and the repository ships a keyless one"
description: Most 'needs a model' claims need a provider, and the repository ships a keyless one.
status: Accepted
timestamp: 2026-10-03
---

# ADR-0027 — Most 'needs a model' claims need a provider, and the repository ships a keyless one

## Status

Accepted

## Context

Four lessons carried gaps recorded as "needs a model": a headless run and its exit codes, the `--json` event stream, token accounting, a real fan-out, a task firing, an SDK round trip. Each was treated as unreachable, which is why the ledger's status was *Partly executed* rather than executed for months of this project's life.

They do not need a model. They need a **provider**, and the repository ships a scriptable one: `dsh-llm-mock-server`, a Messages-compatible endpoint that streams scripted behavior. Pointing the shipping DeepSeek adapter at it runs the real agent loop — tool pipeline, session log, token accounting, turn lifecycle — with no credential:

```sh
pnpm run mock:llm --port 8129 --api-key mock-key --sequence success --repeat-last

DEEPSEEK_BASE_URL=http://127.0.0.1:8129/v1 DEEPSEEK_API_KEY=mock-key \
  dsh --profile headless --patch <model-patch> "say hi"
```

```
$ ... dsh --profile headless ...
mock response recovered
EXIT=0
```

The model's *output* is scripted; everything else is real. That is exactly the right trade for verifying contract-shaped claims (codes, streams, lifecycle, accounting) as opposed to quality-shaped ones (does the text read well, does the tool choice make sense).

## Decision

A claim is only recorded as needing a model when it depends on model **judgement**. A claim that depends on the loop, the protocol, or the log is verified against the mock provider, keyless.

Two details that cost iterations and are now in the scripts:

- **The mock consumes one scripted entry per REQUEST, and a turn does not necessarily make exactly one.** Sequencing entries across runs couples the result to an implementation detail. One behavior per mock instance, with `--repeat-last`, is deterministic.
- **`turn_end` is a phase inside a `status` event, not an event type.** Asserting on the type string tested nothing; the documented stream content is `"phase":"turn_end"`.
- **Killing the `pnpm run` wrapper leaves the node server holding the port.** The next run then times out waiting for a `ready` record that cannot bind, which looks like a mock failure rather than a leak.
- **The mock scripts a tool CALL, not only text.** `--sequence tool_call_success[,success] --tool-name <tool> --tool-arguments '<json>'` makes the harness validate and dispatch a real tool. That reaches checks living in a tool *executor* rather than in a service, which no text-only mock can touch: the workspace-authority refusal, the skill body loading on demand, and the `tool_call`/`tool_result` pair in the headless JSON stream are all verified this way. Because the arguments are fixed **before** the harness boots, any value the call must carry — a session id, a skill name — has to be a constant that the probe also uses.
- **A result's *status* can be host-dependent.** Whether a dispatched tool can actually run may depend on the machine (this one has no usable sandbox backend, so `bash` is refused at execution). Assert the stream **contract** — the event, the tool name, the parsed input, the shared `callId` — and leave the outcome to the host, or the check will pass on one machine and fail on another.

## Consequences

- L9's headless contract — exit codes, stdout/stderr separation, and the `--json` stream — is executed, and the technique is reusable for the SDK, webhook, and task-firing claims that remain.
- "Needs a credential" is now a narrower and more honest category than "needs a model": an SDK round trip or a real provider's behaviour still needs a key, but the harness's own contract does not.
- Three later gaps named in the ledger as "needs a model-driven tool call" turned out to need only a scripted call: L5's skill body loading, L7's cross-workspace refusal, and L9's tool-call event in the JSON stream. The phrase was accurate about the *mechanism* and wrong about the cost, which is the same mistake this ADR was written to correct.
- Verification depends on a *test-support* package of the checkout under test, so it is tied to a source checkout — which the lessons already require.

## Evidence

`solutions/verify-l9.sh` runs two mock instances — one that always succeeds and one that always fails — and asserts eight properties across them, including that a successful `--json` stream carries `"phase":"turn_start"`, `"phase":"turn_end"`, a `text` event, and a closing `final`. Recorded in [VERIFIED.md](../VERIFIED.md) under "Evidence: L9 the headless contract".
