---
type: Exploration Lesson
title: "L8 — Orchestrate multiple agents"
description: Delegate with subagents and forks, fan work out with the workflow engine, compare decomposition against a monolithic run, and opt into agent teams.
resource: dsh
tags: [deepseek-harness, lesson, subagents, workflow, orchestration, agent-teams, presets]
timestamp: 2026-09-30
---

# L8 — Orchestrate multiple agents

**Goal.** By the end of this lesson you can split work across isolated contexts, collect structured results, and justify the split with the numbers you learned to produce in L7.

**Why here.** Everything so far ran in one context. Orchestration is the capability most likely to be over-applied, so it is scheduled *after* you can measure it.

## Concepts taught

| Concept | What you learn |
|---|---|
| `subagent` | Delegate a self-contained task to a child that does not share this context |
| `subagent_fork` | Seed a child with this conversation, for work that builds on it |
| Continuable children | `send_message`, `interrupt_agent`, `list_agents` over a live child |
| Providers | `spawn` and `fork` in-process, plus ACP/Claude Code/Codex/dsh-sdk alternatives |
| `workflow` | A JS script with `agent()`, `pipeline()`, `parallel()`, `phase()`, `log()`, `args` |
| Schema-validated results | `opts.schema` turning a child's prose into a checked object |
| Session forking | `ctx.agents.create({ seed, inheritedEventCount, meta })` at a turn boundary |
| Testable orchestration | Parametrising the engine hooks so the pipeline is testable with fakes |
| Agent presets | Per-session capability sets (met properly in L9's webhook request) |
| Agent teams | Roster, task board, mailbox — opt-in, and it displaces the legacy control names |

Reference: the repository's [subagent subsystem](https://github.com/deepseek-ai/deepseek-harness/blob/master/docs/subsystems/subagent.md), [workflow package](https://github.com/deepseek-ai/deepseek-harness/tree/master/packages/workflow), and [agent-team subsystem](https://github.com/deepseek-ai/deepseek-harness/blob/master/docs/subsystems/agent-team.md).

## Prerequisites

L1–L7 complete. A model provider is required — this lesson is meaningless without one. You need L7's token-accounting routine.

## Step 1 — One delegation, deliberately scoped

The base bundle already makes delegation available: `subagent` uses the `spawn` provider with `backgroundMode: continuable`, and `subagent_fork` uses the `fork` provider with model selection omitted so provider/model stay equal to the parent (which keeps the inherited history eligible for KV-cache reuse).

Use it on a real task in your exploration workspace, for example:

> *Ask the agent to delegate: "Read `<kit>/content/feature-map.md` and report every capability in section 5 as a compact table."*

Then ask the follow-up question that matters: **what did the child not know?** A spawned child does not share this conversation's context — that is its value and its cost. Confirm it can `list_agents` and `send_message` to the child afterward, because the base row is continuable, and `interrupt_agent` to stop it.

Choose between the two delegation tools on one axis: `subagent` when the task is self-contained and the parent's context would only be noise; `subagent_fork` when the task genuinely builds on this conversation. Forking to avoid writing a good task description is a common and expensive mistake.

## Step 2 — Fan out with a workflow

The `workflow` tool takes a JavaScript script and runs agents from it. **Neither the tool nor its engine needs installing** — the base bundle mounts `tool-workflow`, `workflow-ptc`, `tool-subagent`, and the fork row, so this lesson adds no plugin to the kit. Confirm that before writing anything:

```sh
dsh --profile kitdemo --dump-config | grep -E 'id: (tool-workflow|tool-subagent|workflow-ptc)'
```

The kit ships the workflow at `<kit>/kit-plugins/l8/audit-workflow.js`. It is split in two **deliberately**, and the split is the lesson's most transferable idea:

```js
// audit-workflow.js — the PURE half, unit-tested without an agent
export const capabilityRowsSchema = { /* object root, additionalProperties: false */ }

export function normalizeResults(results) {
  return results.filter(r => r != null && Array.isArray(r.rows))
}

export function flattenSections(results) {
  return normalizeResults(results).flatMap((r, index) =>
    r.rows.map(row => ({ ...row, sectionIndex: index })),
  )
}

// audit-workflow.js — the half that needs a model
export async function runWorkflow({ agent, pipeline, phase, log }, sections) {
  phase('audit')
  const results = await pipeline(sections, async (section, _item, index) => {
    log(`auditing ${section}`)
    return agent(sectionPrompt(section), { label: `audit-${index}`, schema: capabilityRowsSchema })
  })
  return flattenSections(results)
}
```

The engine injects `agent`, `pipeline`, `phase`, and `log` into the script, so a function taking them as parameters is testable with fakes. That is exactly what `audit-workflow.test.mjs` does — **seven tests, no model** — and it is what lets you trust the orchestration before spending tokens on it:

```sh
pnpm run check:units
```

The mechanics worth internalizing:

- **`pipeline(items, ...stages)` has no barrier between stages.** Each item flows independently, so a slow item does not hold up the rest. Prefer it over `parallel()` unless a stage genuinely needs every prior result together.
- **A schema turns prose into a checked object.** Without one you get text back and you write a fragile regex to parse it. Note the schema shape: an object root, and `additionalProperties: false` on every object node.
- **A throwing stage drops that item to `null`** and skips its remaining stages — it does not reject the whole run. That is why the normalization step exists, and why the test asserting it is the most valuable one in the file.
- **`phase()` and `log()` are real API, not decoration.** They drive the progress a human sees, and they are the difference between a five-minute fan-out and an opaque one.

Misusing a hook — bad arguments, an unsupported schema keyword, a tripped cap — ends the whole script rather than yielding `null`. Read the failure; it names the argument.

## Step 3 — Compare decomposition to a monolithic run

This is the lesson's actual deliverable. Take one task you have already run monolithically and run it again as a fan-out. For each run, record the four audit parts from L7: the task, turn/step counts, token totals, and the events that prove them.

Then answer honestly:

| Question | What a good answer looks like |
|---|---|
| Did decomposition reduce tokens, or only latency? | Fan-out often *increases* total tokens while reducing wall-clock time |
| Did output quality improve or degrade? | Structured schemas usually help; lost context usually hurts |
| Was the parallelism real? | In-process providers still share one machine's CPU and model quota |
| What would you do differently next time? | The only question that transfers to the next task |

If the fan-out was not better, that is a successful lesson. Orchestration has a cost, and finding the boundary where it stops paying is the skill.

## Step 4 — Fork a session at a turn boundary

Programmatic forking is the seam behind `subagent_fork`, and **it is testable without a model** — creating sessions is not a model call. The kit's probe creates a parent, seeds a child from the parent's log, and reports what the child inherited:

```sh
dsh --profile kitdemo --patch <kit>/solutions/l7.patch.yml \
    --patch <kit>/solutions/l8.probe.patch.yml --port 0 --no-open
```

```
[l8-probe] parent log prefix: 5 event(s), seqs 0,1,2,3,4
[l8-probe] child inheritedEventCount: 5
[l8-probe] child header isSeeded: true
[l8-probe] child parentSession: session-l8-parent-…
[l8-probe] child projection: {"mode":"read-only"}
```

That last line is the claim worth pausing on. The child's **L6 projection already reports the mode carried by the inherited event** — heredity observed through *derived state*, not merely through a header field. If your projection inferred the cut instead of reading it, this is where forks would start misreporting, and this is the check that catches it.

Two contracts the probe hit, both precise:

- **The seed must be contiguous from seq 0** — a prefix of the parent's log, which is what "completed-turn seed" means. Passing one later event fails with `seed event at index 0 has seq 4 (expected 0); seed must be contiguous from 0`. So read the prefix from the log rather than assembling one by hand.
- **`inheritedEventCount` is required whenever `meta.isSeeded` is set**, or creation fails with `seeded session requires an inherited event count`. It is the exact inherited prefix length, and the child's header then carries it so a projection's `init` can read the cut instead of inferring it from `firstLiveSeq`.

Only agent-loop-published sessions persist. `bash <kit>/solutions/verify-l8.sh` asserts all four lines above.

## Step 5 — Opt into agent teams (optional, deeper)

Teams layer a durable roster, task board, and mailbox over continuable subagents on `ctx.agentTeams`. They are **not** enabled in the base bundle. The shipped `agent-team` profile patch is the documented way in, and it is instructive to read before applying, because it disables the legacy continuable-child control names (`tool-subagent-control`, `tool-subagent-list-agents`, `tool-subagent`) while inserting the team plugins with explicit caps:

```yaml
- id: tool-subagent-control
  disabled: true
# ...
- insert:
    - id: agent-team
      name: '@deepseek-ai/dsh-experimental-agent-team'
      config:
        maxMembers: 8
        maxTasks: 256
        maxPendingMessagesPerMember: 64
        maxMessageBytes: 65536
        disposalTimeoutMs: 5000
```

Note what that teaches: swapping a coordination model is a *composition* change, and the caps are part of the contract rather than optional hardening. The `agentTeam` session projection replays one root Session into roster, task board, and mailbox — selecting records by `TeamId`, so events inherited by an ordinary fork retain the ancestor id and never enter the new root's state.

If you explore teams, stop before making them load-bearing. The package is explicitly experimental, and the lesson is the mechanism, not the feature.

## Verification

```sh
bash <kit>/solutions/verify-l8.sh <path/to/deepseek-harness>
```

Observable without a model:

1. `tool-workflow`, `tool-subagent`, `tool-subagent-fork`, and `workflow-ptc` are mounted by the base bundle and compose — **this lesson adds no plugin**, which is itself the finding: orchestration is capability the harness already provides.
2. The workflow's pure core passes seven unit tests with a **fake engine** (`pnpm run check:units`): the pipeline drives every item, logs each one, passes the schema through, and a partially failed fan-out still yields a dense array.
3. The result schema has an object root and declares `additionalProperties: false` on every object node.

Executed keyless, against the repository's scriptable mock provider (ADR-0027) — the mock is told to answer the first request with a `subagent` call and every later request with text:

```sh
pnpm run mock:llm --port 8133 --api-key mock-key \
  --sequence tool_call_success,success,success,success --repeat-last \
  --tool-name subagent --tool-arguments '{"description":"fan-out check","prompt":"Report the answer in one short line."}'

DEEPSEEK_BASE_URL=http://127.0.0.1:8133/v1 DEEPSEEK_API_KEY=mock-key \
  dsh --profile headless --patch <model-patch> "delegate the fan-out check"
```

A real delegation follows, and the numbers say what happened:

- **three model requests** — the parent's tool call, the **child's own turn**, then the parent's final answer. A child agent really ran, in its own context.
- **a child session recorded with a parent link** in the session log, so the delegation is durable lineage rather than a transient call.

`bash <kit>/solutions/verify-l8.sh` runs it and asserts all four properties.

Requires a real provider:

5. A spawned child demonstrates it lacks the parent's *conversation* context — the mock cannot show this, because scripted output does not depend on what the child was given.
5. A forked child inherits the cut, and your L6 projection consumes it rather than inferring it — **executed**: the probe asserts the inherited prefix length, the `isSeeded` marker, the parent lineage, and that the projection reflects the inherited event.
6. A real delegation runs a child turn and records it — **executed**, against the mock provider.
6. `send_message` reaches a live child and `interrupt_agent` stops it.
7. A real fan-out returns schema-validated rows.
8. You can produce the four-part audit for a monolithic run *and* a decomposed run of the same task.

Items 6 and 8 are executed and recorded in [VERIFIED.md](https://github.com/kbaynes/dsh-exploration-kit/blob/main/VERIFIED.md). Item 6 is a real delegation — a genuine fan-out where the parent calls the tool, a child runs its own turn, and the child is durably recorded with a parent link. Item 8's four-part audit is produced by the check itself, which measures **26 tokens for one turn and 57 for the same task as a fan-out (parent 31 + child 26)**, attributing the child's share to the child's own session rather than pooling it.

What that comparison does **not** establish is the *magnitude*: the mock's input is a constant 3 tokens and its output is a scripted reply's character count, so the totals prove correct attribution across agents, not a realistic price. Items 4, 5, and 7 remain unverified.

**A warning worth carrying into your own runs.** Measuring that comparison surfaced an intermittency: a delegated child's turn is sometimes left open — the child's session ends after `request/context`, with no assistant message and no `turn/end` — while the parent still returns a normal answer. It happened in 5 of 10 observed runs. If you fan out and the child's session looks truncated, that is this, not your workflow. The verification retries and prints how many attempts it needed so the rate stays visible.

Item 2 is the reason this lesson is worth more than its prose: the orchestration *contract* is tested even though the agents are not.

## Exit check — you should now be able to explain

- When a fork is right and when a spawn is right, in terms of context, not convenience.
- Why `pipeline` is preferred over `parallel` and when the barrier is genuinely required.
- What a schema changes about your error handling.
- Why teams disabling the legacy control tools is a design statement, not an oversight.

## Next

[L9 — Automate the harness](./09-automation-and-triggers.md).
