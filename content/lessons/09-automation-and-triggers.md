---
type: Exploration Lesson
title: "L9 — Automate the harness"
description: Drive dsh from a script, from another program, and from a clock — headless runs, the SDKs, ACP, schedules, and webhooks — then close with the operating bar.
resource: dsh
tags: [deepseek-harness, lesson, automation, sdk, acp, schedule, webhooks, deployment]
timestamp: 2026-09-30
---

# L9 — Automate the harness

**Goal.** By the end of this lesson `dsh` runs without a human at the keyboard:
from a shell, from another program over a protocol, and on a schedule or an
external event.

**Why last.** Automation multiplies every earlier lesson. Doing it first means
debugging a scheduler, a protocol, and a plugin model simultaneously.

## Concepts taught

| Concept | What you learn |
|---|---|
| Headless one-shot | `dsh --profile headless`, `--json`, `--session-id`, exit-code contract |
| TypeScript SDK | `DeepSeekHarness` spawning a runtime and driving turns |
| Python SDK | The same protocol from Python, with an explicit Harness home |
| JSON-RPC | The newline-delimited wire protocol both SDKs and ACP speak |
| ACP | A standard protocol for automation clients, with no human in the loop |
| Schedules | `schedule_create/list/update/delete` — interval, absolute, daily/weekly, cron |
| Webhooks | `ctx.webhookRuntime` turning an external event into a new Session |
| Hook adapters | Claude Code and Codex hook protocols |
| The operating bar | What must be true before any of this ships unattended |

Reference: [headless integration model](https://github.com/deepseek-ai/deepseek-harness/blob/main/docs/harness/headless-integration-model.md),
[integration options](https://github.com/deepseek-ai/deepseek-harness/blob/main/docs/harness/integration-options.md), and the
[operations checklists](https://github.com/deepseek-ai/deepseek-harness/blob/main/docs/operations/index.md).

## Prerequisites

L1–L8 complete, and a model provider configured. L4's policy work is a **hard**
prerequisite here: unattended automation without a policy gate is how experiments
become incidents.

## Step 1 — One-shot from the shell

```sh
dsh --profile headless "summarize doc/exploration/learning-path.md in five bullets"
```

The task comes from the positional argument, or from stdin when the argument is
omitted or is a lone `-`:

```sh
{ echo "Summarize these changes:"; git diff --stat; } | dsh --profile headless
```

Contract details that scripts depend on:

- **Exit codes are the automation surface.** `0` means the task completed; `1`
  means it aborted or errored, printing `dsh: <code>: <message>` to stderr.
- **Reasoning goes to stderr**, final answer to stdout — so `stdout` is safely
  pipeable.
- **`--json` projects the run as newline-delimited events on stdout.** This is
  your hook for a CI job that needs to assert on tool calls, not just on prose.
- **`--session-id` adopts an exact session identity**, and an unknown id fails
  rather than silently starting fresh. That is what makes a multi-step pipeline
  resumable.
- **The boundary is one task per invocation, with no interactive follow-up.**

## Step 2 — Drive it from TypeScript

The SDK spawns a runtime subprocess and drives turns over the same protocol:

```ts
import { DeepSeekHarness } from '@deepseek-ai/dsh-sdk-client'

await using harness = new DeepSeekHarness({
  profile: 'sdk',
  patches: ['./automation.cordis.yml'],
  provider: 'deepseek-official',
  model: 'deepseek-v4-flash',
  maxTokens: 49_152,
})

const result = await harness.run('say hi')
console.log(result.finalResponse)
```

Design points that matter more than the API shape:

- **The subprocess starts lazily and is owned by the instance across `run()`
  calls.** Use `await using` or `close()` so the child is always reaped.
- **`patches` is how you inject your own composition.** The `automation.cordis.yml`
  in the snippet is exactly the file you have been writing since L1 — your plugin
  work becomes SDK launch configuration.
- **`run()` returns `{ sessionId, finalResponse, events, notifications }`, and
  `finalResponse` is the last committed root-session assistant text in the
  interval — not a response causally bound to your prompt.** Steering, injected
  context, and other queued work can contribute before idle. If your automation
  needs causality, use the lower-level `HarnessClient` and drive
  `prompt()`/`subscribe()` yourself.
- **Typed errors exist for every failure mode** — including `TransportClosedError`
  carrying the runtime's exit code and a bounded stderr tail. Branch on these
  rather than parsing messages.

## Step 3 — Drive it from Python

The Python SDK speaks the same protocol:

```python
# deepseek_harness drives a bundled dsh runtime over newline-delimited JSON-RPC
```

Two differences from the TypeScript path are worth knowing before you build:

- **Every launch requires an explicitly selected Harness home.** Python never
  silently reads `~/.dsh`. If your automation relies on ambient configuration, it
  will fail here — deliberately.
- **The SDK starts the matching bundled `dsh --profile sdk` runtime** unless you
  select another executable or profile, and the shipped `sdk-minimal` profile is
  the runnable minimal example.

## Step 4 — Give it a clock

Schedules are Host-owned and survive restarts. They arrive as ordinary follow-up
messages in the original conversation — **not** email, SMS, or push:

```
schedule_create  { ... }
schedule_list    { ... }
schedule_update  { ... }
schedule_delete  { ... }
```

The tool accepts `after_seconds`, an explicit absolute `at`, a bounded fixed-rate
`every_seconds`, daily and weekly local times in an explicit IANA zone, and cron
as a five-field expression. Management uses the Host storage domain, and a due
message resumes the original Session.

Practical exercise: schedule a recurring check of the `doc/` bundle's validation
(`~/.local/bin/okflint validate --manifest doc/okf-base.yaml ./doc/`), let it fire
once, then delete it. Notice what "resumes the original Session" gives you — the
run has your earlier context, which is both the feature and the risk. A reminder
that inherits a long conversation inherits its cost.

## Step 5 — Give it triggers

`ctx.webhookRuntime` is a registry of **trusted** programmatic rules plus one
built-in action: creating an ordinary root Session inside a Web Workspace.

```ts
// WebhookRule<K>: branded `id`, provider `kind`, and run(delivery, signal)
```

Contract points that shape your design:

- **Provider authentication belongs to adapter packages, not the rule.** The rule
  receives a `VerifiedWebhookDelivery` — provider kind, source id, delivery id,
  normalized lossless JSON, and receipt time — already snapshotted and frozen.
- **`deliveryId` records the provider's identifier only; a repeated delivery runs
  the rules again.** Idempotency is your responsibility, not the runtime's.
- **`WebhookSessionRequest` requires `workspacePath`, `title`, `prompt`,
  `agentPreset`, and `permissionPreset`.** Presets are validated before any
  mutation, and presets are your policy lever — this is where L4's work becomes
  the blast radius control.
- **`Agent.followup()` is the commit point.** The runtime does not wait for idle
  or inspect the reply; ordinary agent behavior owns everything after.
- **Registration is an effect**, and its disposer hides the rule then aborts and
  drains active callbacks. Callbacks must observe the supplied signal.

The repository's GitHub review guide is the worked example of a rule module,
dedicated ingress port, secret setup, and Workspace routing. If your trigger is a
GitHub event, read it rather than improvising.

Also worth knowing: `hooks-claude-code` and `hooks-codex` adapt the **hook
protocols** of those tools, so an existing Claude Code or Codex hook can drive a
DSH hook plugin without rewriting it. That is an integration strategy, not just a
compatibility shim.

## Step 6 — Know the operating bar

You have now built everything that makes unattended automation possible. Before
you let it run, walk the checklists — they exist because each one is a way this
fails in production:

| Checklist | The question it answers |
|---|---|
| [Agent container](https://github.com/deepseek-ai/deepseek-harness/blob/main/docs/operations/agent-container.md) | Concurrency governance, turn timeouts, non-root execution, tool scoping, `/v1/agent/turn` and `/healthz` |
| [Kubernetes scaling](https://github.com/deepseek-ai/deepseek-harness/blob/main/docs/operations/kubernetes-scaling.md) | Resource limits, autoscaling signals, disruption budgets, network policy |
| [State & session store](https://github.com/deepseek-ai/deepseek-harness/blob/main/docs/operations/state-session-store.md) | Serialization, distributed locking, TTL, HA for pod-agnostic routing |
| [Telemetry pipeline](https://github.com/deepseek-ai/deepseek-harness/blob/main/docs/operations/telemetry-pipeline.md) | Token cost tracking, tool latency, secret scrubbing |
| [Visualization & alerting](https://github.com/deepseek-ai/deepseek-harness/blob/main/docs/operations/visualization-auditing-alerting.md) | Letting a human notice before the bill does |

Three sentences to carry away: a stateless pod pool requires session state to live
outside the pod (integration option C); the cheapest control is a policy gate at
`tools/pre-execute` plus a restrictive permission preset; and the only automation
you can debug is the automation you instrumented in L7.

## Verification

1. A headless run returns the expected exit code for a success and for a forced failure.
2. `--json` output contains a tool-call event you can assert on.
3. An SDK run loads your `patches` file and executes a tool from an earlier lesson.
4. A scheduled task fires once and is visible in `schedule_list` before you delete it.
5. A webhook rule creates exactly one Session for one delivery — and you have
   stated what happens on a duplicate delivery.

## Exit check — you should now be able to explain

- Why `finalResponse` is not causally bound to your prompt, and when that matters.
- What "explicitly selected Harness home" protects against.
- Why provider authentication is deliberately not the rule's job.
- Which single checklist item you would skip at your peril, and what it would cost.

## Where to go next

- **Find plugins before writing them.** Use the `find-dsh-plugins` skill or the
  recipes in [plugin discovery](https://github.com/deepseek-ai/deepseek-harness/blob/main/docs/harness/plugin-discovery.md) — the community
  registry holds thousands of entries, and the bare GitHub topic filter
  over-matches badly.
- **Publish your work.** Bundle your plugins into a package that declares its role
  under a `dsh` field in `package.json` (`dsh.bundle`, `dsh.profile`) so others can
  stack it in a profile.
- **Re-read the [capability map](../feature-map.md)** now that every row
  means something concrete. The rows you can explain are the ones you have earned.
