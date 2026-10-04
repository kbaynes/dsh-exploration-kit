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

Reference: the [headless bundle](https://github.com/deepseek-ai/deepseek-harness/blob/main/packages/bundle/headless/README.md)
and the [SDK family](https://github.com/deepseek-ai/deepseek-harness/blob/main/packages/sdk/README.md).

## Prerequisites

L1–L8 complete, a model provider configured, and — for steps 4–5 — an opt-in package
installed into a **web-backed** profile. L4's policy work is a **hard** prerequisite:
unattended automation without a policy gate is how experiments become incidents.

## Step 1 — One-shot from the shell

```sh
dsh --profile headless "summarize <kit>/content/learning-path.md in five bullets"
```

The task comes from the positional argument, or from stdin when the argument is
omitted or is a lone `-`.

A note on profiles you will see in this lesson: `dsh plugin --profile <name>` creates a
**base-backed** profile from a template, which is how `kitdemo` came to exist in L1.
The `web`, `headless`, and `sdk` profiles are *shipped templates* with their own bundle
stacks — `dsh --profile web` boots one directly, and `dsh rescue --from-default-profile web`
creates an editable copy of one. Which profile a step targets matters, because Lesson 3
and [ADR-0016](https://github.com/REPLACE_OWNER/dsh-exploration-kit/blob/main/decisions/0016-profile-choice-is-load-bearing.md)
show that the same row activates differently per profile.

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
from deepseek_harness import DeepSeekHarness

with DeepSeekHarness(
    dsh_home="/absolute/path/to/isolated-dsh-home",
    cwd="/absolute/path/to/workspace",
    provider="deepseek-official",
    model="deepseek-v4-flash",
    max_tokens=49_152,
) as harness:
    result = harness.run("Say hi.", session_id="example-001")

print(result.final_response)
```

Three differences from the TypeScript path are worth knowing before you build:

- **`dsh_home` is mandatory and explicit.** Python never silently reads `~/.dsh`.
  If your automation relies on ambient configuration, it fails here — deliberately.
  Use an isolated home per tenant so sessions and credentials cannot leak between
  automations.
- **`cwd` is the agent workspace**, while `runtime_cwd` independently selects the
  subprocess working directory. Both are made absolute before launch, and the two
  are genuinely different concerns: where the agent operates versus where the
  runtime process starts.
- **The SDK starts the bundled `dsh --profile sdk` runtime**, so Python does not
  need system Node.js installed. Persistent plugin customization belongs to that
  profile — pass `patches=[...]` for an invocation-specific change, or install an
  external bundle with `dsh plugin --profile sdk add link:/path/to/bundle`.

## Step 4 — Give it a clock

**`@deepseek-ai/dsh-schedule` is mounted by no shipped bundle.** Watch for a trap
when you check: the `schedule` and `webhook` names that *do* appear in the bundle
patches are telemetry tuning keys (`scheduledDelayMillis`), not these packages. A
plausible hit on the wrong symbol can make an unmounted capability look available.
So there are two steps, not one:

```sh
dsh plugin --profile web add @deepseek-ai/dsh-schedule@<dsh version>
```

and then the row, from `<kit>/solutions/l9.patch.yml`:

```yaml
- insert:
    - id: schedule
      name: '@deepseek-ai/dsh-schedule'
```

**Apply it to a web-backed profile, not the base-backed `kitdemo` one.** This is L3's
`PENDING` lesson arriving in a real composition: on a base profile the row activates
nothing, because the services it needs come from the web bundle:

```
schedule (@deepseek-ai/dsh-schedule): pending (waiting for service: sessionController)
```

Once mounted, schedules are Host-owned and survive restarts. They arrive as ordinary
follow-up messages in the original conversation — **not** email, SMS, or push:

```
schedule_create  { ... }
schedule_list    { ... }
schedule_update  { ... }
schedule_delete  { ... }
```

The tool accepts `after_seconds`, an explicit absolute `at`, a bounded fixed-rate
`every_seconds`, daily and weekly local times in an explicit IANA zone, and cron as a
five-field expression. Management uses the Host storage domain, and a due message
resumes the original Session.

Note where those tools are registered: in a **live root Agent's scope**, so they do not
appear in `--dump-config`. Composing cleanly proves the service loaded; seeing the tools
needs a session.

Practical exercise: schedule a recurring check of the kit's own validation
(`okflint validate --manifest okf-base.yaml`), let it fire once, then delete it. Notice
what "resumes the original Session" gives you — the run has your earlier context, which
is both the feature and the risk. A reminder that inherits a long conversation inherits
its cost.

## Step 5 — Give it triggers

`ctx.webhookRuntime` is a registry of **trusted** programmatic rules plus one built-in
action: creating an ordinary root Session inside a Web Workspace.

It is opt-in in the same way as schedules — install the package (pinned) and insert the
row:

```sh
dsh plugin --profile web add @deepseek-ai/dsh-webhook@<dsh version>
```

```yaml
    - id: webhook
      name: '@deepseek-ai/dsh-webhook'
```

It needs even more of the web bundle than `schedule` does; on a base profile it reports
`pending (waiting for services: agentPresets, workspaceRegistry)`. Both requirements are
in `<kit>/solutions/l9.patch.yml` with the reasoning inline.

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
you let it run, be deliberate about the concerns that make it fail in production:

| Concern | The question it answers |
|---|---|
| Container | Concurrency governance, turn timeouts, non-root execution, tool scoping, health endpoints |
| Scaling | Resource limits, autoscaling signals, disruption budgets, network policy |
| State & session store | Serialization, distributed locking, TTL, HA for pod-agnostic routing |
| Telemetry | Token cost tracking, tool latency, secret scrubbing |
| Alerting | Letting a human notice before the bill does |

**DSH publishes none of these as documentation.** They are concerns the harness
*exposes* — through the session log, the telemetry packages, and the plugin seams
you have been using — but the deployment decisions are yours. That boundary is
deliberate: the harness is a runtime, not an operations manual. Read the SDK-minimal
and telemetry bundle rows plus their package READMEs to see what can be observed,
then build the rest to your environment's requirements.

Three sentences to carry away: a stateless pod pool requires session state to live
outside the pod; the cheapest control is a policy gate at `tools/pre-execute` plus
a restrictive permission preset; and the only automation you can debug is the
automation you instrumented in L7.

## Verification

```sh
bash <kit>/solutions/verify-l9.sh <path/to/deepseek-harness>
```

Observable without a model:

1. The overlay inserts `schedule` and `webhook`, and **no shipped bundle already
   provides them** — they are genuinely opt-in, and the shipped bundles' `schedule`/
   `webhook` matches are telemetry knobs.
2. Booting a **web-backed** profile with both installed produces **no activation
   warnings**. On a base-backed profile the same overlay leaves both rows `PENDING`,
   naming the missing services — which is the point, not a defect.
3. The profile manifest pins both packages to your dsh version rather than npm's stale
   `latest`.

Requires a provider:

4. A headless run returns the documented exit code for success and for a forced
   failure.
5. `--json` output contains a tool-call event you can assert on.
6. An SDK run loads your patches file and executes a tool from an earlier lesson.
7. A scheduled task fires once and appears in `schedule_list` before you delete it.
8. A webhook rule creates exactly one Session per delivery, and you have stated what
   happens on a duplicate delivery.

Items 4–8 are recorded as unverified in
[VERIFIED.md](https://github.com/REPLACE_OWNER/dsh-exploration-kit/blob/main/VERIFIED.md).

## Exit check — you should now be able to explain

- Why `finalResponse` is not causally bound to your prompt, and when that matters.
- What "explicitly selected Harness home" protects against.
- Why provider authentication is deliberately not the rule's job.
- Which single checklist item you would skip at your peril, and what it would cost.

## Where to go next

- **Find plugins before writing them.** The community registry and the npm
  `deepseek-harness` keyword are better starting points than a bare GitHub topic
  filter, which matches the ambiguous token `dsh` and returns many unrelated
  projects. See the [publish guide](https://github.com/deepseek-ai/deepseek-harness/blob/main/docs/user/develop/basic/publish.md)
  for how a plugin is packaged, so you can judge what you find.
- **Publish your work.** Bundle your plugins into a package that declares its role
  under a `dsh` field in `package.json` (`dsh.bundle`, `dsh.profile`) so others can
  stack it in a profile.
- **Re-read the [capability map](../feature-map.md)** now that every row
  means something concrete. The rows you can explain are the ones you have earned.
