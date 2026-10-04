# Verification Status

This file records **what has actually been executed** against which DeepSeek
Harness version, so readers know how much weight each lesson's claims carry.

> **Rule for contributors: never mark a step verified unless you ran it.**
> Documented-but-unrun is a legitimate status. Overstated verification is the most
> damaging error this repository can make.

## Tested against

| Field | Value |
|---|---|
| DeepSeek Harness version | `0.2.0-rc.2` |
| Upstream tag | `dsh-v0.2.0-rc.2` |
| Source commit (full) | `639ed015397290b3745d163aafe02ffee4aa3f84` |
| Upstream branch at capture | `master` |
| Upstream tree | clean (no local modifications) |
| Captured on | 2026-10-01 |
| Kit commit at capture | see `git log -1` in this repository |
| Platform | macOS (darwin), Node.js 22.23.1 |
| pnpm | 11.7.0 |
| Verifier | Kit author |

Record the **full** commit, not an abbreviation: a short hash is not a stable
identifier for reproducing the state these lessons were verified against.

DSH is a developer preview with explicitly breaking changes. On a different
version, expect to adjust commands and package import paths.

## Harness state this kit targets

Every verification in this file is a statement about **one harness state**, identified
by the upstream commit above. The kit is not versioned against a moving target.

### Release-time gate

Before a kit release is tagged, all of the following must hold:

- [ ] Every lesson is **Implemented** and **Tested** in [ROADMAP.md](https://github.com/REPLACE_OWNER/dsh-exploration-kit/blob/main/ROADMAP.md).
- [ ] The upstream tree used for verification was **clean** at capture, so the commit
      identifies exactly what was exercised. Debris in the harness checkout invalidates
      the record.
- [ ] The table above carries the full upstream commit, its tag, and the capture date.
- [ ] `package.json`'s `packageManager`, the kit lockfiles, and the pinned optional
      package versions all match the release under test (see
      [ADR-0013](https://github.com/REPLACE_OWNER/dsh-exploration-kit/blob/main/decisions/0013-pin-optional-package-versions.md)).
- [ ] No pre-publication placeholder remains: `pnpm run check:placeholders` passes.
- [ ] `pnpm run check:kit` passes in full.

### Tag naming

A kit release tag records the harness state it targets, so the relationship survives
without reading prose:

```
v<kit-version>+dsh.<dsh-version>.g<short-dsh-sha>
```

For the state verified here that would be, for a kit version of `0.1.0`:

```
v0.1.0+dsh.0.2.0-rc.2.g639ed01539
```

The tag is a claim: everything in it was verified against that commit. Retagging to a
newer harness commit means re-running the verification, not editing the record.

### When upstream moves

DSH is a developer preview with explicitly breaking changes. On each upstream release:

1. Re-run `pnpm run check:kit` against the new checkout.
2. Re-verify the lessons the change touches; re-promote each `VERIFIED.md` row with its
   new evidence, and demote any whose claims no longer hold.
3. Update the table above and the pinned versions in one pass, so no two of them can
   disagree.
4. Tag a new kit release at the new commit.

**Demoting a row is the honest outcome of an upstream break, not a failure.** A row
that claims verification against a commit where the behaviour changed is worse than a
row that admits it has not been checked yet.
## Status legend

| Status | Meaning |
|---|---|
| **Executed** | Ran end-to-end and observed the stated result |
| **Partly executed** | Some steps or facts ran; the lesson's full exercise did not |
| **Documented** | Asserted from DSH's public docs and source; **not run** |
| **Unrun** | Requires a model API key, or is dependent on another unrun step |

## Per-lesson status

| Lesson | Status | Notes |
|---|---|---|
| L1 — Mount your first plugin | **Mostly executed** | Lifecycle cycle verified twice: originally via a patch overlay, and again after the bundle pivot (`dsh --profile kitdemo`), which is what the lesson now teaches. Both the `FAILED` throw and the `PENDING` inject experiments **are** executed, and their real output corrected two draft assumptions. See evidence below. |
| L2 — Register a tool, compose with config | **Mostly executed** | Executed: the plugin loads through the installed bundle and logs `ACTIVE — defaultUnit=lines`; the Schemastery schema rejects `paragraphs` with a field-naming error; an overlay patch on the *installed* row changes the value to `chars`. Still **not** executed: an actual model tool call (needs a provider). See evidence below. |
| L3 — Services, isolation, and hot reload | **Mostly executed** | Executed: the service is provided as `ctx.lessonClock` and consumed; disabling the provider strands the consumer and the scoped sweep names it `PENDING`; editing a plugin file reloads it live under the `hmr` overlay. Two upstream-tutorial traps were found by running it. Not executed: the `plugin_manager` and `isolate` explorations. |
| L4 — Build a policy gate | **Partly executed** | Executed: both policy plugins load (`l4-write-scope` reports its confinement root, `l4-guard` registers its monotonic guard), and the missing-`inject` failure was reproduced. **Not** executed: any allow/deny decision, which needs a model tool call. |
| L5 — Assemble context deliberately | **Partly executed** | Executed: all three plugins activate on the real composition, `agent.inject()` is built from `createUserMessage` with a producer-owned source kind, and the skills overlay composes onto the base `skill-filesystem` row. **Not** executed: the `pre-step` payload, injected-text durability, the model's skill catalog, and `/l5-facts` — each needs a session. |
| L6 — Give the session durable state | **Partly executed** | Executed: both plugins load on the real composition; the projection's fold is **unit-tested** (`kit-plugins/l6/fold.test.mjs`, 4 tests, in CI) including the same-reference contract and the delta-corruption hazard. **Not** executed: appending to a real session, JSONL inspection, and restart replay — each needs a session. |
| L7 — Operate the harness | **Partly executed** | Executed: the overlay composes as one override plus three inserts, and a boot applies it with **zero activation warnings**; the optional tool package is installed pinned to the dsh version. **Not** executed: any query, the authority refusal, token deltas, `/compact`, and the invariant findings — each needs a session. |
| L8 — Orchestrate multiple agents | **Partly executed** | Executed: the orchestration primitives are confirmed mounted by the base bundle (no kit plugin needed), and the workflow's pure core passes **7 unit tests with a fake engine** — pipeline drives every item, the schema passes through, and a partially failed fan-out still yields a dense array. **Not** executed: any real delegation, fork, or fan-out — each needs a provider. |
| L9 — Automate the harness | **Partly executed** | Executed: `schedule` and `webhook` are confirmed opt-in (no shipped bundle provides them), the overlay composes, and a web-backed profile activates both with **no warnings** while a base-backed profile leaves them `PENDING` naming the missing services; both packages install pinned. The Python snippet is a real upstream example. **Not** executed: any headless run, `--json` events, an SDK round trip, a schedule firing, a webhook delivery — each needs a provider. |

## Design pivot: plugins must be a bundle, not a `--patch` overlay

**Verified finding.** Pointing a `--patch` overlay at a loose plugin file works only
when that plugin imports **nothing** from dsh. A plugin that imports
`@deepseek-ai/dsh-tools` fails to load:

```
dsh: warning: 1 entry did not activate
l2-wordcount (file:///.../solutions/l2/wordcount.ts): failed to import
```

The loader resolves the relative path outside the dsh installation, and pnpm
symlinks only declared dependencies, so `@deepseek-ai/*` is unreachable from an
arbitrary directory. This was reproduced both outside the checkout and from inside
it (`packages/dsh-exploration-kit/`), so it is a module-resolution property, not a
path bug.

**Verified fix.** Package the exercises as a real bundle. `kit-plugins/` now
declares `dsh.bundle`, names its rows by package, and is installed with
`dsh plugin --profile <name> add link:<kit>/kit-plugins`. Verified end-to-end:

```
$ dsh --profile kitdemo --dump-config | grep -A4 l2-wordcount
# == dsh-exploration-kit-plugins
- id: l2-wordcount
  name: dsh-exploration-kit-plugins/l2/wordcount.js
  config:
    defaultUnit: lines

$ dsh --profile kitdemo
[l2-wordcount] ACTIVE — defaultUnit=lines
```

The plugin imports `@deepseek-ai/dsh-tools` and `@deepseek-ai/schemastery`, mounts
its tool, and receives validated config. **This supersedes the `--patch` overlay
instructions throughout the lessons**, which must be rewritten to install the
bundle. The overlay concept remains useful for *overriding* an installed row's
config, which is still how Lesson 2's last-write-wins exercise should be taught.

**Dependency versions** are pinned to the release under test: `@deepseek-ai/dsh-*`
at `0.2.0-rc.2`, `@deepseek-ai/schemastery` at `^3.18.4`. Bump them with each
verification pass.

### `link:` is required while editing, `file:` is not enough

**Verified.** `dsh plugin add file:<path>` **copies** the package into the profile.
A plugin row added to the kit afterwards did not compose until reinstall:

```
$ dsh --profile kitdemo --dump-config | grep -A8 dsh-exploration-kit-plugins
# == dsh-exploration-kit-plugins
- id: l2-wordcount            # the l1-hello row added minutes earlier is absent
```

`dsh plugin add link:<path>` creates a symlink instead, and every subsequent edit
composes live:

```
lrwxr-xr-x  dsh-exploration-kit-plugins -> ../../../../MyDocs/DeepSeekHarness/dsh-exploration-kit/kit-plugins
```

**All lesson instructions use `link:`.** This is not cosmetic: the lessons ask the
learner to edit plugin files and observe the change, which `file:` would defeat.

### Lesson 1 re-verified through the bundle

Booted `dsh --profile kitdemo` with both bundle rows installed:

```
[l1-hello] apply() ran — plugin is ACTIVE
[l1-hello] effect registered
[l2-wordcount] ACTIVE — defaultUnit=lines
dsh web: http://127.0.0.1:<port>/?token=...
[l1-hello] disposer ran — plugin is DISPOSED      (on shutdown)
```

This confirms the full cycle through the *bundle* path, not the retired overlay
path, and confirms a `.ts` module loads from an installed bundle.

Both failure experiments were then executed as the lesson instructs:

```
# apply throws
dsh: warning: 1 entry did not activate
l1-hello (dsh-exploration-kit-plugins/l1/hello.ts): Error: apply exploded
    at new apply (file:///<kit>/kit-plugins/l1/hello.ts:4:9) ...

# inject an unavailable service
dsh: warning: 1 entry did not activate
l1-hello (dsh-exploration-kit-plugins/l1/hello.ts): pending (waiting for service: definitelyNotAService)
```

**Two draft assumptions were wrong and are corrected in the lesson:** the boot
warns and continues rather than exiting non-zero, and `PENDING` is *not* silent —
the startup summary names the missing service.

## Evidence: L9 opt-in packages compose and activate

**A premise in the lesson was wrong.** It assumed `schedule_*` and `ctx.webhookRuntime`
were available. Neither package is mounted by any shipped bundle. The `schedule` and
`webhook` strings in the bundle patches are telemetry tuning knobs
(`scheduledDelayMillis`), which is exactly the kind of false match that makes a wrong
assumption look confirmed.

**Both are opt-in and must be installed, pinned** (ADR-0013):

```
dsh plugin --profile web add @deepseek-ai/dsh-schedule@0.2.0-rc.2
dsh plugin --profile web add @deepseek-ai/dsh-webhook@0.2.0-rc.2
```

**Profile choice is load-bearing.** On the base-backed `kitdemo` profile the same
overlay strands both rows in `PENDING`, naming the services they need:

```
schedule (...): pending (waiting for service: sessionController)
webhook  (...): pending (waiting for services: agentPresets, workspaceRegistry)
```

On a **web-backed** profile with both installed, a boot produced no activation warnings
at all. That is Lesson 3's `PENDING` mechanism appearing in a real composition rather
than a contrived one.

**Where the tools appear.** `schedule_*` registers in a live root Agent's scope, so it
does not show up in `--dump-config`. Composing cleanly proves the service loaded;
observing the tools needs a session. The lesson states that rather than implying the
dump is evidence.

**Deliberately unverified:** any headless run and its exit codes, `--json` events, an
SDK round trip, a schedule firing, and a webhook delivery.

## Evidence: L8 orchestration primitives are mounted, and its logic is unit-tested

**This lesson adds no plugin.** `tool-subagent`, `tool-subagent-fork`,
`tool-subagent-control`, `tool-workflow`, and `workflow-ptc` are all mounted by the
base bundle, so orchestration is capability the harness already provides rather than
something the kit installs. Worth recording because it is the opposite of L6's
expectation.

**The workflow's pure core is unit-tested without a model.** The engine injects
`agent`, `pipeline`, `phase`, and `log` into a workflow script, so a function that
takes them as parameters is testable with fakes. `kit-plugins/l8/audit-workflow.test.mjs`
runs seven tests, all passing, covering:

- the result schema has an object root with `additionalProperties: false`
- a throwing stage drops **that item** to `null` — it does not reject the run
- a malformed result is dropped rather than crashing the flatten
- flattening keeps order and tags each row's section
- a partially failed fan-out still yields a dense array
- the prompt names the section verbatim
- `runWorkflow` drives `pipeline`, logs each item, passes the schema through, and
  returns a dense result

**A stale path was found and fixed.** L8 and L9 still pointed readers at
`doc/exploration/...`, the workspace location the curriculum left when it became a
standalone repository. Both now use `<kit>/content/...`.

**Deliberately unverified:** any real delegation, fork, or fan-out, and the
monolith-versus-fan-out cost comparison. Every one needs a provider.

## Evidence: L7 composes and activates

Two defects were found by building this lesson, and both are now recorded.

**A row naming an uninstalled package fails to import.** Adding the tool row alone
produced:

```
dsh: warning: 1 entry did not activate
tool-session-query (@deepseek-ai/dsh-tool-session-query): failed to import
```

A row name resolves through the profile's installation, so the package must be
installed. This is [ADR-0003](https://github.com/REPLACE_OWNER/dsh-exploration-kit/blob/main/decisions/0003-plugins-ship-as-a-bundle.md)'s mechanism
applied to a package the kit does not own.

**An unpinned install resolves a stale version.** The obvious command —
`dsh plugin --profile kitdemo add @deepseek-ai/dsh-tool-session-query` — was rejected:

```
Plugin @deepseek-ai/dsh-tool-session-query@0.0.1-rc.1 is incompatible with dsh 0.2.0-rc.2
```

The registry confirms why: `dist-tags.latest` is `0.0.1-rc.1` while versions run to
`0.2.0-rc.2`. Installing the pinned version succeeded, and the subsequent boot had
**zero activation warnings**:

```
$ node -e "...profile manifest..."
{ "@deepseek-ai/dsh-tool-session-query": "0.2.0-rc.2",
  "dsh-exploration-kit-plugins": "link:.../kit-plugins" }
```

Recorded as [ADR-0013](https://github.com/REPLACE_OWNER/dsh-exploration-kit/blob/main/decisions/0013-pin-optional-package-versions.md).

**A third defect was in the kit's own tooling:** `solutions/verify-l7.sh` was written
with `timeout`, which is GNU coreutils and absent on macOS — the command did not run
at all, so the check silently passed on empty output. It now bounds the boot portably.
Worth recording because a check that cannot run is worse than no check.

**Deliberately unverified:** every query, the workspace-authority refusal, token
deltas, `/compact`, and the invariant sweep's findings. Each needs a session.

## Evidence: L6 plugins load, and the fold is unit-tested

Both plugins activate:

```
[l6-counter] ACTIVE — appends l6/step on each tool result
[l6-projection] ACTIVE — registered the l6Steps unit
```

The projection's pure core was extracted into `l6/fold.js` precisely so its two
subtle contracts are testable without a session. `pnpm run check:units` runs four
tests, all passing:

1. Folding `l6/step` events yields the reported total.
2. An unrelated event returns the **same state reference** — the contract that stops
   a projection recomputing on every committed event.
3. A relevant event returns a new reference.
4. A delta-shaped event yields a wrong total, which is the evidence for the
   "complete post-change state" rule rather than an assertion of it.

**A dependency was declared rather than inherited.** `zod` resolved transitively
before this lesson, but a plugin importing it directly must declare it — ADR-0005's
exception for a package whose *teaching is the point*. It is now in the bundle's
`peerDependencies` and `devDependencies`.

**Deliberately unverified:** appending to a real session, reading `l6/step` rows from
JSONL, and confirming the total survives a restart. Each needs a session.

## Evidence: L5 plugins load (session-dependent claims unverified)

```
[l5-observer] ACTIVE — watching agent/pre-step
[l5-inject] ACTIVE — appends durable context on agent/created
[l5-commands] ACTIVE — /l5-facts registered
```

The skills overlay composes as an in-place override of the base row:

```
- id: skill-filesystem
  name: '@deepseek-ai/dsh-skill-filesystem'
  config:
    customSkillDirs:
      - !!js >-
        process.env.KIT_ROOT ? process.env.KIT_ROOT + '/kit-plugins/l5/skills' : undefined
```

**A stale upstream example was corrected.** `docs/cookbook/adding-a-tool.md` shows
`agent.inject({ content, source: { kind: 'plugin', plugin: '<name>' } })`. That is not
a `UserMessage`: `inject()` requires one, and there is deliberately no catch-all
`plugin` source kind — each producer declares its own. The kit's plugin uses
`createUserMessage` with a declared kind, and `solutions/verify-l5.sh` asserts that
the stale shape is absent.

**Deliberately unverified:** the pre-step payload shape, whether injected text
survives replay, what the model's skill catalog contains, and whether `/l5-facts`
answers without a turn. Each requires a session and therefore a provider.

## Evidence: L4 plugins load (decisions unverified)

Both policy plugins activate on the live composition:

```
[l4-write-scope] ACTIVE — writes confined to <kit>/l4-sandbox
[l4-guard] ACTIVE — monotonic guard registered
```

**A real failure was reproduced and fixed.** The first version of `l4-guard` touched
`ctx.tools` without declaring the service, and the load failed loudly:

```
l4-guard (dsh-exploration-kit-plugins/l4/guard.js): Error: cannot get property "tools" without inject
```

The lesson now documents that `inject = ['tools']` is mandatory, because the service
is not ambient.

**A design correction.** The original gate computed its confinement root from
`process.cwd()`. The dsh process runs from the *checkout*, not the kit, so that
would have defended the wrong tree. The root now comes from the plugin's own config,
supplied by the bundle row with `!!js` at load time.

**Deliberately unverified:** the allow/deny outcomes. Observing them requires a tool
call, which requires a provider. The lesson separates what the boot proves from what
only a call can prove, rather than presenting the former as the latter.

## Evidence: L3 executed (except the runtime-management extras)

**Service provision and consumption**, healthy composition:

```
[l3-clock] service provided as ctx.lessonClock
[l3-uses-clock] 2026-10-01T12:21:13.309Z
[l3-diagnose] 0 stranded fiber(s) matching "l3-"
```

**Stranding the consumer** by setting `disabled: true` on the provider row:

```
[l3-diagnose] PENDING: l3-uses-clock — a required service is missing
dsh: warning: 1 entry did not activate
```

Worth recording: with the filter removed, the same sweep also reported
`AuthorizationService`, `PlatformAccount`, `llm-pi-ai`, and `TypertGatewayService`
as PENDING **in a healthy profile**. None are broken. That is why the diagnose row
is scoped by config — a diagnostic that cries wolf is worse than none.

**Hot reload**, editing `l3/uses-clock.js` while the process ran under the `hmr`
overlay with `root` set to the kit's plugin directory:

```
[l3-uses-clock] 2026-10-01T12:21:49.606Z          <- before the edit
[l3-uses-clock-EDITED] 2026-10-01T12:22:07.232Z   <- after saving, no restart
```

### Two upstream-tutorial traps found by running it

1. **`FiberState` is a `const enum`.** TypeScript erases it and the published
   `@deepseek-ai/cordis` does not export it, so the upstream Cordis tutorial's
   `import { FiberState, type Context } from '@deepseek-ai/cordis'` fails at load.
   Verified: `node -e "import('@deepseek-ai/cordis').then(c => console.log(c.FiberState))"`
   prints `undefined`. The lesson compares the stable numeric states instead.
2. **`Config` must be a real Standard Schema.** A hand-rolled `{ parse }` object
   fails with `TypeError: Cannot read properties of undefined (reading 'validate')`.
   Schemastery works and is already a bundle dependency.

## Evidence: L2 executed (except the model call)

All three behavioural claims were executed against the running harness.

**The plugin loads through the bundle**, proving its `@deepseek-ai/dsh-tools` and
`@deepseek-ai/schemastery` imports resolve and its config reaches `apply`:

```
[l1-hello] apply() ran — plugin is ACTIVE
[l2-wordcount] ACTIVE — defaultUnit=lines
```

**An invalid value is rejected before `apply` runs:**

```
dsh: warning: 1 entry did not activate
l2-wordcount (dsh-exploration-kit-plugins/l2/wordcount.js): ValidationError: invalid config:
  - $.defaultUnit expected "words" | "lines" | "chars" but got "paragraphs" (at defaultUnit)
    at resolveConfig (file:///<checkout>/vendor/cordis/lib/index.js:960:27)
```

This corrected an earlier draft that paraphrased the error and omitted the `$`
prefix Cordis supplies.

**An overlay patch overrides the installed row:**

```
$ dsh --profile kitdemo --patch <kit>/solutions/l2.override.patch.yml
[l2-wordcount] ACTIVE — defaultUnit=chars
```

`solutions/verify-l2.sh <checkout>` was run against the real harness and passes:

```
== 1. valid overlay composes ==
PASS  overlay row present
PASS  module resolves to the kit file
PASS  no doubled path segment
PASS  config value carried
== 2. schema declares defaultUnit as a closed union ==
PASS  Config declares a closed union for defaultUnit
PASS  Config is exported as both a type and a runtime schema
== 3. stacked overlays, last write wins ==
PASS  override value wins
```

A defect was found and fixed during this verification: placing the patch file
*inside* the plugin directory made `'./l2/wordcount.ts'` resolve to a nested
`solutions/l2/l2/wordcount.ts`. The lesson now documents that trap explicitly.

**Deliberately not verified:** `--dump-config` composes config rows and does **not**
run Schemastery validation, so the claim that an invalid `defaultUnit` is rejected
at load remains unproven. It needs a harness boot with the plugin mounting.

## Evidence: L1 executed

The L1 mechanics were booted against the real harness before the lesson was
written, which is how two footguns were found and fixed in the lesson text:

**Patch composition.** `dsh --profile web --patch <overlay> --dump-config`
composed the overlay row correctly. Two failure modes were observed and are now
documented in the lesson's troubleshooting table:

- A bare `- id: <new-id>` entry failed with
  `patch: entry "<new-id>" not found` — new rows require `- insert:`.
- A `name` written relative to the workspace root silently resolved to a doubled
  path (`exploration/plugins/exploration/plugins/l1/hello.ts`) — the specifier is
  relative to the **patch file**.

**Full lifecycle observed.** Booting
`dsh --profile web --patch <overlay> --port 0 --no-open` produced, in order:

```
[l1-hello] apply() ran — plugin is ACTIVE
[l1-hello] effect registered
dsh web: http://127.0.0.1:<port>/?token=...
[l1-hello] disposer ran — plugin is DISPOSED   (on shutdown)
```

This confirms `LOADING → ACTIVE → UNLOADING → DISPOSED`, that effects unwind on
unload, and that the disposer runs on graceful shutdown.

**Sandbox limitation.** The agent file sandbox blocked `dsh` from writing
`~/.dsh/profiles/web/cordis.yml` (`EPERM: operation not permitted`). Every lesson
therefore instructs readers to run boot commands in their own shell. This is an
environment fact, not a DSH defect.

## Not verified at all

- Any **client/UI plugin authoring** (React conversation nodes) — out of scope of
  the curriculum.
- **Model-call-dependent outcomes** in L5, L7, L8, and L9 — these require a
  configured provider and have not been run by the author.
- The L9 **Python SDK** snippet — now a real upstream example, still unrun.
- **An actual model tool call** for L2's `word_count` (and every other tool the kit
  registers). Needs a configured provider.
- **Runtime behavior of every example plugin** (L2's tool registration, L3's
  service and HMR loop, L4's gate denying a real call, L5's injection and skill
  catalog, L6's projection replay) — the mechanisms are verified against source
  and, for L2, composition is executed; the plugins have not been mounted.

## Verification backlog

Ordered by value:

1. Run L2–L6 end-to-end against `0.2.0-rc.2` and promote each to **Executed**.
2. Replace the L9 Python placeholder with a tested snippet, or delete the step.
3. Add a `scripts/verify.sh` that boots each lesson overlay headlessly and
   asserts on `--json` output, so this file can be regenerated mechanically.
4. Re-run the whole curriculum on the next DSH release and record the version
   bump, including any import-path or command changes.
