# DSH Exploration Kit

A hands-on, nine-lesson curriculum for learning [DeepSeek Harness](https://github.com/deepseek-ai/deepseek-harness)
(`dsh`) by building real plugins — from mounting your first plugin to unattended
automation.

DSH is a plugin-based agent runtime: every capability is a Cordis plugin mounted
into one shared context. This kit teaches that mechanism once, then points it at a
different extension seam in every lesson.

**Start → [the learning path](content/learning-path.md)** · then
[Lesson 1](content/lessons/01-plugin-lifecycle.md), which needs no API key.

## The nine lessons

| # | Lesson | New mechanism | API key? |
|---|---|---|---|
| 1 | [Mount your first plugin](content/lessons/01-plugin-lifecycle.md) | Plugin tree, shapes, fiber lifecycle | No |
| 2 | [Register a tool, compose with config](content/lessons/02-tool-and-effects.md) | `ctx.tools`, Schemastery, patch layers | No |
| 3 | [Services, isolation, and hot reload](content/lessons/03-service-and-hmr.md) | `ctx.*` services, `inject`, HMR, inventory | No |
| 4 | [Build a policy gate](content/lessons/04-policy-waterfalls.md) | `tools/*` and `fs/*` waterfall events, guards | Optional |
| 5 | [Assemble context deliberately](content/lessons/05-context-assembly.md) | Context hooks, skills, commands | Yes |
| 6 | [Give the session durable state](content/lessons/06-durable-session-state.md) | `SessionEventMap`, projections, replay | No |
| 7 | [Operate the harness](content/lessons/07-operating-the-harness.md) | Session query, telemetry, token accounting | Yes |
| 8 | [Orchestrate multiple agents](content/lessons/08-multi-agent-orchestration.md) | Subagents, forks, workflow engine | Yes |
| 9 | [Automate the harness](content/lessons/09-automation-and-triggers.md) | Headless, SDK/ACP, schedules, webhooks | Yes |

Also included: the [capability map](content/feature-map.md) — every DSH feature
grouped by subsystem, with the package or seam that provides it — and the
[learning path](content/learning-path.md), which explains the ordering.

## Repository layout

```
content/          The curriculum — an Open Knowledge Format bundle
  index.md        Bundle entry point
  feature-map.md  Capability inventory
  learning-path.md  Curriculum design (ordering, checkpoints)
  lessons/        The nine lessons
website/          VitePress configuration and theme (renders content/ in place)
plugins/          Exercise plugins you build while working the lessons
examples/         Read-only exact files as each lesson presents them
solutions/        Answer key, for diffing when stuck
scripts/          Verification tooling
```

`content/` is the source of truth. The website reads it directly; nothing is
duplicated.

## Building the site

From the repository root:

```sh
pnpm install      # see the hoisting note below
pnpm run dev      # local preview at http://127.0.0.1:5173
pnpm run build    # static build into website/.vitepress/dist
```

Requires Node.js 20 or newer.

> **Why hoisting is required.** VitePress compiles the markdown in `content/`,
> which sits *outside* the directory it is invoked from. pnpm symlinks only
> declared dependencies, so Node cannot resolve `vue` from those files and the
> build fails with `Rollup failed to resolve import "vue/server-renderer"`. The
> repository's [`.npmrc`](.npmrc) sets `shamefully-hoist=true` to solve this; it
> is a deliberate, documented workaround, not a stray setting.

pnpm may also print `Ignored build scripts: esbuild`. That warning is harmless
here — Vite's platform binary arrives through esbuild's optional dependency
package rather than its postinstall script, and the build succeeds with the
script ignored. Run `pnpm approve-builds` if you want to silence it.

## Checks

```sh
pnpm run check:links   # every relative link inside content/ resolves
pnpm run validate      # OKF conformance, if okflint is on your PATH
```


## Compatibility

Authored and verified against **DeepSeek Harness `0.2.0-rc.2`** (commit
`639ed01539`). DSH is a developer preview and will change. [VERIFIED.md](VERIFIED.md)
records exactly which steps have been executed against that version and which are
documented but unverified — read it before trusting a lesson's stronger claims.

## Project status and plan

This kit is **not finished**. Only Lesson 1 has been executed end to end; the
remaining lessons are written but unverified.

- [ROADMAP.md](ROADMAP.md) — status at a glance, phase by phase and lesson by lesson.
- [PLAN.md](PLAN.md) — the detailed, checkbox-driven implementation plan covering
  build, test, review, publication readiness, and promotion.

The rule that governs the project: **a step is verified only when it has been run
and the observed result recorded.** If you hit something that does not work as
written, that is a defect worth an issue — see [CONTRIBUTING.md](CONTRIBUTING.md).


## Contributing

Corrections, clearer explanations, and new lessons are welcome. See
[CONTRIBUTING.md](CONTRIBUTING.md).

## License and attribution

The curriculum and website are [MIT licensed](LICENSE). DeepSeek Harness is
developed by DeepSeek AI and licensed under MIT; this kit is an independent,
unofficial teaching resource, not affiliated with or endorsed by DeepSeek AI.
See [THIRD-PARTY.md](THIRD-PARTY.md).
