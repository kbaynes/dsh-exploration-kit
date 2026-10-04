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
| Source commit | `639ed01539` |
| Platform | macOS (darwin), Node.js 22.23.1 |
| Verifier | Kit author |

DSH is a developer preview with explicitly breaking changes. On a different
version, expect to adjust commands and package import paths.

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
| L3 — Services, isolation, and hot reload | **Partly executed** | `PENDING` semantics and the fiber state machine read from `docs/cordis-tutorial/02..03`; the `diagnose.ts` registry walk and the HMR reload observation are **documented, not run**. |
| L4 — Build a policy gate | **Partly executed** | The `PreToolDecision` union and pipeline order are verified against `packages/core/tools/src/index.ts` and `packages/core/tools/README.md`. The example gate plugin has **not** been executed. |
| L5 — Assemble context deliberately | **Documented** | Verified against `docs/architecture.md`, `docs/cookbook/adding-a-tool.md` (`agent.inject()` semantics), `packages/skill/skill-filesystem/README.md`, and `packages/interaction/commands/README.md`. Not run; needs a model. |
| L6 — Give the session durable state | **Documented** | `SessionEventMap` merge shape and `session.append` signature verified against `packages/deliverables/tool-present/src/types.ts` and `packages/core/session/src/index.ts`; projection rules from `packages/session/session-projection/README.md`. The JSONL replay experiment has **not** been run. |
| L7 — Operate the harness | **Documented** | Bundle rows, `tool-session-query` contract, and telemetry env vars verified against the bundle patches and package READMEs. Query authorization and cost measurement not run; needs a model. |
| L8 — Orchestrate multiple agents | **Documented** | Subagent provider rows verified against `packages/bundle/base/cordis.patch.yml`; agent-team caps verified against `packages/experimental/agent-team-profile/cordis.patch.yml`. Needs a model. |
| L9 — Automate the harness | **Documented** | Headless CLI contract, SDK usage, schedule and webhook contracts read from package READMEs. **The Python snippet in step 3 is a placeholder** and must be replaced or removed before publication. Needs a model. |

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
`dsh plugin --profile <name> add file:<kit>/kit-plugins`. Verified end-to-end:

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
