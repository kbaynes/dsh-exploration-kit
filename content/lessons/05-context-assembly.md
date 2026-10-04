---
type: Exploration Lesson
title: "L5 — Assemble context deliberately"
description: Hook the turn flow, inject model-facing context that lands durably in the log, ship a skill the agent discovers on its own, and add a human command that needs no model turn.
resource: dsh
tags: [deepseek-harness, lesson, context, skills, commands, agent-events, agent-instructions]
timestamp: 2026-09-30
---

# L5 — Assemble context deliberately

**Goal.** By the end of this lesson you control what the model knows at each step:
you inject context from a plugin, you ship a skill the agent discovers without
being told, and you add a `/command` that runs entirely in code.

**Why here.** L4 was about constraining the model. This lesson is about informing
it — the context-engineering half of the harness, and the prerequisite for the
durable state you add in L6.

## Concepts taught

| Concept | What you learn |
|---|---|
| `agent/pre-step` | The waterfall that runs before a request is admitted |
| `agent/request` | The waterfall around the outgoing model request |
| `agent.inject()` | Append durable context the *next* admitted request sees |
| "Not a wake-up" | Injected context does not wake an idle agent |
| Instruction loading | How `AGENTS.md`/`CLAUDE.md` reach context, and why placement matters |
| Skills | A `SKILL.md` catalog discovered from scanned roots, body loaded on demand |
| Human commands | `ctx.commands.register()` — dispatches without a model turn |

Reference: [workspace instruction loading](https://github.com/deepseek-ai/deepseek-harness/blob/main/packages/context/agent-instructions/README.md), the
repository's
[skill filesystem README](https://github.com/deepseek-ai/deepseek-harness/blob/main/packages/skill/skill-filesystem/README.md)
and
[commands README](https://github.com/deepseek-ai/deepseek-harness/blob/main/packages/interaction/commands/README.md).

## Prerequisites

L1–L4 complete. You need the `diagnose` instrument, the reload loop, and the
habit of separating what a boot proves from what a session proves.

## Step 1 — Watch the turn flow before touching it

Open `<kit>/kit-plugins/l5/turn-observer.js`, wired into the bundle:

```js
export const name = 'l5-turn-observer'

export function apply(ctx) {
  ctx.on('agent/pre-step', async (payload, next) => {
    console.log('[l5-observer] pre-step', JSON.stringify(payload).slice(0, 160))
    return next()
  })

  ctx.on('agent/created', ({ agent }) => {
    console.log(`[l5-observer] agent created: ${agent.session.id ?? '(session)'}`)
  })

  console.log('[l5-observer] ACTIVE — watching agent/pre-step')
}
```

The declared payload is:

```ts
'agent/pre-step'(payload: {
  agent: Agent
  messages: UserMessage[]
  turn: number
  step: number
  signal: AbortSignal
}, next: () => Promise<PreStepDecision>): Promise<PreStepDecision>
```

**Take the shape from the declaration, not from the event name.** The payload is an
object, and the subject is `payload.agent` — the same trap that bit this kit's own
`agent/created` listeners, where reading `payload.session` instead of
`payload.agent.session` produced `undefined` and, behind a `try`/`catch`, a plugin that
silently did nothing.

Boot the profile and start a conversation, then read what actually arrives there. The
declaration says which fields *exist*; only a real turn shows you what is *in* them, and
guessing either is the usual source of broken context plugins.

`agent/pre-step` is a **waterfall**: return `next()` to delegate. Several
first-party plugins already listen here, including `agent-instructions`, `plan-mode`,
`tool-skill`, `time-context`, and `session-checkpoint-policy`. You are joining an
existing layer, not replacing it.

**No API key?** The registration is observable at boot — the plugin prints that it is
watching. The payload's shape is observed too, from a real turn against the mock
provider: the observer logs `pre-step turn=1 step=1 messages=2`, and
`solutions/verify-l5.sh` runs it.

## Step 2 — Inject context deliberately

`<kit>/kit-plugins/l5/inject.js` appends context:

```js
import { createUserMessage } from '@deepseek-ai/dsh-llm'

export const name = 'l5-inject'
export const inject = ['agents']

export function apply(ctx) {
  // The payload is `{ agent, source, signal }`, not the agent: destructure it.
  ctx.on('agent/created', ({ agent }) => {
    try {
      agent.inject(createUserMessage({
        content: [
          {
            type: 'text',
            text: 'Exploration mode: when you explain a change, name the file it lands in.',
          },
        ],
        source: { kind: 'l5-inject' },
      }))
      console.log('[l5-inject] context appended to the next admitted request')
    } catch (error) {
      // The agent may already be disposed; never let a notification kill a plugin.
      // Keep it LOUD — a silent catch hides a wrong payload shape, which is how this
      // plugin previously did nothing at all without anyone noticing.
      console.log(`[l5-inject] FAILED to inject: ${error.message}`)
    }
  })

  console.log('[l5-inject] ACTIVE — appends durable context on agent/created')
}
```

Three contract points, each verified against the runtime's own types:

- **`agent.inject()` takes a complete `UserMessage`, not a loose object.** Build it
  with `createUserMessage`, which fills in the role and a stable identity.
- **The source kind is producer-owned.** Each producer declares its own kind; there
  is deliberately no catch-all `plugin` kind to reuse. The upstream cookbook shows
  `source: { kind: 'plugin', plugin: '…' }`, which is stale — that shape is not a
  `UserMessage` source and will not typecheck.
- **It is not a wake-up.** Injected context lands in the *next* admitted request; an
  idle agent stays idle. Guard against a disposed agent, as above.
- **`agent/created` hands you a payload, not an agent.** The listener receives
  `{ agent, source, signal }`, so it is `({ agent }) => …` — not `(agent) => …`. Getting
  this wrong is quiet: `agent.session` is `undefined`, and a `try`/`catch` around it turns
  the whole plugin into a no-op that logs a cheerful success message. That is why the
  catch here says `FAILED` rather than `skipped`, and why this lesson's probe creates a
  session — an agent-created listener that never fires is invisible until one exists.

### Confirming the durability claim — in two processes, with no model

Durability cannot be checked in one process. `agent/created` fires while the session is
being built, so an in-process assertion measures the *queue*, not the log. The kit ships a
probe that does it properly:

```sh
export L5_SESSION_ID="session-l5-check-$RANDOM"
dsh --profile kitdemo --patch <kit>/solutions/l5.probe.patch.yml --port 0 --no-open   # creates a session
dsh --profile kitdemo --patch <kit>/solutions/l5.read.patch.yml  --port 0 --no-open   # a FRESH process
```

```
[l5-probe] re-read 5 event(s): permission/preset, sandbox/mode, approval/policy, agent/inbox/spliced, agent/inbox/spliced
[l5-probe] injected text present after restart: true
[l5-probe] carried by: agent/inbox/spliced
```

**The carrier is worth noticing: an inbox event, not a `user/message`.** `agent.inject()`
queues into the agent's inbox, and that is the durable record. It is also a *first-party*
event type, which is why the log stays readable — the constraint
[ADR-0024](https://github.com/REPLACE_OWNER/dsh-exploration-kit/blob/main/decisions/0024-do-not-invent-session-event-types.md)
records, and the reason L6's original approach had to be rebuilt.

`bash <kit>/solutions/verify-l5.sh` runs both phases and asserts the text is still there.

That is the mechanism L6 builds on: the log is the source of truth, and anything durable
about a session is in it.

## Step 3 — A skill the agent discovers on its own

Skills are the right delivery mechanism for knowledge too large to inject on every
turn and too specific to put in `AGENTS.md`. The kit ships one at
`<kit>/kit-plugins/l5/skills/repo-onboarding/SKILL.md`:

```md
---
name: repo-onboarding
description: Use when asked to explain how the DSH exploration kit is organized, where its knowledge lives, or how to get started reading it.
---

# Kit onboarding

The DSH Exploration Kit is a nine-lesson curriculum for learning DeepSeek Harness by
building real plugins. Its layout:
...
```

Frontmatter rules that bite if ignored: `name` must be kebab-case, `description` is
**required**, and discovery is exactly one level deep — `<root>/<name>/SKILL.md` or
`<root>/<name>.md`. A nested `**/SKILL.md` is deliberately not discovered. An invalid
skill is skipped with a warning, so from the model's point of view a broken skill
looks **identical to an absent one** — a genuinely nasty failure mode, and the reason
the `description` deserves care.

Point a scanned root at the kit's skills with the shipped overlay,
`<kit>/solutions/l5.skills.patch.yml`:

```yaml
- id: skill-filesystem
  config:
    customSkillDirs: [!!js "process.env.KIT_ROOT ? process.env.KIT_ROOT + '/kit-plugins/l5/skills' : undefined"]
    includeDefaultRoots: false
```

Two things about that shape:

- **It is an override, not an insert.** `customSkillDirs` is a config field on an
  existing base-bundle row, so the entry has no `insert` and no `name`. This is the
  same in-place override you used in L2.
- **`includeDefaultRoots: false` makes the experiment unambiguous.** Root resolution
  order is project roots, then `customSkillDirs`, then user roots; disabling the
  default roots means only the kit's skill can appear.

Boot with it:

```sh
KIT_ROOT=<kit> dsh --profile kitdemo --patch <kit>/solutions/l5.skills.patch.yml --port 0 --no-open
```

The directory **need not exist yet** — a missing root is probed until it appears, and
existing roots are watched, so adding or renaming a skill reaches the next catalog
without a restart.

The catalog/body split is the design worth noticing: a model-invocable skill gets a
durable catalog of names and capped descriptions before the first request, and the
body loads only when the agent calls the `skill` tool. That is why `description`
quality decides whether a skill is ever used.

**No API key?** The overlay composes (visible in `--dump-config`), the profile boots
with it, and what the *model* sees is asserted against the mock provider: the session
log carries the skill's name while the body stays out of it. That pair — announced,
not shipped — is the whole design described here.

## Step 4 — A command that needs no model turn

`ctx.commands.register()` gives a human a deterministic entry point.
`<kit>/kit-plugins/l5/commands.js` registers one:

```js
export const name = 'l5-commands'
export const inject = ['commands']

export function apply(ctx) {
  ctx.commands.register({
    name: 'l5-facts',
    description: 'Print how the DSH exploration kit is laid out',
    handler: () => ({
      kind: 'success',
      text: [
        'content/      the curriculum (OKF bundle) — start at content/index.md',
        ...
      ].join('\n'),
    }),
  })

  console.log('[l5-commands] ACTIVE — /l5-facts registered')
}
```

A command line starts with `/`, a lowercase name, then either end-of-input or
whitespace; everything after the name is `rawInput` and the command owns its grammar.
Registering the same name twice in one scope throws. The handler returns `success` or
`error` plus optional UI text.

Type `/l5-facts` in the composer and confirm the reply is immediate. That the handler runs
from plain code is testable rather than merely asserted — the kit's probe dispatches the
command through `ctx.commands.execute`, the same path the composer uses:

```sh
dsh --profile kitdemo --patch <kit>/solutions/l7.patch.yml \
    --patch <kit>/solutions/l5.cmd.patch.yml --port 0 --no-open
```

```
[l5-cmd] resolved: true
[l5-cmd] outcome: {"kind":"success","text":"content/      the curriculum (OKF bundle) — …"}
[l5-cmd] command events in the log: command/run, command/done
[l5-cmd] model-request events in the log: 0
```

**The last line is the claim.** The session records the command's lifecycle events and
**zero model-request events** — which is what "needs no model turn" means in the log, rather
than a claim about responsiveness. (`ctx.commands.execute` takes an Agent, and
`ctx.agents.create` makes one without running a turn, which is why this is reachable offline.)

## Step 5 — Decide where knowledge belongs

You now have four delivery mechanisms, and choosing correctly is most of the
skill:

| Mechanism | Use it for | Cost model |
|---|---|---|
| `AGENTS.md` / `CLAUDE.md` | Workspace-wide rules that always apply | Loaded into every session |
| `agent.inject()` | Facts discovered at runtime for the next request | Per-injection, durable in the log |
| Skills | Procedures and reference too large to inject | Catalog always, body on demand |
| Commands | Deterministic actions with no reasoning needed | No model turn at all |

Placement has a correctness dimension, not just a cost one. The
[agent-instructions concept](https://github.com/deepseek-ai/deepseek-harness/blob/main/packages/context/agent-instructions/README.md) records the rule and
a real mistake from this very bundle: `~/.dsh/AGENTS.md` loads in **every** dsh
session on the machine, so anything workspace-specific placed there bleeds into
unrelated projects. Workspace-root `AGENTS.md` is correct for workspace-specific
knowledge even though it is less guaranteed to fire. Correctness of scope beats
the convenience of "always loads".

## Verification

Observable without a model:

1. The boot prints all three activation lines:
   `[l5-observer] ACTIVE`, `[l5-inject] ACTIVE`, `[l5-commands] ACTIVE`.
2. `--dump-config` with the skills overlay shows the composed `skill-filesystem`
   row carrying your `customSkillDirs` and `includeDefaultRoots: false`.
3. Removing `inject = ['agents']` or `['commands']` makes the load fail loudly, as
   L4 showed — proof neither service is ambient.

Requires a session, and therefore a provider:

4. Your observer prints the `pre-step` payload shape for a real turn.
5. Injected text is present in the replayed session after a restart.
6. Your skill appears in the catalog, and `name`/`description` are exactly right.
7. Renaming the skill directory changes the catalog without a restart.
8. `/l5-facts` responds with no model turn and no `pre-step` log line.

Items 5, 6, and 8 are executed and recorded in
[VERIFIED.md](https://github.com/REPLACE_OWNER/dsh-exploration-kit/blob/main/VERIFIED.md), and
item 4's payload shape is observed there. Item 7 (a rename reflected without a restart) and the
step *after* the catalog — a model choosing to invoke the skill — are not: the second needs a
model-driven tool call, not a scripted one.

## Exit check — you should now be able to explain

- Why `next()` in a waterfall is mandatory for an observing listener.
- Why injected context is *not* a mechanism for waking a background agent.
- What the catalog/body split buys, and what a missing `description` costs you.
- Which of the four mechanisms you would use for: a coding standard, a
  discovered API fact, a 40-step release procedure, and a cache-clearing action.

## Next

[L6 — Give the session durable state](./06-durable-session-state.md).
