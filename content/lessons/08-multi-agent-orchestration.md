---
type: Exploration Lesson
title: "L8 — Orchestrate multiple agents"
description: Delegate with subagents and forks, fan work out with the workflow engine, compare decomposition against a monolithic run, and opt into agent teams.
resource: dsh
tags: [deepseek-harness, lesson, subagents, workflow, orchestration, agent-teams, presets]
timestamp: 2026-09-30
---

# L8 — Orchestrate multiple agents

**Goal.** By the end of this lesson you can split work across isolated contexts,
collect structured results, and justify the split with the numbers you learned to
produce in L7.

**Why here.** Everything so far ran in one context. Orchestration is the capability
most likely to be over-applied, so it is scheduled *after* you can measure it.

## Concepts taught

| Concept | What you learn |
|---|---|
| `subagent` | Delegate a self-contained task to a child that does not share this context |
| `subagent_fork` | Seed a child with this conversation, for work that builds on it |
| Continuable children | `send_message`, `interrupt_agent`, `list_agents` over a live child |
| Providers | `spawn` and `fork` in-process, plus ACP/Claude Code/Codex/dsh-sdk alternatives |
| `workflow` | A JS script with `agent()`, `pipeline()`, `parallel()`, `phase()`, `log()`, `args` |
| Schema-validated results | `opts.schema` turning a child's prose into a checked object |
| Session forking | `ctx.agents.create({ seed, meta })` at a turn boundary |
| Agent presets | Per-session capability sets; a service row there needs an `isolate` realm |
| Agent teams | Roster, task board, mailbox — opt-in, and it displaces the legacy control names |

Reference: the repository's
[subagent subsystem](https://github.com/deepseek-ai/deepseek-harness/blob/main/docs/subsystems/subagent.md),
[workflow package](https://github.com/deepseek-ai/deepseek-harness/tree/main/packages/workflow),
and [agent-team subsystem](https://github.com/deepseek-ai/deepseek-harness/blob/main/docs/subsystems/agent-team.md).

## Prerequisites

L1–L7 complete. A model provider is required — this lesson is meaningless without
one. You need L7's token-accounting routine.

## Step 1 — One delegation, deliberately scoped

The base bundle already makes delegation available: `subagent` uses the `spawn`
provider with `backgroundMode: continuable`, and `subagent_fork` uses the `fork`
provider with model selection omitted so provider/model stay equal to the parent
(which keeps the inherited history eligible for KV-cache reuse).

Use it on a real task in your exploration workspace, for example:

> *Ask the agent to delegate: "Read `doc/exploration/feature-map.md` and report
> every capability in section 5 as a compact table."*

Then ask the follow-up question that matters: **what did the child not know?**
A spawned child does not share this conversation's context — that is its value and
its cost. Confirm it can `list_agents` and `send_message` to the child afterward,
because the base row is continuable, and `interrupt_agent` to stop it.

Choose between the two delegation tools on one axis: `subagent` when the task is
self-contained and the parent's context would only be noise; `subagent_fork` when
the task genuinely builds on this conversation. Forking to avoid writing a good
task description is a common and expensive mistake.

## Step 2 — Fan out with a workflow

The `workflow` tool takes a JavaScript script and runs agents from it. Learn the
shape by using every hook once:

```js
const sections = ['1. Plugin core', '2. Extension seams', '3. Agent runtime']

phase('audit')

const results = await pipeline(
  sections,
  async (section, _item, index) => {
    log(`auditing ${section}`)
    return agent(
      `Read doc/exploration/feature-map.md and return the rows under "${section}" ` +
      `as a JSON array of {capability, providedBy}.`,
      {
        label: `audit-${index}`,
        schema: {
          type: 'object',
          properties: {
            rows: {
              type: 'array',
              items: {
                type: 'object',
                properties: {
                  capability: { type: 'string' },
                  providedBy: { type: 'string' },
                },
                required: ['capability', 'providedBy'],
                additionalProperties: false,
              },
            },
          },
          required: ['rows'],
          additionalProperties: false,
        },
      },
    )
  },
)

return results.filter(Boolean)
```

The mechanics worth internalizing:

- **`pipeline(items, ...stages)` has no barrier between stages.** Each item flows
  independently, so a slow item does not hold up the rest. Prefer it over
  `parallel()` unless a stage genuinely needs every prior result together.
- **A schema turns prose into a checked object.** Without one you get text back and
  you will write a fragile regex to parse it.
- **A throwing stage drops that item to `null`** and skips its remaining stages —
  which is why the script filters `Boolean` at the end rather than assuming a
  dense array.
- **`phase()` and `log()` are real API, not decoration.** They drive the progress
  a human sees, and they are the difference between a five-minute fan-out and an
  opaque one.

Misusing a hook — bad arguments, an unsupported schema keyword, a tripped cap —
ends the whole script rather than yielding `null`. Read the failure; it names the
offending argument.

## Step 3 — Compare decomposition to a monolithic run

This is the lesson's actual deliverable. Take one task you have already run
monolithically and run it again as a fan-out. For each run, record the four audit
parts from L7: the task, turn/step counts, token totals, and the events that prove
them.

Then answer honestly:

| Question | What a good answer looks like |
|---|---|
| Did decomposition reduce tokens, or only latency? | Fan-out often *increases* total tokens while reducing wall-clock time |
| Did output quality improve or degrade? | Structured schemas usually help; lost context usually hurts |
| Was the parallelism real? | In-process providers still share one machine's CPU and model quota |
| What would you do differently next time? | The only question that transfers to the next task |

If the fan-out was not better, that is a successful lesson. Orchestration has a
cost, and finding the boundary where it stops paying is the skill.

## Step 4 — Fork a session at a turn boundary

Programmatic forking is the seam behind `subagent_fork`:

```ts
ctx.agents.create({
  sessionId,
  seed,
  meta: { parentSession, seedLength },
})
```

Only agent-loop-published sessions persist, and the forked header carries an
`isSeeded` lineage bit plus the exact inherited cut — a projection's `init` receives
that cut and must not infer it from `firstLiveSeq`. Re-read your L6 projection and
confirm it uses the cut it was given. If it guesses, forks will misreport state.

## Step 5 — Opt into agent teams (optional, deeper)

Teams layer a durable roster, task board, and mailbox over continuable subagents on
`ctx.agentTeams`. They are **not** enabled in the base bundle. The shipped
`agent-team-profile` patch is the documented way in, and it is instructive to read
before applying, because it disables the legacy continuable-child control names
(`tool-subagent-control`, `tool-subagent-list-agents`, `tool-subagent`) while
inserting the team plugins with explicit caps:

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

Note what that teaches: swapping a coordination model is a *composition* change,
and the caps are part of the contract rather than optional hardening. The
`agentTeam` session projection replays one root Session into roster, task board,
and mailbox — selecting records by `TeamId`, so events inherited by an ordinary
fork retain the ancestor id and never enter the new root's state.

If you explore teams, stop before making them load-bearing. The package is
explicitly experimental, and the lesson is the mechanism, not the feature.

## Verification

1. A spawned child completes a task while demonstrating it lacks the parent's context.
2. Your workflow returns a dense, schema-validated array — or a filtered one you can explain.
3. `send_message` reaches a live child and `interrupt_agent` stops it.
4. You can produce the four-part audit for a monolithic run *and* a decomposed run of the same task.
5. Your L6 projection consumes the fork-inherited cut rather than inferring it.

## Exit check — you should now be able to explain

- When a fork is right and when a spawn is right, in terms of context, not convenience.
- Why `pipeline` is preferred over `parallel` and when the barrier is genuinely required.
- What a schema changes about your error handling.
- Why teams disabling the legacy control tools is a design statement, not an oversight.

## Next

[L9 — Automate the harness](./09-automation-and-triggers.md).
