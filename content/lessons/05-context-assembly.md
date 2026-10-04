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

L1–L4 complete. You need your `diagnose.ts` instrument and the reload loop.

## Step 1 — Watch the turn flow before touching it

Create `<kit>/plugins/l5/turn-observer.ts` and mount it:

```ts
import type { Context } from '@deepseek-ai/cordis'

export const name = 'l5-turn-observer'

export function apply(ctx: Context) {
  ctx.on('agent/pre-step', async (payload, next) => {
    console.log('[l5] pre-step', JSON.stringify(payload).slice(0, 120))
    return next()
  })
}
```

Run one conversation turn and read what actually arrives. Do this before writing
any injection logic — the shape of the payload tells you what is available at this
stage, and guessing it is the usual source of broken context plugins.

`agent/pre-step` is a **waterfall**: return `next()` to delegate. Several
first-party plugins already listen here, including `agent-instructions`, `plan-mode`,
`tool-skill`, `time-context`, and `session-checkpoint-policy`. You are joining an
existing layer, not replacing it.

## Step 2 — Inject context deliberately

Now add an injection to the same plugin:

```ts
import type { Context } from '@deepseek-ai/cordis'
import { createUserMessage } from '@deepseek-ai/dsh-llm'

// A source kind belongs to its producer, so declare yours. There is deliberately
// no shared catch-all `plugin` kind.
declare module '@deepseek-ai/dsh-llm' {
  interface MessageSourceMap {
    'l5-turn-observer': { kind: 'l5-turn-observer' }
  }
}

export const name = 'l5-turn-observer'

export function apply(ctx: Context) {
  ctx.on('agent/pre-step', async (payload, next) => {
    const decision = await next()
    // after delegating, append durable context for the next admitted request
    return decision
  })

  ctx.on('agent/created', (agent) => {
    try {
      agent.inject(createUserMessage({
        content: [
          {
            type: 'text',
            text: 'Exploration mode: when you explain a change, name the file it lands in.',
          },
        ],
        source: { kind: 'l5-turn-observer' },
      }))
    } catch {
      // the agent may already be disposed; never let a notification kill a plugin
    }
  })
}
```

`agent.inject()` takes a complete `UserMessage`, not a loose `{ content, source }`
object. Build it with `createUserMessage`, which fills in the role and a stable
identity. The **source kind is producer-owned**: each producer declares its own
kind by merging into `MessageSourceMap`, and there is no catch-all kind to reuse.

The contract that matters here is that the injected message appends durable context
the **next** model request sees — and it is **not a wake-up**. An idle agent stays
idle. Guard against disposed agents.

To confirm the durability claim yourself, inject a distinctive sentence, run one
turn, close the session, reopen it, and search the replayed history for your text.
It is in the session log because the log is the source of truth — which is exactly
what L6 builds on.

## Step 3 — A skill the agent discovers on its own

Skills are the right delivery mechanism for knowledge too large to inject on every
turn and too specific to put in `AGENTS.md`. Create a skill bundle:

`<kit>/plugins/l5/skills/repo-onboarding/SKILL.md`:

```md
---
name: repo-onboarding
description: Use when asked to explain how this workspace is organized, where knowledge lives, or how to get started reading it.
---

# Repo onboarding

This workspace keeps its agent-facing knowledge in an Open Knowledge Format bundle
under `doc/`. Start at `doc/index.md`; it fans out to `harness/` (architecture and
plugin model) and `operations/` (deploy-time checklists).

The exploration curriculum is `doc/exploration/`; its capability inventory is
`doc/exploration/feature-map.md`.

Before answering an architecture question, read the relevant concept instead of
reasoning from memory.
```

Frontmatter rules that will bite if ignored: `name` must be kebab-case and match
the directory, `description` is **required**, and discovery is exactly one level
deep — `<root>/<name>/SKILL.md` or `<root>/<name>.md`. A nested `**/SKILL.md` is
deliberately not discovered. An invalid skill is skipped with a warning, so a
broken skill looks *identical to an absent one* from the model's point of view.

Now point a scanned root at it. The shipped `skill-filesystem` row carries no
`config` at all, so your overlay supplies the first `customSkillDirs` by overriding
that existing row rather than inserting a second provider:

`<kit>/plugins/l5.skills.patch.yml`:

```yaml
- id: skill-filesystem
  config:
    customSkillDirs: ['<absolute path to>/dsh-exploration-kit/plugins/l5/skills']
    includeDefaultRoots: false
```

Root resolution order is project roots, then `customSkillDirs`, then user roots;
`includeDefaultRoots: false` makes the experiment unambiguous. The directory
**need not exist yet** — a missing root is probed until it appears, and existing
roots are watched, so adding or renaming a skill reaches the next catalog without
a restart.

Verify by asking the agent what onboarding skills it has, or by reading the
session's first request in the log. A model-invocable skill receives a durable
catalog of names and capped descriptions before the first request; the body loads
only when the agent calls the `skill` tool. That two-phase split — catalog versus
body — is the design worth noticing, and it is why `description` quality decides
whether a skill is ever used.

## Step 4 — A command that needs no model turn

`ctx.commands.register()` gives a human a deterministic entry point:

```ts
export const name = 'l5-commands'
export const inject = ['commands']

export function apply(ctx: Context) {
  ctx.commands.register({
    name: 'l5-facts',
    description: 'Print how this exploration bundle is laid out',
    handler: () => ({
      kind: 'success',
      text: 'doc/exploration/{feature-map,learning-path}.md + lessons/01..09',
    }),
  })
}
```

A command line starts with `/`, a lowercase name, then either end-of-input or
whitespace; everything after the name is `rawInput` and the command owns its
grammar. Registering the same name twice in one scope throws. The handler returns
`success` or `error` plus optional UI text. Type `/l5-facts` in the composer and
confirm the reply appears **without** a model call — you can check that by watching
your `pre-step` observer stay silent.

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

1. Your observer prints the `pre-step` payload shape for a real turn.
2. Injected text is present in the replayed session after a restart.
3. Your skill appears in the catalog, and `name`/`description` are exactly right.
4. Renaming the skill directory changes the catalog without a restart.
5. `/l5-facts` responds with no model turn and no `pre-step` log line.

## Exit check — you should now be able to explain

- Why `next()` in a waterfall is mandatory for an observing listener.
- Why injected context is *not* a mechanism for waking a background agent.
- What the catalog/body split buys, and what a missing `description` costs you.
- Which of the four mechanisms you would use for: a coding standard, a
  discovered API fact, a 40-step release procedure, and a cache-clearing action.

## Next

[L6 — Give the session durable state](./06-durable-session-state.md).
