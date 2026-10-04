---
okf_version: "0.1"
---

# DSH Exploration Kit

A hands-on, nine-lesson curriculum for learning DeepSeek Harness (`dsh`) by
building real plugins — from mounting your first plugin to unattended automation.

Learn [DeepSeek Harness](https://github.com/deepseek-ai/deepseek-harness) (`dsh`) by
building things that run. Nine lessons, each producing a working artifact, each
teaching exactly one new part of the harness.

DSH is enormous but its *mechanism* is small and uniform: every capability is a
plugin mounted into one shared context, reacting to typed events, owning a
lifecycle. This kit teaches that mechanism once and then points it at a different
extension seam in every lesson.

## Start here

1. [Learning path](./learning-path.md) — the ordering, why it is ordered that way,
   the dependency graph, and five progress checkpoints.
2. [Capability map](./feature-map.md) — every DSH capability grouped by subsystem,
   with the package or seam that provides it.
3. [Lesson 1 — Mount your first plugin](./lessons/01-plugin-lifecycle.md) — needs
   no API key.

## The nine lessons

| # | Lesson | New mechanism | API key? |
|---|---|---|---|
| 1 | [Mount your first plugin](./lessons/01-plugin-lifecycle.md) | Plugin tree, shapes, fiber lifecycle | No |
| 2 | [Register a tool, compose with config](./lessons/02-tool-and-effects.md) | `ctx.tools`, Schemastery, patch layers | No |
| 3 | [Services, isolation, and hot reload](./lessons/03-service-and-hmr.md) | `ctx.*` services, `inject`, HMR, inventory | No |
| 4 | [Build a policy gate](./lessons/04-policy-waterfalls.md) | `tools/*` and `fs/*` waterfall events, guards | Optional |
| 5 | [Assemble context deliberately](./lessons/05-context-assembly.md) | Context hooks, skills, commands | Yes |
| 6 | [Give the session durable state](./lessons/06-durable-session-state.md) | `SessionEventMap`, projections, replay | No |
| 7 | [Operate the harness](./lessons/07-operating-the-harness.md) | Session query, telemetry, token accounting | Yes |
| 8 | [Orchestrate multiple agents](./lessons/08-multi-agent-orchestration.md) | Subagents, forks, workflow engine | Yes |
| 9 | [Automate the harness](./lessons/09-automation-and-triggers.md) | Headless, SDK/ACP, schedules, webhooks | Yes |

## How to use this kit

Each lesson has the same shape: **goal → concepts → steps → verification →
exit check → next**. Do not skip the verification step. DSH fails loudly by
design, and reading the failure is most of the learning.

Every lesson assumes:

- A **DeepSeek Harness source checkout** with `pnpm run build` already run.
- `dsh` on your `PATH` (see
  [installing the dsh CLI](https://github.com/deepseek-ai/deepseek-harness/blob/main/docs/development.md)).
- The path convention `<kit>` meaning this repository's root. Build your exercise
  plugins under `<kit>/plugins/`.

**Run boot commands in your own shell, not through a sandboxed agent's bash tool.**
The default file sandbox blocks `dsh` from writing its composed profile under
`~/.dsh`, and the boot fails with `EPERM`.

## Compatibility

Authored and verified against **DeepSeek Harness `0.2.0-rc.2`**
(commit `639ed01539`). DSH is a developer preview with explicitly breaking
changes, so a different version may require adjustments. See
[VERIFIED.md](./VERIFIED.md)
for exactly which steps have been executed and which are documented but unrun.

## Contributing

Corrections, clearer explanations, and additional lessons are welcome — see
[CONTRIBUTING.md](./CONTRIBUTING.md).
The content is an [Open Knowledge Format](https://github.com/GoogleCloudPlatform/knowledge-catalog)
bundle, so every file is plain markdown with YAML frontmatter.

## Attribution

This is an independent, unofficial teaching resource. DeepSeek Harness is
developed by [DeepSeek AI](https://deepseek.com) and licensed under MIT (see
[THIRD-PARTY.md](./THIRD-PARTY.md)).
The knowledge here was derived from the public DSH documentation and source; the
lesson design, exercises, and explanations are original. Not affiliated with or
endorsed by DeepSeek AI.

## Bundle

- [Lessons](./lessons/index.md) — the lesson directory listing
- [Learning path](./learning-path.md) — the curriculum design document
- [Capability map](./feature-map.md) — the capability inventory
