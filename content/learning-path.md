---
type: Lesson Plan
title: DSH Exploration Learning Path
description: The ordering of the nine exploration projects, why that order teaches the harness fastest, and the dependency graph between lessons.
resource: dsh
tags: [deepseek-harness, exploration, curriculum, learning-path, plugins]
timestamp: 2026-09-30
---

# DSH Exploration Learning Path

Why the nine lessons are in this order, and what each one buys you. Start at the [lesson index](index.md); the capability inventory is the [feature map](feature-map.md).

## The ordering principle

DSH is a plugin tree whose behavior is enormous but whose *mechanism* is small and uniform. Every advanced capability in the [feature map](feature-map.md) — a policy gate, a memory system, a multi-agent pipeline — is the same mechanism (register an effect on a context, react to an event, own a lifecycle) applied to a different seam. So the path is built to teach the mechanism **once**, then spend each later lesson pointing that mechanism at a new seam.

Three rules produced the order:

1. **Mechanism before capability.** You cannot reason about a policy gate until you have watched a plugin load, fail, and unload. Lessons 1–3 teach only the mechanism; no lesson before L4 asks you to make a judgment about agent behavior.
2. **One new seam per lesson.** A lesson introduces exactly one new extension point, so a failure is attributable. L2 adds `ctx.tools`, L3 adds a service and the reload path, L4 adds `tools/*` events, L5 adds context hooks, L6 adds `ctx.sessionProjections` over a known first-party event, and so on.
3. **Cheap feedback loops first.** Every lesson is verified by booting a real profile and reading its output; L9's headless and SDK paths are executed too, keyless against the repository's scriptable mock provider. The expensive lessons (L8 orchestration, L9 automation) come last, because by then you can debug them with the introspection skills L3 and L7 taught.

## The lessons and what each unlocks

| # | Project | New mechanism | Unlocks |
|---|---|---|---|
| L1 | Mount your first plugin | Plugin tree, bundles and rows, fiber lifecycle | Reading a `FAILED` or `PENDING` load as a diagnosis instead of a mystery |
| L2 | A tool + config composition | `ctx.tools`, Schemastery, config override | Making DSH do something new the model can call |
| L3 | A service + hot reload | `ctx.*` service keys, `inject`, HMR, isolated realms, inventory | Watching the runtime reconfigure live; inspecting your own tree |
| L4 | A policy gate | `tools/*` and `fs/*` waterfall events, guards | Governing what the agent may do, not just what it can do |
| L5 | Deliberate context assembly | `agent/pre-step`, `agent/request`, `agent.inject()`, skills, commands | Controlling what the model knows and when |
| L6 | Durable session state | `ctx.sessionProjections` folding a known first-party event | State that survives a restart and is reconstructable from the log |
| L7 | Operate the harness | OTel, token meter, session query, invariants | Answering "what did it cost, and what actually happened?" |
| L8 | Multi-agent orchestration | Subagents, forks, workflow engine, presets, teams | Fanning work across contexts with structured results |
| L9 | Automation and triggers | Headless, SDK/ACP, schedules, webhooks, hook adapters | Running DSH unattended and letting other systems drive it |

## Dependency graph

```
L1 ──> L2 ──> L3 ──> L4 ──> L5 ──> L6 ──> L7
                                          │
                                          ▼
                                         L8 ──> L9
```

Read it as the *required* order rather than the only useful one: L8 depends on the whole of L1–L7 (its prerequisites say so, and step 4 boots the L7 overlay to read a session log), which is why the edge runs from L7.

- L1 → L2 → L3 is strictly linear: each adds one lifecycle concept the next assumes.
- L4 depends on L1–L3 only for the mechanics of mounting a listener.
- L5 needs L4's interception vocabulary (`waterfall`, `next()`) before it can distinguish observing a request from rewriting it.
- L6's projection work assumes L5, because the cheapest place to *observe* a session event is a context hook you already built.
- L8 requires L1–L7. It uses L6's projection to *observe* what a forked child inherits, and L7's overlay to read the parent's log for the seed, so the edge runs from L7 — but the deeper reason it is scheduled late is that orchestration should be measured before it is trusted, and L7 is where the measuring is taught.
- L9 closes the loop: it depends on L2 (a bundle to ship), L3 (HMR awareness), and L8 (work worth automating).

## If you only have 30 minutes

The path is nine lessons because the harness is nine mechanisms deep, not because you must finish it. A defensible short version, in this order:

| # | Lesson | Why it earns the time | ~time |
|---|---|---|---|
| 1 | [Mount your first plugin](./lessons/01-plugin-lifecycle.md) | You cannot reason about anything else here until you have watched a plugin load, fail, and unload. It also installs the bundle every later lesson uses. | 15 min |
| 3 | [Services, isolation, and hot reload](./lessons/03-service-and-hmr.md) | `PENDING` is the failure mode that costs people hours, and the reload loop is what makes every later experiment fast. | 15 min |

That pair gives you the mental model — a plugin tree, effects with a lifecycle, dependencies that gate activation, and a loop you can iterate in — which is most of what makes the rest readable rather than mysterious.

**What you give up:** Lesson 2's tool and config composition, and everything from Lesson 4 onward (policy, context, session state, observability, orchestration, automation). If you skip ahead afterwards, note that L4 assumes the interception vocabulary from L3 and L6 assumes L5's "the log is the source of truth".

## Suggested pacing and checkpoints

| Checkpoint | After | You should be able to, unaided |
|---|---|---|
| C1 | L3 | Explain what happens, step by step, when a plugin's `apply` throws |
| C2 | L4 | Write a waterfall listener that denies one tool call and delegates the rest |
| C3 | L6 | Fold a known first-party session event into a projection and read it again after a restart |
| C4 | L7 | Produce a cost and trajectory report for one multi-turn task |
| C5 | L9 | Run DSH unattended from another program, triggered by a schedule |

If a checkpoint fails, repeat the lesson — do not proceed. The later lessons assume the earlier ones are muscle memory, and each later lesson is more expensive to debug from a weak base.

## What this path deliberately does not cover

- **Model provider authoring** (`ctx.llm` adapters). Covered by the repository's [adding-an-llm-adapter cookbook](https://github.com/deepseek-ai/deepseek-harness/blob/master/docs/cookbook/adding-an-llm-adapter.md); the [providers guide](https://github.com/deepseek-ai/deepseek-harness/blob/master/docs/user/guide/providers.md) covers the configuration-level version. The prerequisite is L2's `ctx.tools` registration: an adapter is registered on a `ctx.*` seam the same way, which is the transferable part.
- **Client/UI plugin authoring.** L3 touches the browser half through the Cordis client runner, but building a React conversation node is out of scope; see the repository's `docs/subsystems/conversation.md`.
- **Production deployment.** L9 stops at the local container boundary. DSH does not publish deployment checklists, so hardening a multi-tenant pool from these lessons is explicitly out of scope.

## Related Concepts

- [Exploration lesson plan index](index.md) — the lessons themselves
- [Capability map](feature-map.md) — what each lesson is exercising
- [Plugin model](https://github.com/deepseek-ai/deepseek-harness/blob/master/docs/user/develop/framework/index.md) — the mechanism all nine lessons share
