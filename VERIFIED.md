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
| L1 — Mount your first plugin | **Executed** | See evidence below. This is the only lesson verified end-to-end. |
| L2 — Register a tool, compose with config | **Documented** | `defineTool` contract and Schemastery config pattern read from `docs/cookbook/adding-a-tool.md` and `docs/cordis-tutorial/05-config.md`; patch-layer and `!!js` behavior verified under L1. Tool registration itself not executed. |
| L3 — Services, isolation, and hot reload | **Partly executed** | `PENDING` semantics and the fiber state machine read from `docs/cordis-tutorial/02..03`; the `diagnose.ts` registry walk and the HMR reload observation are **documented, not run**. |
| L4 — Build a policy gate | **Partly executed** | The `PreToolDecision` union and pipeline order are verified against `packages/core/tools/src/index.ts` and `packages/core/tools/README.md`. The example gate plugin has **not** been executed. |
| L5 — Assemble context deliberately | **Documented** | Verified against `docs/architecture.md`, `docs/cookbook/adding-a-tool.md` (`agent.inject()` semantics), `packages/skill/skill-filesystem/README.md`, and `packages/interaction/commands/README.md`. Not run; needs a model. |
| L6 — Give the session durable state | **Documented** | `SessionEventMap` merge shape and `session.append` signature verified against `packages/deliverables/tool-present/src/types.ts` and `packages/core/session/src/index.ts`; projection rules from `packages/session/session-projection/README.md`. The JSONL replay experiment has **not** been run. |
| L7 — Operate the harness | **Documented** | Bundle rows, `tool-session-query` contract, and telemetry env vars verified against the bundle patches and package READMEs. Query authorization and cost measurement not run; needs a model. |
| L8 — Orchestrate multiple agents | **Documented** | Subagent provider rows verified against `packages/bundle/base/cordis.patch.yml`; agent-team caps verified against `packages/experimental/agent-team-profile/cordis.patch.yml`. Needs a model. |
| L9 — Automate the harness | **Documented** | Headless CLI contract, SDK usage, schedule and webhook contracts read from package READMEs. **The Python snippet in step 3 is a placeholder** and must be replaced or removed before publication. Needs a model. |

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
- The L9 **Python SDK** snippet — placeholder only.

## Verification backlog

Ordered by value:

1. Run L2–L6 end-to-end against `0.2.0-rc.2` and promote each to **Executed**.
2. Replace the L9 Python placeholder with a tested snippet, or delete the step.
3. Add a `scripts/verify.sh` that boots each lesson overlay headlessly and
   asserts on `--json` output, so this file can be regenerated mechanically.
4. Re-run the whole curriculum on the next DSH release and record the version
   bump, including any import-path or command changes.
