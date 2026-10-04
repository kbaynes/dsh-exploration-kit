---
type: Lesson Plan
title: DSH Exploration Learning Path
description: The ordering of the nine exploration projects, why that order teaches the harness fastest, and the dependency graph between lessons.
resource: dsh
tags: [deepseek-harness, exploration, curriculum, learning-path, plugins]
timestamp: 2026-09-30
---

# DSH Exploration Learning Path

Why the nine lessons are in this order, and what each one buys you. Start at the
[lesson index](index.md); the capability inventory is the
[feature map](feature-map.md).

## The ordering principle

DSH is a plugin tree whose behavior is enormous but whose *mechanism* is small
and uniform. Every advanced capability in the [feature map](feature-map.md)
— a policy gate, a memory system, a multi-agent pipeline — is the same
mechanism (register an effect on a context, react to an event, own a lifecycle)
applied to a different seam. So the path is built to teach the mechanism **once**,
then spend each later lesson pointing that mechanism at a new seam.

Three rules produced the order:

1. **Mechanism before capability.** You cannot reason about a policy gate until
   you have watched a plugin load, fail, and unload. Lessons 1–3 teach only the
   mechanism; no lesson before L4 asks you to make a judgment about agent
   behavior.
2. **One new seam per lesson.** A lesson introduces exactly one new extension
   point, so a failure is attributable. L2 adds `ctx.tools`, L3 adds a service
   and the reload path, L4 adds `tools/*` events, L5 adds context hooks, L6 adds
   `SessionEventMap`, and so on.
3. **Cheap feedback loops first.** Lessons 1–8 are verified by booting a real profile and
   reading its output; the headless and SDK paths in L9 are documented but not yet run.
   The expensive lessons (L8 orchestration, L9 automation) come last, because by
   then you can debug them with the introspection skills L3 and L7 taught.

## The lessons and what each unlocks

| # | Project | New mechanism | Unlocks |
|---|---|---|---|
| L1 | Mount your first plugin | Plugin tree, bundles and rows, fiber lifecycle | Reading a `FAILED` or `PENDING` load as a diagnosis instead of a mystery |
| L2 | A tool + config composition | `ctx.tools`, Schemastery, config override | Making DSH do something new the model can call |
| L3 | A service + hot reload | `ctx.*` service keys, `inject`, HMR, inventory | Watching the runtime reconfigure live; inspecting your own tree |
| L4 | A policy gate | `tools/*` and `fs/*` waterfall events, guards | Governing what the agent may do, not just what it can do |
| L5 | Deliberate context assembly | `agent/pre-step`, `agent.inject()`, skills, commands | Controlling what the model knows and when |
| L6 | Durable session state | `SessionEventMap`, projections, replay | State that survives a restart and is reconstructable from the log |
| L7 | Operate the harness | OTel, token meter, session query, invariants | Answering "what did it cost, and what actually happened?" |
| L8 | Multi-agent orchestration | Subagents, forks, workflow engine, presets, teams | Fanning work across contexts with structured results |
| L9 | Automation and triggers | Headless, SDK/ACP, schedules, webhooks, API gateway | Running DSH unattended and letting other systems drive it |

## Dependency graph

```
L1 ──> L2 ──> L3 ──> L4 ──> L5 ──> L6 ──> L7
                       │             │
                       └────> L8 <───┘
                                │
                                └──> L9
```

- L1 → L2 → L3 is strictly linear: each adds one lifecycle concept the next assumes.
- L4 depends on L1–L3 only for the mechanics of mounting a listener.
- L5 needs L4's interception vocabulary (`waterfall`, `next()`) before it can
  distinguish observing a request from rewriting it.
- L6's projection work assumes L5, because the cheapest place to *observe* a
  session event is a context hook you already built.
- L8 is reachable after L4 but is scheduled after L7 so that you can measure the
  orchestration instead of guessing. It depends on L6 for forked-session seeding.
- L9 closes the loop: it depends on L2 (a bundle to ship), L3 (HMR awareness),
  and L8 (work worth automating).

## Suggested pacing and checkpoints

| Checkpoint | After | You should be able to, unaided |
|---|---|---|
| C1 | L3 | Explain what happens, step by step, when a plugin's `apply` throws |
| C2 | L4 | Write a waterfall listener that denies one tool call and delegates the rest |
| C3 | L6 | Add a durable session event and render it again after a restart |
| C4 | L7 | Produce a cost and trajectory report for one multi-turn task |
| C5 | L9 | Run DSH unattended from another program, triggered by a schedule |

If a checkpoint fails, repeat the lesson — do not proceed. The later lessons
assume the earlier ones are muscle memory, and each later lesson is more
expensive to debug from a weak base.

## What this path deliberately does not cover

- **Model provider authoring** (`ctx.llm` adapters). Covered by the repository's
  [adding-an-llm-adapter cookbook](https://github.com/deepseek-ai/deepseek-harness/blob/main/docs/cookbook/adding-an-llm-adapter.md);
  the [openrouter integration](https://github.com/deepseek-ai/deepseek-harness/blob/main/docs/user/guide/providers.md) concept covers
  the configuration-level version. L4's provider-free policy work is the
  prerequisite.
- **Client/UI plugin authoring.** L3 touches the browser half through the Cordis
  client runner, but building a React conversation node is out of scope; see the
  repository's `docs/subsystems/conversation.md`.
- **Production deployment.** L9 stops at the local container boundary. DSH does
  not publish deployment checklists, so hardening a multi-tenant pool from these
  lessons is explicitly out of scope.

## Related Concepts

- [Exploration lesson plan index](index.md) — the lessons themselves
- [Capability map](feature-map.md) — what each lesson is exercising
- [Plugin model](https://github.com/deepseek-ai/deepseek-harness/blob/main/docs/user/develop/framework/index.md) — the mechanism all nine lessons share
