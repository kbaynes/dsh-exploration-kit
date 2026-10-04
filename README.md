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
kit-plugins/      The dsh bundle that carries each lesson's exercise plugin
plugins/          Your own scratch space for writing the exercises
examples/         Generated mirror of each lesson's files (drift-checked in CI)
solutions/        Answer key, for diffing when stuck
scripts/          Verification tooling
```

`content/` is the source of truth. The website reads it directly; nothing is
duplicated.

## Prerequisites

**To read the lessons** you need a
[DeepSeek Harness source checkout](https://github.com/deepseek-ai/deepseek-harness)
with `pnpm run build` already run, and `dsh` on your `PATH`. You then install this
kit's exercise bundle into a dsh profile:

```sh
cd kit-plugins && pnpm install && cd ..
dsh plugin --profile kitdemo add link:$PWD/kit-plugins
```

See [kit-plugins/README.md](kit-plugins/README.md) for why plugins must be shipped
as a bundle rather than loaded as loose files. The lessons create and
boot real plugins against that checkout, so the curriculum cannot be completed
without it. See DSH's
[development guide](https://github.com/deepseek-ai/deepseek-harness/blob/main/docs/development.md)
for the checkout and CLI setup.

**To build this site** you need Node.js ≥20 and pnpm ≥10. Development is verified
on Node 22.23.1 with pnpm 11.7.0, which is pinned in `packageManager`.

Lessons 1–3 and 6 need no model API key. Lessons 4, 5, and 7–9 benefit from (and
mostly require) a configured provider.

## Building the site

From the repository root:

```sh
pnpm run setup      # installs BOTH dependency roots (see below)
pnpm run dev        # local preview at http://127.0.0.1:5173
pnpm run build      # static build into website/.vitepress/dist
pnpm run preview    # serve the production build at http://127.0.0.1:4173
```

> **pnpm approves build scripts explicitly.** `pnpm-workspace.yaml` (and a second one in
> `kit-plugins/`) approves esbuild's postinstall by name. Without it a pristine install
> exits 1 with `ERR_PNPM_IGNORED_BUILDS` while still populating `node_modules` — easy to
> miss locally, fatal in CI.

> **There are two dependency roots, deliberately.** The repository root holds the site
> tooling; `kit-plugins/` holds the lesson plugins' own dependencies. The bundle is not
> a workspace member, because its packages are what a *profile* resolves at runtime, and
> folding it into the root workspace would change that resolution
> ([ADR-0003](decisions/0003-plugins-ship-as-a-bundle.md)). The cost is that a fresh
> clone needs both installs — `pnpm run setup` does both. If you run only `pnpm install`,
> `pnpm run check:units` says so explicitly rather than failing with an import error.

Use `preview` rather than `dev` when you care about the deployed URL: `dev` serves
from the site root, which hides mistakes in the VitePress `base` path.

`pnpm run dev` and `pnpm run build` first run `scripts/sync-site-docs.mjs`, which
copies `VERIFIED.md`, `CONTRIBUTING.md`, and `THIRD-PARTY.md` into `content/` for
the build. Those copies are generated and git-ignored — edit the root files.

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
pnpm run check:links         # every relative link inside content/ resolves
pnpm run check:placeholders  # no pre-publication placeholders remain
pnpm run validate            # OKF conformance, if okflint is on your PATH
pnpm run check:upstream      # upstream DSH links resolve (needs a checkout)
pnpm run check:examples      # examples/ matches the canonical bundle
```

`check:upstream` takes a DSH checkout path as an argument or in `DSH_CHECKOUT`:

```sh
DSH_CHECKOUT=~/src/deepseek-harness pnpm run check:upstream
```

It exists because the curriculum links to DSH documentation by absolute GitHub URL,
and a plausible-looking path such as `docs/harness/plugins.md` can simply not
exist. CI runs the first three; only a maintainer with a checkout can run the last.

Verified from a clean export of the committed tree: `pnpm install --frozen-lockfile`,
`pnpm run check:links`, and `pnpm run build` all succeed with no inherited
`node_modules`.

## Deploying the site

The site deploys to GitHub Pages via
[`.github/workflows/site.yml`](.github/workflows/site.yml) on every push to `main`.

One-time setup: **Settings → Pages → Build and deployment → Source: GitHub
Actions**. The workflow needs no secrets and no DSH checkout — the curriculum is
documentation, not executable code.

The site then serves from `https://<owner>.github.io/dsh-exploration-kit/`, which
must match `base` in [website/.vitepress/config.mts](website/.vitepress/config.mts).
For a user/org root site or a custom domain, change `base` to `/`.


## Compatibility

Authored and verified against **DeepSeek Harness `0.2.0-rc.2`**, upstream tag
`dsh-v0.2.0-rc.2`, commit `639ed015397290b3745d163aafe02ffee4aa3f84`.

Releases are tagged for the harness state they target —
`v<kit-version>+dsh.<dsh-version>.g<short-dsh-sha>` — so you can tell at a glance
whether a lesson was verified against the harness you have. See
[VERIFIED.md](VERIFIED.md#harness-state-this-kit-targets) for the policy.

The kit records that state in one place, [`kit.target.json`](kit.target.json), and
`pnpm run check:target` holds every other record of it — the ledger, this README, the
roadmap, the tag example, the bundle's pins, the verify scripts' defaults — to that file.
A drift between any two of them would be a false claim about what was verified.

DSH is a developer preview and will change. [VERIFIED.md](VERIFIED.md) records exactly
which steps have been executed against that commit and which are documented but
unverified — read it before trusting a lesson's stronger claims.

## Project status and plan

This kit is **not finished**. Only Lesson 1 has been executed end to end; the
remaining lessons are written but unverified.

- [ROADMAP.md](ROADMAP.md) — status at a glance, phase by phase and lesson by lesson.
- [decisions/](decisions/README.md) — the engineering decisions behind the kit, each
  one earned by getting it wrong first. Worth reading before contributing.
- [PLAN.md](PLAN.md) — the detailed, checkbox-driven implementation plan covering
  build, test, review, publication readiness, and promotion.

The rule that governs the project: **a step is verified only when it has been run
and the observed result recorded.** If you hit something that does not work as
written, that is a defect worth an issue — see [CONTRIBUTING.md](CONTRIBUTING.md).


## Getting help and reporting defects

<!-- placeholder-check:allow -->
Open an [issue](https://github.com/REPLACE_OWNER/dsh-exploration-kit/issues). Two
templates are provided:

- **Lesson defect** — a step does not work, or a technical claim is wrong. Include
  your DSH version; version drift is the most common cause.
- **Clarity feedback** — the step worked but the explanation did not. This is
  genuinely valuable: if it confused you, it will confuse others.

Please check [VERIFIED.md](VERIFIED.md) first — a lesson that has never been
executed is far more likely to have defects, and it is the honest place to set your
expectations.

Questions about DeepSeek Harness itself belong
[upstream](https://github.com/deepseek-ai/deepseek-harness/discussions), not here.

## Contributing

Corrections, clearer explanations, and new lessons are welcome. See
[CONTRIBUTING.md](CONTRIBUTING.md), and note that participation is covered by the
[Code of Conduct](CODE_OF_CONDUCT.md).

## License and attribution

The curriculum and website are [MIT licensed](LICENSE). DeepSeek Harness is
developed by DeepSeek AI and licensed under MIT; this kit is an independent,
unofficial teaching resource, not affiliated with or endorsed by DeepSeek AI.
See [THIRD-PARTY.md](THIRD-PARTY.md).
