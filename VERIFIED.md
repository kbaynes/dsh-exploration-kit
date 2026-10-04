# Verification Status

This file records **what has actually been executed** against which DeepSeek Harness version, so readers know how much weight each lesson's claims carry.

> **Rule for contributors: never mark a step verified unless you ran it.** Documented-but-unrun is a legitimate status. Overstated verification is the most damaging error this repository can make.

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

Record the **full** commit, not an abbreviation: a short hash is not a stable identifier for reproducing the state these lessons were verified against.

DSH is a developer preview with explicitly breaking changes. On a different version, expect to adjust commands and package import paths.

## Harness state this kit targets

Every verification in this file is a statement about **one harness state**, identified by the upstream commit above. The kit is not versioned against a moving target.

### Release-time gate

Before a kit release is tagged, all of the following must hold:

- [ ] Every lesson is **Implemented** and **Tested** in [ROADMAP.md](https://github.com/kbaynes/dsh-exploration-kit/blob/main/ROADMAP.md).
- [ ] The upstream tree used for verification was **clean** at capture, so the commit
      identifies exactly what was exercised. Debris in the harness checkout invalidates
      the record.
- [ ] The table above carries the full upstream commit, its tag, and the capture date.
- [ ] `package.json`'s `packageManager`, the kit lockfiles, and the pinned optional
      package versions all match the release under test (see
      [ADR-0013](https://github.com/kbaynes/dsh-exploration-kit/blob/main/decisions/0013-pin-optional-package-versions.md)).
- [ ] No pre-publication placeholder remains: `pnpm run check:placeholders` passes.
- [ ] `pnpm run check:kit` passes in full.

### Tag naming

A kit release tag records the harness state it targets, so the relationship survives without reading prose:

```
v<kit-version>+dsh.<dsh-version>.g<short-dsh-sha>
```

For the state verified here that would be, for a kit version of `0.1.0`:

```
v0.1.0+dsh.0.2.0-rc.2.g639ed01539
```

The tag is a claim: everything in it was verified against that commit. Retagging to a newer harness commit means re-running the verification, not editing the record.

### When upstream moves

DSH is a developer preview with explicitly breaking changes. On each upstream release:

1. Re-run `pnpm run check:kit` against the new checkout.
2. Re-verify the lessons the change touches; re-promote each `VERIFIED.md` row with its new evidence, and demote any whose claims no longer hold.
3. Update the table above and the pinned versions in one pass, so no two of them can disagree.
4. Tag a new kit release at the new commit.

**Demoting a row is the honest outcome of an upstream break, not a failure.** A row that claims verification against a commit where the behaviour changed is worse than a row that admits it has not been checked yet.
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
| L1 — Mount your first plugin | **Executed** | The lifecycle cycle is verified twice — via a patch overlay originally, and again after the bundle pivot, which is what the lesson now teaches. The deliberate `FAILED` throw and the `PENDING` inject are both executed, and their real output corrected two draft assumptions in the lesson text. Nothing in this lesson is unverified. See evidence below. |
| L2 — Register a tool, compose with config | **Executed** | The plugin loads through the installed bundle; the Schemastery schema rejects an invalid value; an overlay changes the installed row's config; and the **tool itself is called through the real pipeline** by a shipped probe — the configured default reaches it, an explicit unit overrides it, invalid arguments are rejected before `execute` runs, and `value`/`content` show the canonical/render split. Outside this lesson's scope: whether a model *chooses* to call it. See evidence below. |
| L3 — Services, isolation, and hot reload | **Executed** | The service is provided as `ctx.lessonClock` and consumed; disabling the provider strands the consumer and the scoped sweep names it `PENDING`; editing a plugin file reloads it live under the `hmr` overlay; the `plugin_manager` claim is executed and **corrected** (it manages the profile's rows and whole bundles, not rows a bundle contributes — ADR-0025); and **service isolation is executed** — two groups isolating one service name each see their own provider. Two upstream-tutorial traps found by running it. Nothing in this lesson is unverified. |
| L4 — Build a policy gate | **Executed** | Both plugins load, the missing-`inject` failure was reproduced, and the gate's **decisions** are exercised through the real tool pipeline by a shipped probe: an outside write is `GATE-DENIED` with the lesson's reason, and an inside write is *not* denied by the gate (a second policy layer stops it, since the target is outside the agent's workspace). Still unverified: `ask` decisions and guard undo-ability against a live competing listener. |
| L5 — Assemble context deliberately | **Executed** | Executed: all three plugins activate; `agent.inject()` is built from `createUserMessage`; injected context is proved **durable across a restart** in two processes (carried by a first-party `agent/inbox/spliced` event); the skills overlay composes; and the **command path is executed** — `/l5-facts` dispatches through `ctx.commands.execute`, returns its text, logs `command/run` + `command/done`, and records **zero model-request events**. The **model-visible skill catalogue** is executed end to end: against the mock provider a real turn assembles a request, the session log carries the skill catalogue with the skill's BODY absent, and when the model then **calls the `skill` tool** the body loads through the real tool pipeline — announced on demand, loaded on demand. A skill **added to a watched root live** also reaches the catalog with **no restart**: two sessions in one process see different catalogs once a new skill directory is written, and the added skill's body is not shipped either. Nothing in L5 is left unexecuted. |
| L6 — Give the session durable state | **Executed** | Rebuilt on the pattern that works, and proved across a **restart in two processes**, with no model: phase one derives the session's permission mode and changes it via a real preset switch (`workspace-write` → `danger-full-access`); phase two, a fresh process, resumes the session and reports `danger-full-access` reconstructed from the persisted log. The fold uses a first-party event type, and the check fails if any plugin invents one. The earlier defect is retained as a deliberate, disabled hazard. **Not verified:** the fold's behaviour under a real model turn, which is a question about the model rather than about durable state. See evidence below. |
| L7 — Operate the harness | **Executed** | Executed: the overlay composes and boots with no warnings; the pinned package installs; the query service lists and reads; all five lesson tools register in an agent root scope (5/5); the invented-type caveat is asserted with self-cleanup; and the row no longer claims that a log-only event is findable by a type filter — **structural events produce no searchable document at all**, which the source explains, and the positive case is asserted on a session that has semantic text (see the evidence below); the invariant rows are asserted to report **no violation**; and against the mock provider a **real turn COMPLETES** — it produces its own assistant message, ends `{"kind":"completed"}`, is searchable back to its own session, and exposes the **token-accounting projection** with real numbers — `uncachedInputTokens: 3` and `outputTokens: 23`, the mock's constants, not zeroes; `/compact` reports a **measurable reduction** (`Compacted 4 history items (~4742 tokens)`). An earlier version of this row claimed the turn's text was searchable: that check was green because the search matched OTHER sessions, and it now searches for a marker unique to the run and asserts the hit is this session. `session_event_read` is executed through a real tool call and returns the target event as JSON with `Before:`/`After:` neighbour summaries. The **workspace-authority refusal** is executed too, via a real model-driven tool call into a session under a different `cwd`: the tool result is refused with `SESSION_QUERY_TOOL_UNAUTHORIZED`, and a nonexistent target produces a byte-identical refusal, so the target's existence does not leak. The **token delta from mounting a tool** is executed with a real provider: the same prompt, the same model, one row toggled, and the tool's schema costs **1,664 input tokens** (14,544 with `tool-session-query`, 12,880 without). Nothing in L7 is left unexecuted. |
| L8 — Orchestrate multiple agents | **Executed** | Executed: the orchestration primitives are mounted by the base bundle (no kit plugin needed); the workflow's pure core passes 7 unit tests with a fake engine; fork heredity is verified through derived state (inherited prefix, `isSeeded`, parent lineage, and L6's projection reflecting the inherited event); and a **real end-to-end delegation** is executed keyless against the mock provider — three model requests (parent call, child turn, parent finish) and a child session recorded with a parent link. The **monolith-versus-fan-out cost comparison** is executed and measured: one turn costs 26 tokens, the same task as a fan-out costs 57 (parent 31 + child 26), and the child's 26 are attributed to the **child's own session** rather than pooled. Measuring it also explained an apparent stall: a child's session was sometimes left open because the mock's scripted call took `subagent`'s **default background scheduling** and the headless process exited mid-turn; `run_in_background: false` closes it every time, and the phase now asserts the child's turn **closed** rather than merely counting requests. The two model-judgement items are executed too, with a real provider: a spawned child **does not** share the parent's conversation (a passphrase is in the parent's log, absent from the child's, and the child answers `NOT-TOLD`), and `send_message` **reaches a live child** while `interrupt_agent` **stops it** (the parent calls all four tools, the marker arrives in the child's log, and the child's turn closes as an abort). What remains unexecuted is only the *magnitude* of the cost comparison. The mock's input is a constant 3 tokens and its output is a scripted reply's character count, so the totals prove correct attribution across agents rather than a realistic price. |
| L9 — Automate the harness | **Executed** | Executed: `schedule` and `webhook` are opt-in; the overlay activates on a web-backed profile with no warnings; both install pinned; a scheduled task **survives a restart**; **delivery** is verified end to end — a due task splices its reminder, records a delivery receipt, resumes the session and **completes the scheduled work** (a second assistant message, `{"kind":"completed"}`); the **headless contract** (exit codes, stdout/stderr, `--json` phases, and a real **tool call with its correlated result** in the stream) runs keyless; and a **real SDK round trip** runs keyless too — the SDK drives a turn, receives the model's answer, reports the session, and observes 23 notifications — including an SDK run that **loads a patches file and executes an earlier lesson's tool**: the mock scripts a `word_count` call that omits `unit`, the patch sets `defaultUnit: chars` for Lesson 2's tool, and the result reads `11681 chars` — the real character count of the kit README. The patched unit proves the patch was loaded; the count proves the tool read the file. The **webhook delivery** is executed too: a signed GitHub delivery is accepted (202) and creates **exactly one Session**, an unsigned one is refused as malformed (400) and a wrongly signed one as unauthenticated (401), and a **repeated delivery id runs the rule again** (2 Sessions), which is the documented behaviour since `deliveryId` is never used for built-in deduplication. It needed no credential: the adapter takes a credential *reference*, and credential resolution reads the process environment first, so the check signs its own payload. Nothing in L9 is left unexecuted. |

## Design pivot: plugins must be a bundle, not a `--patch` overlay

**Verified finding.** Pointing a `--patch` overlay at a loose plugin file works only when that plugin imports **nothing** from dsh. A plugin that imports `@deepseek-ai/dsh-tools` fails to load:

```
dsh: warning: 1 entry did not activate
l2-wordcount (file:///.../solutions/l2/wordcount.ts): failed to import
```

The loader resolves the relative path outside the dsh installation, and pnpm symlinks only declared dependencies, so `@deepseek-ai/*` is unreachable from an arbitrary directory. This was reproduced both outside the checkout and from inside it (`packages/dsh-exploration-kit/`), so it is a module-resolution property, not a path bug.

**Verified fix.** Package the exercises as a real bundle. `kit-plugins/` now declares `dsh.bundle`, names its rows by package, and is installed with `dsh plugin --profile <name> add link:<kit>/kit-plugins`. Verified end-to-end:

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

The plugin imports `@deepseek-ai/dsh-tools` and `@deepseek-ai/schemastery`, mounts its tool, and receives validated config. **This supersedes the `--patch` overlay instructions throughout the lessons**, which must be rewritten to install the bundle. The overlay concept remains useful for *overriding* an installed row's config, which is still how Lesson 2's last-write-wins exercise should be taught.

**Dependency versions** are pinned to the release under test: `@deepseek-ai/dsh-*` at `0.2.0-rc.2`, `@deepseek-ai/schemastery` at `^3.18.4`. Bump them with each verification pass.

### `link:` is required while editing, `file:` is not enough

**Verified.** `dsh plugin add file:<path>` **copies** the package into the profile. A plugin row added to the kit afterwards did not compose until reinstall:

```
$ dsh --profile kitdemo --dump-config | grep -A8 dsh-exploration-kit-plugins
# == dsh-exploration-kit-plugins
- id: l2-wordcount            # the l1-hello row added minutes earlier is absent
```

`dsh plugin add link:<path>` creates a symlink instead, and every subsequent edit composes live:

```
lrwxr-xr-x  dsh-exploration-kit-plugins -> ../../../../MyDocs/DeepSeekHarness/dsh-exploration-kit/kit-plugins
```

**All lesson instructions use `link:`.** This is not cosmetic: the lessons ask the learner to edit plugin files and observe the change, which `file:` would defeat.

### Lesson 1 re-verified through the bundle

Booted `dsh --profile kitdemo` with both bundle rows installed:

```
[l1-hello] apply() ran — plugin is ACTIVE
[l1-hello] effect registered
[l2-wordcount] ACTIVE — defaultUnit=lines
dsh web: http://127.0.0.1:<port>/?token=...
[l1-hello] disposer ran — plugin is DISPOSED      (on shutdown)
```

This confirms the full cycle through the *bundle* path, not the retired overlay path, and confirms a `.ts` module loads from an installed bundle.

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

**Two draft assumptions were wrong and are corrected in the lesson:** the boot warns and continues rather than exiting non-zero, and `PENDING` is *not* silent — the startup summary names the missing service.

## Evidence: L9 the SDK round trip, keyless

`solutions/sdk-roundtrip.mjs` imports the SDK by absolute path out of the checkout (pnpm does not hoist it, so a bare specifier fails) and drives one turn against the mock:

```
finalResponse="mock response recovered"
sessionId=session-0f92550e57ce453688600f03413614a1
notifications=15
```

Five assertions: exit 0, the answer, the session id, a non-empty notification feed, and that the SDK home holds an **uncompressed** session log.

**One thing came out of making it work.** The SDK needs its own `DSH_HOME`: its profile persists sessions uncompressed while the base and web profiles write `.jsonl.zstd`, and sharing a home fails with *"uses .jsonl.zstd, but this backend is configured for compression none"*.

## Evidence: L9 delivery resumes the session and the scheduled work COMPLETES

A task scheduled two seconds out, with the mock provider supplying the model. The probe reports:

```
[l9-fire] warm-up turn produced 1 assistant message(s)
[l9-fire] the session logged a request header: true
[l9-fire] scheduled schedule-6552f8d1-… to fire in 2s
[l9-fire] delivery receipt: {"scheduledAt":"2026-10-03T05:50:48.096Z",
    "deliveredAt":"2026-10-03T05:50:48.105Z","messageId":"f94a6d08-…",
    "prompt":"The scheduled task fired; report that you ran."}
[l9-fire] deliveries reported: 1
[l9-fire] assistant messages in the session: 2
[l9-fire] the delivered turn ended: {"kind":"completed"}
```

In the session log that is `agent/inbox/spliced` delivering the reminder, `turn/start` opening the turn, and a second `assistant/message` followed by `{"kind":"completed"}` — the scheduled work really ran, and the receipt is recorded.

**Two fixes were needed, and both are instructive.**

- The turn used to die at `turn/start` with `cannot get property "toJSON" without inject`. That was **this repository's bug**, not the harness's: Lesson 5's pre-step listener called `JSON.stringify(payload)` on a live event payload, and reaching `toJSON` on the Cordis proxy inside it throws. See ADR-0028. It was attributed upstream here for two rounds, while an audit of 119 entry `Config` schemas found nothing because the fault was never in them.
- Delivery then failed one layer deeper with `prompt variable "{{model}}" has no value`. Delivery restores provider/model from the session's **logged request header**, so a programmatically created session that has never made a request resumes with no model at all. The probe now talks to the model once before scheduling — the realistic shape of a scheduled follow-up in any case.

`solutions/l9.fire.patch.yml` reproduces it, and it **is** wired into `solutions/verify-l9.sh` (phase 8) now that it passes. It stayed out while it failed: a check that fails for a reason outside this repository trains people to ignore the suite.

## Evidence: L9 the --json stream carries a tool call and its correlated result

The headless phases previously proved the stream's text and phase events. This one proves it carries a real **tool call**, with the mock scripting the call and the harness validating and dispatching the tool:

```
"type":"tool_call","callId":"mock-call-1","tool":"bash","input":{"command":"echo l9-tool-call-ok",…}
"type":"tool_result","callId":"mock-call-1","status":"error","result":"Error: sandbox mode …"
```

**The result status is deliberately not asserted as `completed`.** Whether a tool can actually run depends on the host, and on this machine the sandbox backend is not usable (`sandbox-exec: sandbox_apply: Operation not permitted`), so the call is refused at execution — correctly. What is host-independent, and what the lesson's claim actually is, is the stream **contract**: a `tool_call` naming the tool with its parsed input, and a `tool_result` carrying the same `callId`. The check asserts the correlation, because a result that cannot be tied to its call is not observable.

**A wiring bug caught here too.** The phase first ran after the script had deleted the model patch it reused, so `--patch` pointed at a removed file and the boot failed with six unexplained errors. It now writes its own patch — the same fix already needed for the delivery phase.

## Evidence: a fresh clone passes the WHOLE suite in a fresh harness home

The strongest check of publication readiness is the workflow the documentation gives a reader, performed literally on a new checkout with no local state:

```
$ git clone <kit> /tmp/kit-clone && cd /tmp/kit-clone
$ pnpm run setup                                  # exit 0, both dependency roots
$ pnpm run check:kit                              # no checkout yet
11 passed, 0 warned, 0 failed, 9 skipped          # the 9 need a DSH checkout

$ export DSH_HOME=/tmp/kit-clone-home             # a home that has never seen this kit
$ bash scripts/setup-verify-profiles.sh ~/.local/bin 0.2.0-rc.2
Profiles provisioned at dsh 0.2.0-rc.2.
$ DSH_CHECKOUT=<checkout> pnpm run check:kit
20 passed, 0 warned, 0 failed, 0 skipped
harness left: 0
```

Three things this establishes that nothing else does:

- **The generated files really are generated.** `content/VERIFIED.md`, `content/CONTRIBUTING.md` and `content/THIRD-PARTY.md` are gitignored and absent from a clone; the OKF check and the site build pass anyway, because the sync runs first.
- **The install story works from nothing.** `setup-verify-profiles.sh` provisions every profile the per-lesson checks need — including the kit bundle into *two* profiles and the pinned optional packages — in a home that started empty.
- **The suite's own hygiene holds on a clean machine.** `harness left: 0` after 27 boots, which is the property [ADR-0035](https://github.com/kbaynes/dsh-exploration-kit/blob/main/decisions/0035-a-background-launch-is-killed-by-the-pid-you-started.md) and [ADR-0036](https://github.com/kbaynes/dsh-exploration-kit/blob/main/decisions/0036-never-wait-unboundedly-on-a-process-you-no-longer-need.md) restored.

## Evidence: L9 an SDK run loads a patches file and executes an earlier lesson's tool

Verification item 6 in Lesson 9, and the strongest of the SDK claims: the SDK composes a profile from a **patches file** and a tool from an earlier lesson actually runs.

The mock scripts a `word_count` call that **omits** `unit`, and the patch is Lesson 2's own override:

```
$ cat solutions/l2.override.patch.yml
- id: l2-wordcount
  config:
    defaultUnit: chars

$ ... --tool-arguments '{"path":"<kit>/README.md"}'      # no `unit` in the call
```

The session log inside the SDK's own home:

```
"type":"tool/call","data":{…"name":"word_count","arguments":"{\"path\":\"<kit>/README.md\"}"}
"type":"tool/result","data":{…"content":[{"type":"text","text":"11681 chars"}],"isError":false}
```

`11681` is computed from the file by the check itself, and `chars` is the **patched** unit — the plugin's own default is `words`. So the result cannot be produced unless the patches file was loaded *and* the tool read the real file.

One prerequisite is worth knowing: the SDK spawns `dsh` with its own `DSH_HOME`, and a fresh home has only the shipped `sdk-minimal` **template**, so the kit bundle is not there. Installing a bundle creates the profile, so the phase runs `dsh plugin --profile sdk-minimal add link:<kit>/kit-plugins` into that home first — and `scripts/setup-verify-profiles.sh` now does the same for the shared home.

## Evidence: L9 a signed webhook delivery creates one Session, and a duplicate runs it again

The last claim in the ledger that was called credential-bound. It is not: the GitHub adapter's `secretEnv` is a credential **reference**, and credential resolution reads the inherited process environment first, so the check supplies its own secret and signs its own payload. No GitHub account, no tunnel, no network.

```
PASS  the webhook adapter registered a route on the web server
PASS  the trusted rule registered
PASS  a delivery with NO signature is refused as malformed            (400)
PASS  a delivery with a WRONG signature is refused as unauthenticated (401)
PASS  a signed delivery is accepted                                   (202)
PASS  the first delivery created exactly one Session
PASS  a REPEATED delivery id runs the rule AGAIN (not deduplicated): 2 Sessions
```

Three details are the substance rather than the ceremony:

- **The two refusals are different, and both are asserted.** A request with no signature header is malformed (400); a request carrying a wrong signature is authenticated-and-rejected (401). Provider authentication belongs to the adapter, not to the rule.
- **The duplicate is the interesting half.** `deliveryId` is recorded but never used for built-in deduplication, so a repeated delivery runs the rules again — the check posts the same delivery id twice and asserts the count goes 1, then 2.
- **The rule is registered by a probe, because that is the design.** `ctx.webhookRuntime` is a registry of trusted *programmatic* rules; returning a `WebhookSessionRequest` makes the runtime perform its one built-in action, creating an ordinary root Session in a Web Workspace. Sessions are counted by the id the runtime generates (`webhook-<uuid>`), and the count is a **delta from the probe's start**, so sessions from earlier runs in the shared home cannot inflate it.

**Two harness-fault traps this phase hit, both worth knowing.** A fixed port turns any stray harness from an aborted run into `EADDRINUSE` on the next one — and a stray that outlives `SIGKILL` (ADR-0036) cannot be cleaned up by hand, so the phase now chooses a **free port at run time** and reaps on any exit with a trap. The sneakiest symptom was a delivery count that lagged by exactly one delivery: the POSTs were being answered by the **stray** harness, whose probe had its own baseline, while the new harness never saw them. With a free port the first delivered Session appears in about 2 seconds.

## Evidence: L9 the headless contract, keyless

The remaining "needs a model" claim turned out to need a *provider*, and the repository ships a scriptable one (`dsh-llm-mock-server`). Against it, with no API key:

```
$ DEEPSEEK_BASE_URL=$MOCK/v1 DEEPSEEK_API_KEY=mock-key dsh --profile headless ... "say hi"
mock response recovered
EXIT=0

$ ... --json "say hi"            # stream types/phases observed
session, status(turn_start), status(step_start), text, status(step_end), status(turn_end), final

$ ... against a mock scripted to fail
EXIT=1        stderr: dsh: SERVER: mock script failed
```

`solutions/verify-l9.sh` starts one mock that always succeeds and one that always fails, and asserts eight properties across them. Recorded as ADR-0027, including that the mock consumes one scripted entry per *request* (so one behavior per instance is deterministic) and that `turn_end` is a phase inside a `status` event rather than an event type.

## Evidence: L9 a scheduled task survives a restart

Executed in two processes, no model — creating a task is a service call:

```
PHASE ONE   [l9-probe] created task id=schedule-0a70ae86-… title="l9 schedule probe"
            [l9-probe] listed 1 task(s): l9 schedule probe

PHASE TWO   [l9-probe] after restart, tasks for the session: 1
            [l9-probe]   title="l9 schedule probe" id=schedule-0a70ae86-…
            [l9-probe] after deleting: 0 task(s)
```

The same task id in a process that never created it, so the task is Host storage rather than process memory. `solutions/verify-l9.sh` runs both phases and asserts all three lines. Delivery — a due task resuming the session and the agent working on it — still needs a provider, and the lesson says so.

**Two gotchas found on the way.** The kit bundle had to be installed into the web profile as well as the base one, because L9's probe lives in the bundle but must run where `schedule` can activate (ADR-0016). And the **web profile does not surface a plugin's `console.log`** — its boot prints only the URL — so a probe there must report through a file. Both are now in the lesson and in `scripts/setup-verify-profiles.sh`.

## Evidence: L9 opt-in packages compose and activate

**A premise in the lesson was wrong.** It assumed `schedule_*` and `ctx.webhookRuntime` were available. Neither package is mounted by any shipped bundle. The `schedule` and `webhook` strings in the bundle patches are telemetry tuning knobs (`scheduledDelayMillis`), which is exactly the kind of false match that makes a wrong assumption look confirmed.

**Both are opt-in and must be installed, pinned** (ADR-0013):

```
dsh plugin --profile web add @deepseek-ai/dsh-schedule@0.2.0-rc.2
dsh plugin --profile web add @deepseek-ai/dsh-webhook@0.2.0-rc.2
```

**Profile choice is load-bearing.** On the base-backed `kitdemo` profile the same overlay strands both rows in `PENDING`, naming the services they need:

```
schedule (...): pending (waiting for service: sessionController)
webhook  (...): pending (waiting for services: agentPresets, workspaceRegistry)
```

On a **web-backed** profile with both installed, a boot produced no activation warnings at all. That is Lesson 3's `PENDING` mechanism appearing in a real composition rather than a contrived one.

**Where the tools appear.** `schedule_*` registers in a live root Agent's scope, so it does not show up in `--dump-config`. Composing cleanly proves the service loaded; observing the tools needs a session. The lesson states that rather than implying the dump is evidence.

**Superseded.** An earlier version of this section listed the headless run and its exit codes, `--json` events, the SDK round trip, a schedule firing and a webhook delivery as unverified. All five are executed keyless in `solutions/verify-l9.sh` (phases 6–10).

## Evidence: L4's gate decisions executed

Lesson 4's central claim was recorded as needing a provider. It does not: `ctx.tools.execute()` runs the same pipeline a model-direct call runs, so `kit-plugins/l4/policy-probe.js` dispatches synthetic calls and classifies the denying layer by its reason string.

```
[l4-probe] write-outside: GATE-DENIED  {"isError":true,"error":{"message":"writes are confined to <kit>/l4-sandbox"}}
[l4-probe] write-inside:  OTHER-DENIED {"isError":true,"error":{"message":"[sandbox: file access denied under workspace-write mode]"}}
```

Two things are proven at once: the gate **enforces** (outside is denied with its own reason), and it **discriminates** (inside is not denied by it — a second, independent policy layer stops it, because the target is outside the agent's workspace). Enforcement alone would be satisfied by a gate that blocks everything.

Also recorded: two traps. dsh's filesystem tools take `file_path`, not `path`, and the wrong key is rejected by argument validation *before* policy runs — easy to misread as the gate working. And `ctx.tools.execute()` requires a `signal`.

`bash solutions/verify-l4.sh` asserts both verdicts.

## Evidence: L8 a real delegation, end to end

Against the mock provider, with the first request scripted as a `subagent` tool call:

```
PASS  the delegating turn exits 0
PASS  the parent prints the model's answer
PASS  a child agent ran its own turn (model requests served: 3)
PASS  a child session was recorded with a parent link (5 -> 6)
```

The request count is the evidence that matters: **three** requests means the parent called the tool, a **child ran its own model turn**, and the parent finished — a genuine fan-out, not a simulated one. The parent link in the child's session header makes the delegation durable lineage, which is what `solutions/verify-l8.sh` decompresses the recent session log to check.

**A counter bug worth recording:** the first version of that check grepped the session files for `parentSession` and always reported zero, because the log is `zstd`-compressed. It now decompresses only recently-touched sessions.

## Evidence: L7 the token delta from mounting a tool, with a REAL provider

The one claim in L7 that the mock cannot reach, because the delta is an **input**-side effect and the mock reports a constant `input_tokens: 3` whatever the request contains.

The check holds the composition still and toggles ONE row — both boots mount the session store and the turn probe, and only `tool-session-query` differs — then sends the same prompt to the same model:

```
[l7-tokens] with tool-session-query:    14544 input tokens
[l7-tokens] without tool-session-query: 12880 input tokens
[l7-tokens] steps: with=1 without=1
PASS  mounting the tool adds 1664 input tokens to the request
```

The check asserts the **direction** — the tool-mounted run reports strictly more input tokens — and prints the difference; `1664` is that run's recorded observation, not a constant any assertion compares. The same applies to the L8 cost figures below.

**The single-step requirement is load-bearing, and the first attempt proved why.** With a conversational prompt the model took **seven** steps when the session-query tools were mounted (104,966 input tokens) and **one** without them (12,869) — a difference in trajectory, not in tool schema. The probe's prompt is now configurable and the phase uses one that cannot trigger a tool, then asserts both runs are exactly one step before comparing.

This phase is **opt-in** (`DSH_REAL_PROVIDER_PATCH`), because the repository must stay keyless by default: with no key set it prints `SKIP`.

## Evidence: L8 the same task costs 26 tokens, or 57 as a fan-out

The lesson asks the reader to run one task monolithically and again as a fan-out, then compare the four audit parts. That comparison is measurable, and `solutions/verify-l8.sh` phase 6 performs it:

```
[l8-cost] parent session: session-7f500193-…
[l8-cost] fan-out parent tokens: 31
[l8-cost] fan-out child tokens: 26
[l8-cost] monolith tokens: 26
[l8-cost] fan-out total tokens: 57
PASS  the monolith's tokens are recorded and non-zero (26)
PASS  the CHILD's tokens are attributed to the child's own session (26)
PASS  the fan-out costs more tokens than one turn (57 > 26)
```

As above, the assertion is the **relation** (`fan-out > monolith`), and `57`/`26` are this run's recorded figures rather than compared constants.

Three things make this real rather than decorative. The parent's 31 is summed from the headless `--json` stream's `status`/`step_end` usage events, and the child's 26 from its **own** session log, so the comparison exercises attribution across agents instead of a single counter. Each half is asserted non-zero, because a zero would make every sum vacuously small. And the child's session is read only after waiting for its usage to appear: a child session is durably recorded when it is announced, but its tail is flushed asynchronously, and the first version of this phase read a turn that was still open and reported 0 (ADR-0032's rule, met a second time).

**What this does not establish** is the magnitude. The mock's input is a constant 3 tokens and its output is the character count of a scripted reply, so `57 > 26` proves the harness attributes and sums cost correctly across agents; a realistic price still needs a real provider.

### The stall that turned out to be scheduling, not a harness fault

Measuring the child's share first produced an apparent intermittency: a child's session was sometimes left **open** — ending after `request/context` with no `assistant/message` and no `turn/end` — while the parent returned a normal answer and exited 0. Five of ten observed runs stalled, and a stalled log was still stalled when re-read 30 seconds later.

The cause is the tool's scheduling, not a defect. The base bundle's `subagent` uses the `continuable` background mode, so `run_in_background` **defaults to true**: the parent gets a handle back and the child is scheduled independently. In a one-shot `dsh headless` task the process then exits while the child is still working, and the child's session is never closed. Passing `run_in_background: false` in the scripted call closes it **every time**:

```
$ ... --tool-arguments '{"description":"…","prompt":"…","run_in_background":false}'
run 1 exit=0 requests=4 child events=19 closed=True tokens=26
run 2 exit=0 requests=4 child events=19 closed=True tokens=26
run 3 exit=0 requests=4 child events=19 closed=True tokens=26
```

Two things were wrong with the verification, and both are fixed. It drove the tool in a mode it did not intend, and its assertion — "at least three model requests" — was satisfied by a child that was spawned and then abandoned, so it passed while the child never finished. The phase now asserts the child's turn **CLOSED** (a child with recorded usage has an `assistant/message` and a `turn/end`). The retry that used to be the mechanism stays as a guard and still prints its attempt count ([ADR-0034](https://github.com/kbaynes/dsh-exploration-kit/blob/main/decisions/0034-a-retry-must-report-itself.md)).

## Evidence: L8 a spawned child does not know the parent's conversation

The claim the mock cannot show, since scripted output does not depend on what the child was given. The test is mechanical rather than judgemental: a unique passphrase goes into the parent, the child is asked for it, and the assertion is about the **child's session log**:

```
[l8-context] the parent's own log contains the passphrase: true
[l8-context] child session: c67ec994-53c2-48d5-b253-ba3260194445
[l8-context] the child's log is non-empty: true
[l8-context] the child's log contains the passphrase: false
[l8-context] the child's turn closed: true
[l8-context] the child replied NOT-TOLD: true
```

The passphrase is present in the parent's conversation and absent from the child's. What the child *says* is printed for the reader; the assertion is the absence.

## Evidence: L8 send_message reaches a live child, and interrupt_agent stops it

The only claim in the lesson that needs the **model to choose**, because the child's session id exists only after the spawn — a scripted call could never name it:

```
[l8-control] the parent's tool calls: subagent,list_agents,send_message,interrupt_agent
[l8-control] child session: c26ff980-a490-4e66-a64e-bfbd858a4df9
[l8-control] the message reached the child: true
[l8-control] the child's turn closed: true
[l8-control] the child was interrupted rather than completing: true
```

Two corrections this cost, both worth recording. The tool calls are counted **structurally** (`tool/call` events by name), because a substring search over the log is satisfied by the tool **catalogue** in `request/header`, which lists every tool name — the first version reported all three tools as "called" during a turn that made no call at all. And the *first* real run failed with `Provider finish_reason: error`; retrying the identical composition succeeded, so that was the provider, not the harness.

Both L8 phases are **opt-in** (`DSH_REAL_PROVIDER_PATCH`); with no key they print `SKIP`, and the default suite stays keyless.

## Evidence: L8 fork heredity, verified through derived state

Executed without a model — creating and seeding sessions is not a model call:

```
[l8-probe] parent log prefix: 5 event(s), seqs 0,1,2,3,4
[l8-probe] child inheritedEventCount: 5
[l8-probe] child header isSeeded: true
[l8-probe] child parentSession: session-l8-parent-…
[l8-probe] child projection: {"mode":"read-only"}
```

The last line is the substantive one: the child's **Lesson 6 projection already reflects the mode carried by the inherited event**, so heredity is observed through derived state rather than through a header field alone. A projection that inferred the cut instead of reading it would misreport forks, and this is the check that would catch it. `solutions/verify-l8.sh` asserts all four lines.

**Two API contracts found by probing, both now in the lesson:**

```
seed event at index 0 has seq 4 (expected 0); seed must be contiguous from 0
seeded session requires an inherited event count
```

The seed must be a **prefix** of the parent's log, and `inheritedEventCount` is **mandatory** whenever `meta.isSeeded` is set.

**A near-miss worth recording:** a truncated `grep` made me believe `inheritedEventCount` was not on `CreateAgentOptions`, and I was one edit away from "fixing" a snippet that was correct. The rule added after round 13 — verify before you edit — applies to reading code as much as to writing it.

## Evidence: L8 orchestration primitives are mounted, and its logic is unit-tested

**This lesson adds no plugin.** `tool-subagent`, `tool-subagent-fork`, `tool-subagent-control`, `tool-workflow`, and `workflow-ptc` are all mounted by the base bundle, so orchestration is capability the harness already provides rather than something the kit installs. Worth recording because it is the opposite of L6's expectation.

**The workflow's pure core is unit-tested without a model.** The engine injects `agent`, `pipeline`, `phase`, and `log` into a workflow script, so a function that takes them as parameters is testable with fakes. `kit-plugins/l8/audit-workflow.test.mjs` runs seven tests, all passing, covering:

- the result schema has an object root with `additionalProperties: false`
- a throwing stage drops **that item** to `null` — it does not reject the run
- a malformed result is dropped rather than crashing the flatten
- flattening keeps order and tags each row's section
- a partially failed fan-out still yields a dense array
- the prompt names the section verbatim
- `runWorkflow` drives `pipeline`, logs each item, passes the schema through, and returns a dense result

**A stale path was found and fixed.** L8 and L9 still pointed readers at `doc/exploration/...`, the workspace location the curriculum left when it became a standalone repository. Both now use `<kit>/content/...`.

**This section covers the contract the workflow engine guarantees, and nothing more.** The parts that need a provider are verified in their own sections below: fork heredity, a real delegation, and the monolith-versus-fan-out comparison (keyless), plus the two claims that need model judgement (opt-in, with a real provider).

## Evidence: L7 the invariant checks run clean

The overlay inserts both invariant rows, and a violation **throws** `InvariantError` rather than logging one — so the check is that this boot mounts them and reports none:

```
PASS  no activation warnings
PASS  the invariant checks ran and reported no violation
```

That is the strongest claim available: `ctx.invariants` exposes `register(packageName, installer)` and no way to enumerate or run checks on demand, so "no violation was reported" is honest where "the checks found nothing" would not be.

**A cost bug found while adding it:** that boot's readiness pattern waited for `dsh web:`, which a base-backed profile never prints — so it sat out the full 60-second timeout and then asserted on a half-started log. Accepting either the web URL or the kit plugin's own apply line cut verify-l7 from about 75 seconds to 15.

## Evidence: L7 session_event_read returns an event as JSON, with its neighbours

The claim is about tool *output*, so the tool has to run. The mock scripts the call and the harness executes it; `session_id` is optional on this tool, so the call targets the caller's own session and no id has to be known before the harness boots:

```
[l7-event] result 0 isError=false: Session session-l7-event-read-… — mock response recovered |
    Target event seq 1: | ```json | { |   "type": "sandbox/mode", |   "seq": 1, |   "time": … |
    "data": { |     "mode": "workspace-write" |   } | } | ``` |  | Before: | - seq 0 |
    permission/preset | …Z | (no semantic text) |  | After: | - seq 2 | approval/policy | …Z |
    (no semantic text) | - seq 3 | agent/inbox/spliced | …Z | (no semantic text)
```

Phase 9 asserts each part separately: the target event is JSON (`"type": "sandbox/mode"`), the prefix names the seq, and both directions of neighbour are summarised.

**Why a dedicated probe for this.** The first attempt reused the authority probe, which truncated every tool result to 700 characters — cutting off exactly the neighbour lists the claim is about. A check that cannot see its own evidence is a check that will pass for the wrong reason, so the event-read probe prints results in full.

## Evidence: L7 the accounting carries REAL numbers, and /compact reduces measurably

Two claims in this row were wrong or unproven because of one false premise — that the mock reports no usage for scripted text. It always did. `llm-mock-server` sends `input_tokens: 3` (a constant) and an `output_tokens` equal to `Array.from(successText).length`, which is 23 for `mock response recovered` and 2 for a tool call:

```
[l7-turn] tokenUsage: {"totals":{"uncachedInputTokens":3,"outputTokens":23,"cacheReadTokens":0,
           "cacheWriteTokens":0},"last":{"turn":1,"step":1,"buckets":{…}}}
[l7-turn] /compact outcome: {"kind":"success","text":"Compacted 4 history items (~4742 tokens).",
           "sourceEventSeq":27}
```

So phase 7 asserts exact values (`"uncachedInputTokens":3`, `"outputTokens":23`) rather than the shape alone, and asserts that `/compact` reports how much it removed.

The correction matters beyond the numbers. A shape-only check was justified by a limitation that did not exist, and it stayed that way for several rounds — the same failure as the search that matched other sessions, in a quieter form: an assertion that was true but weaker than the claim.

## Evidence: L7 a cross-workspace read is refused, and a missing target looks identical

The authority check lives in the tool **executor** (`packages/session-query/tool-session-query`'s `workspace-access.ts`), not in the query service, so a text-only mock cannot reach it. The mock scripts the CALL and the harness runs the tool for real, which is what makes this reachable with no credential:

```
[l7-auth] foreign session created: session-l7-foreign-workspace
[l7-auth] foreign workspace: /var/folders/…/dsh-l7-foreign-workspace
[l7-auth] caller workspace: <checkout>
[l7-auth] tool/result events: 1
[l7-auth] result 0: {…"text":"Error: session target is outside the caller workspace"…
                    "isError":true…"code":"SESSION_QUERY_TOOL_UNAUTHORIZED"}
[l7-auth] the turn ended: {"kind":"completed"}
```

The probe deliberately creates a session under a **different cwd**, so the foreign target exists and a refusal cannot be confounded with "not found". Then the same probe runs against a session id that does not exist at all, and the two refusals are compared after normalising volatile ids:

```
PASS  an existing foreign target and a nonexistent one are INDISTINGUISHABLE
```

Asserting only "both were refused" would have passed for two different messages, which is why the check compares the results rather than counting them.

**One probe bug worth recording.** The foreign session id is a constant, because the mock's tool arguments are fixed before the harness boots. The first version therefore failed on its second run with `session "session-l7-foreign-workspace" already exists`. A check that only passes on a fresh harness home is not a check; the probe now resumes the persisted session instead.

## Evidence: L7 which events the query layer can find, and why the old check was vacuous

A claim in this row was wrong, and the way it was wrong is the point. The phase asserted that the type filter answers by matching only the printed **label**:

```
check "the type filter answers" "filterEvents by type 'sandbox/mode':" "$probe_out"
```

The probe prints `<label>: N match(es)`, so `0 match(es)` satisfied it. Requiring a non-zero count exposed it, and the **source** explains it exactly:

- `extractSessionEventText` (`packages/session-query/session-query/src/extraction.ts`) returns text for **user and assistant messages, tool calls, tool results, todo writes, and turns that ended with a reason**. Everything else — including `sandbox/mode`, `permission/preset`, `request/header` — returns an empty string.
- `buildSessionEventSearchDocuments` **omits** every event whose text is empty ("structural events are omitted", `documents.ts`).

So a log-only **structural** event produces no searchable document, and no type filter, text filter or full-text search can find it — by design, not by fault. Measured on the phase's session, which has no messages:

```
[l7-probe] events the query layer can index (semantic-bearing): 0 of 5
[l7-probe] filterEvents by type 'sandbox/mode': 0 match(es) after 5000ms
[l7-probe] searchSessions: 0 hit(s)
[l7-probe] listSessions: 1269 total; mine found: true
[l7-probe] readSession: 5 event(s); marker present: true
```

`listSessions` (live-preferred) and `readSession` still see the session and its appended event; the query layer's *filters* do not, because there is nothing in it to index. The wait exists to rule out the innocent explanation, and it does: 30 seconds changes nothing, and neither does a fresh home holding a single session.

**The positive case is asserted where it belongs.** Phase 7 runs a real turn whose user message carries a unique marker, and asserts `searchSessions(<marker>): 1 hit(s)` with the hit being that session — so the working path is checked on a session that has semantic text, instead of the broken path being checked on one that does not.

**Consequences for the lesson, both now applied.** The step that told the reader a log-only event is "findable by a type filter" is wrong and is corrected: what matters is that **structural events are not retrievable at all**, so retrieval cannot be built on one. And the invented-type caveat is no longer claimed as a contrast the filters demonstrate — an unknown type is non-searchable for the same reason every structural event is; its real evidence remains ADR-0024's unreadable log.

## Evidence: L7 the turn COMPLETES, and an earlier check measured the wrong thing

The turn phase runs against the mock provider, and this is what it now reports about its **own** turn:

```
PASS  the turn produced its own assistant message
PASS  the turn completed rather than failed
PASS  the trajectory is searchable and the hit is this session
```

**An honest correction, twice over.** The first version of this phase asserted that the trajectory was searchable by "the assistant's own text", and it **passed — because the search found `mock response` in other sessions** left by earlier headless runs. The turn it was describing had no assistant message at all. That is the most dangerous kind of green check; the search now uses a marker unique to the run and asserts the hit is this session.

The second correction is what removed the missing assistant message. This file previously recorded the failure as an upstream bug in the harness's settings plugin — whose guard `'toJSON' in schema` is true for a Cordis Context proxy, whose `.toJSON` then throws the inject error — and noted that an audit of all 119 configuration entries found every `Config` valid. That audit was correct and the conclusion was wrong: the fault was never in the harness. It was this repository's own Lesson 5 listener stringifying a live event payload (ADR-0028). `solutions/l3.audit.patch.yml` is kept, reframed as what it actually shows: every entry's `Config` is a valid schema.

## Evidence: L7 a real turn, keyless, and the caveat

Against `dsh-llm-mock-server` (ADR-0027), so the loop, log and accounting are real while the model's output is scripted:

```
[l7-turn] tokenUsage: {"totals":{"uncachedInputTokens":0,…,},"last":null}
[l7-turn] sessionStats (web-only): not mounted in this profile
[l7-turn] searchSessions('mock response'): 13 hit(s)
[l7-turn] /compact outcome: {"kind":"success","text":"No compactable history yet."}
```

`13 hit(s)` is the claim that matters: the text the **assistant** produced is findable in the trajectory. The accounting projection is asserted for its shape **and its numbers**: the mock reports `input_tokens: 3` (a constant) and `output_tokens` equal to the character count of its scripted reply, so `uncachedInputTokens: 3` and `outputTokens: 23` are exact and checkable. An earlier version of this paragraph claimed the mock reported no usage for scripted text; that was simply wrong, and it held the check at shape-only for several rounds.

**The caveat is asserted with cleanup.** A second phase appends an invented event type and shows it is invisible to a type filter, a text filter, and full-text search — then removes the session it created, because an unreadable session breaks search for the whole home. That cleanup is not politeness: 37 such sessions had accumulated in the verification home during development, which is what made the search assertions fail with a confusing error.

`solutions/verify-l7.sh` runs all of it.

## Evidence: L7 composes and activates

Two defects were found by building this lesson, and both are now recorded.

**A row naming an uninstalled package fails to import.** Adding the tool row alone produced:

```
dsh: warning: 1 entry did not activate
tool-session-query (@deepseek-ai/dsh-tool-session-query): failed to import
```

A row name resolves through the profile's installation, so the package must be installed. This is [ADR-0003](https://github.com/kbaynes/dsh-exploration-kit/blob/main/decisions/0003-plugins-ship-as-a-bundle.md)'s mechanism applied to a package the kit does not own.

**An unpinned install resolves a stale version.** The obvious command — `dsh plugin --profile kitdemo add @deepseek-ai/dsh-tool-session-query` — was rejected:

```
Plugin @deepseek-ai/dsh-tool-session-query@0.0.1-rc.1 is incompatible with dsh 0.2.0-rc.2
```

The registry confirms why: `dist-tags.latest` is `0.0.1-rc.1` while versions run to `0.2.0-rc.2`. Installing the pinned version succeeded, and the subsequent boot had **zero activation warnings**:

```
$ node -e "...profile manifest..."
{ "@deepseek-ai/dsh-tool-session-query": "0.2.0-rc.2",
  "dsh-exploration-kit-plugins": "link:.../kit-plugins" }
```

Recorded as [ADR-0013](https://github.com/kbaynes/dsh-exploration-kit/blob/main/decisions/0013-pin-optional-package-versions.md).

**A third defect was in the kit's own tooling:** `solutions/verify-l7.sh` was written with `timeout`, which is GNU coreutils and absent on macOS — the command did not run at all, so the check silently passed on empty output. It now bounds the boot portably. Worth recording because a check that cannot run is worse than no check.

**Superseded.** Every query, the workspace-authority refusal, the token delta, `/compact` and the invariant sweep are executed — see the evidence sections below and `solutions/verify-l7.sh` phases 5–10.

**Two open items from the editorial review are now closed:**

1. **`@deepseek-ai/dsh-invariants` does resolve in a fresh profile**, even though it is not a dependency of the base bundle. Verified by applying the L7 overlay to a profile that had never installed it: the two invariants rows resolved and only the uninstalled query tool failed to import. The mechanism is that rows resolve against the running installation's package tree, which a source checkout provides. The lesson now states the resulting rule — a row naming a package your installation contains resolves; an optional package it does not must be installed.
2. **The session storage layout is not flat.** It is `$DSH_HOME/sessions/<workspace>/session-<uuid>/session.jsonl.zstd`: workspace-scoped, one *directory* per session, and zstd-compressed, with a write-open publishing version-named successors such as `session.v4.jsonl.zstd`. L6 told readers to "open the session file under `$DSH_HOME/sessions/`", which would have failed three ways. Both L6 and L7 now give the real path and note `zstd -dc` as the way to read it.

## Evidence: L6 executed — durable state across a restart

The lesson was rebuilt on `sandbox/mode`, a first-party log-only event that the harness itself folds in a `sandboxMode` projection unit. Both phases executed, no model involved:

```
PHASE ONE (write)          dsh --profile kitdemo --patch solutions/l6.probe.patch.yml
  [l6-probe] mode at creation: {"mode":"workspace-write"}
  [l6-probe] mode after switching the preset: {"mode":"danger-full-access"}

PHASE TWO (fresh process)  dsh --profile kitdemo --patch solutions/l6.resume.patch.yml
  [l6-probe] resuming session-l6-verify-… in a fresh process
  [l6-probe] RESUMED mode: {"mode":"danger-full-access"}
```

Phase two is the whole point: on load the session replayed its persisted log, the registry folded it, and the state was **reconstructed** rather than remembered. `solutions/verify-l6.sh` runs both phases, generates a fresh session id per run (sessions persist, so a fixed id fails the second run with `already exists`), and asserts that the persisted log stays readable — the check that fails if anyone reintroduces an invented event type.

The preset switch is a real service call, the same one the `/permission` control makes, so the probe needs no agent turn and no provider.

### The defect this replaced

## Evidence: L6's durability claim is false as written

**A two-boot experiment, executed:**

```
BOOT 1 (write)
  [l7-probe] created session-l7-durability with a distinctive marker
  [l7-probe] readSession: 5 event(s); marker present: true

BOOT 2 (fresh process)
  [l7-probe] RE-READ FAILED: failed to read stored session "session-l7-durability":
    session "session-l7-durability" contains event type "l6/step" (seq 4)
    unknown to this harness and not marked ignorable;
    refusing to interpret the log — it was likely written by a newer harness
```

The event is writable and foldable in the process that wrote it, so the lesson's earlier "the count comes back" claim looked true. After a restart the session is unopenable.

**It is contagious.** `searchSessions` observes whole sessions, so one such session breaks search for the corpus:

```
[l7-probe] searchSessions failed: session-search persistence observation failed:
  session "session-l6-probe-…" contains event type "l6/step" …
```

**Why:** `validateStoredEvents` rejects stored events outside the harness's known vocabulary unless the envelope carries `ignorable: true`; the persistence catalog states that external plugin types are outside its inventory; `KNOWN_SESSION_EVENT_TYPES` is a static generated set with no runtime registration; and `session.append()` cannot set `ignorable`.

**The lesson is corrected** — Step 4 now teaches this as the trap and gives the supported replacement, folding a known event type. This is the first finding that *invalidated* a lesson's central claim rather than refining it, and it is recorded as ADR-0024.

## Evidence: L6 executed (and two shipped bugs found)

**The full claim, executed without a model.** `ctx.agents.create()` makes a session and runs no turn, so the append path and the projection registry are reachable offline:

```
[l6-probe] projection before any event: {"total":0}
[l6-probe] after append count=1: {"total":1}
[l6-probe] after append count=9: {"total":9}
```

The third line is the lesson's subtle rule made observable: the event carries the **complete post-change state**, so the fold replaces rather than accumulates — `9`, not `1 + 9`. It also proves the event *committed*, since a projection only folds committed events.

**Two shipped bugs found by the same probe**, recorded as ADR-0022:

```
[l6-probe] FAILED: Invalid value used as weak map key
[l6-probe] stack:
    at WeakMap.set
    at kit-plugins/l6/counter.js:9:12
```

`agent/created` delivers `{ agent, source, signal }`, not the agent. Lesson 6's counter therefore crashed on the first real session; Lesson 5's inject plugin hit the same error, **caught it**, and logged `skipped` — so it did nothing at all while appearing to work. Both now destructure `{ agent }`, and the inject plugin's catch reports `FAILED` rather than a benign skip.

Both were invisible because an `agent/created` listener that never fires looks identical to one that works, and no boot before this created a session. `solutions/verify-l6.sh` now fails if any plugin throws on session creation.

## Evidence: L6 the projection loads, and the fold is unit-tested

The shipped default is the projection. The plugin-declared-event hazard is bundled but **disabled**, which is why the activation line below is the only one a normal boot prints:

```
[l6-projection] ACTIVE — registered the l6Steps unit
```

The projection's pure core was extracted into `l6/fold.js` precisely so its contracts are testable without a session. `pnpm run check:units` runs **five** tests over it, all passing:

1. `folds the known event type into the reported mode`
2. `the LATEST event wins, because the event carries complete state`
3. `folds a type the harness knows, not a plugin-declared one` — the assertion is that the folded type does not begin with `l6/`, which is ADR-0024 written as a test
4. `returns the SAME reference for unrelated events` — the contract that stops a projection recomputing on every committed event
5. `returns a NEW reference for a relevant event`

The fold's subject is `sandbox/mode`, a first-party log-only event. An earlier version of this section described four tests including an `l6/step` fold and a delta-shaped event; neither exists, because the invented type was removed along with the plugin that appended it (the hazard keeps the pattern, disabled, as a demonstration).

**A dependency was declared rather than inherited.** `zod` resolved transitively before this lesson, but a plugin importing it directly must declare it — ADR-0005's exception for a package whose *teaching is the point*. It is now in the bundle's `peerDependencies` and `devDependencies`.

## Evidence: L5 the model-visible skill catalogue, against a real turn

The catalogue only exists once a request is assembled, so this needs a provider — not a model. The mock endpoint runs the real loop and request assembly (ADR-0027), and the catalogue is durable, which is what makes it checkable: it lands in the session log as a user message. The claim is a PAIR, and the second half is what stops the first from being trivially satisfiable:

```
[l5-cat] event types: …,step/start,system/message,user/message,…,request/header,request/context,
         session/title,assistant/message,step/end,turn/end
[l5-cat] catalogue mentions 'repo-onboarding': true
[l5-cat] body loaded into the log: false
```

`true` is the catalogue reaching the model's context. `false` is the skill body **not** being shipped with it — the body loads only once the model chooses the skill, which is the lesson's actual point. `solutions/verify-l5.sh` phase 8 asserts all three lines, including that the turn completed.

**A silent no-op caught here.** The first version of that phase omitted `KIT_ROOT`, which the skills overlay reads at load time to compute `customSkillDirs`. An unset value resolves to `undefined`, the skill directory disappears, and the catalogue is empty — indistinguishable, in the assertion output, from the claim being false. The lesson's own environment variable was load-bearing for its verification.

## Evidence: L5 the model CALLS the skill, and only then does the body load

The catalogue phase proves the announcement with the body absent. This phase proves the other half — announce, choose, load — with the mock scripting the CALL (`tool_call_success` for the `skill` tool) while the harness executes the tool for real:

```
PASS  the catalogue is still announced
PASS  the call ran through the real tool pipeline
PASS  the skill BODY loads once the model calls it
```

The body marker that the catalogue phase asserts is **absent** is here **present**. That pair is the mechanism the lesson describes, and it needs a scripted tool call rather than a model: what is being verified is the harness's loading behaviour, not a model's judgement about when to read a skill.

## Evidence: L5 a skill added to a watched root reaches the catalog with no restart

The catalog is built from the provider's live view of the filesystem — `skill-filesystem` watches its roots, with a 200ms stability threshold. Two sessions in ONE process prove it:

```
[l5-live] before: catalogue mentions the original skill: true
[l5-live] before: catalogue mentions the new skill: false
[l5-live] wrote /tmp/l5-live-skills/live-added-skill/SKILL.md
[l5-live] after: catalogue mentions the original skill: true
[l5-live] after: catalogue mentions the new skill: true
[l5-live] after: the new skill's BODY is not shipped either: true
```

A second **session** rather than a second turn is deliberate: the catalog arrives as durable context, and re-announcing it mid-session is a different question from whether the provider's view of the filesystem is live. The last line checks that the new skill obeys the same body rule as the original.

The probe writes into a **temporary** root seeded from the kit's own skill, never into `<kit>/kit-plugins/l5/skills`. A verification that renames the repository's own files can leave it broken when the run is killed half-way.

## Evidence: L5 the command path, with no model request

Executed through `ctx.commands.execute` — the dispatch path the composer uses — against a session created by `ctx.agents.create`, which runs no turn:

```
[l5-cmd] resolved: true
[l5-cmd] outcome: {"kind":"success","text":"content/      the curriculum (OKF bundle) — start at content/index.md…"}
[l5-cmd] command events in the log: command/run, command/done
[l5-cmd] model-request events in the log: 0
```

The last line is the evidence for "needs no model turn": the session records the command's lifecycle and **zero** model-request events. `solutions/verify-l5.sh` asserts all four lines.

## Evidence: L5 injected context survives a restart

The lesson's durability claim, tested in **two processes** because one cannot distinguish the queue from the log — `agent/created` fires while the session is being built:

```
PHASE ONE  (create)   [l5-inject] context appended to the next admitted request
PHASE TWO  (fresh)    [l5-probe] re-read 5 event(s): permission/preset, sandbox/mode,
                                   approval/policy, agent/inbox/spliced, agent/inbox/spliced
                      [l5-probe] injected text present after restart: true
                      [l5-probe] carried by: agent/inbox/spliced
```

Two things the probe made explicit rather than assumed:

1. **The durable carrier is an inbox event, not a `user/message`.** `agent.inject()` queues into the agent's inbox; that queue is what persists.
2. **It is a first-party event type**, which is why the log stays readable after the restart. A plugin-declared carrier would have made the session unopenable (ADR-0024).

`solutions/verify-l5.sh` runs both phases and asserts the text survives, plus that the log is readable — the check that fails if a plugin invents an event type.

**Found earlier by the same probe:** the inject plugin was reading the `agent/created` payload as the agent, so it threw, caught the error, and logged `skipped` — doing nothing at all while appearing to work. Fixed under ADR-0022, and the catch now reports `FAILED`.

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

**A stale upstream example was corrected.** `docs/cookbook/adding-a-tool.md` shows `agent.inject({ content, source: { kind: 'plugin', plugin: '<name>' } })`. That is not a `UserMessage`: `inject()` requires one, and there is deliberately no catch-all `plugin` source kind — each producer declares its own. The kit's plugin uses `createUserMessage` with a declared kind, and `solutions/verify-l5.sh` asserts that the stale shape is absent.

**Superseded.** The pre-step payload shape, replay durability, the model-visible skill catalogue and `/l5-facts` are all executed — see the L5 sections below and `solutions/verify-l5.sh` phases 6–10. Each requires a session and therefore a provider.

## Evidence: L4 plugins load (decisions unverified)

Both policy plugins activate on the live composition:

```
[l4-write-scope] ACTIVE — writes confined to <kit>/l4-sandbox
[l4-guard] ACTIVE — monotonic guard registered
```

**A real failure was reproduced and fixed.** The first version of `l4-guard` touched `ctx.tools` without declaring the service, and the load failed loudly:

```
l4-guard (dsh-exploration-kit-plugins/l4/guard.js): Error: cannot get property "tools" without inject
```

The lesson now documents that `inject = ['tools']` is mandatory, because the service is not ambient.

**A design correction.** The original gate computed its confinement root from `process.cwd()`. The dsh process runs from the *checkout*, not the kit, so that would have defended the wrong tree. The root now comes from the plugin's own config, supplied by the bundle row with `!!js` at load time.

**Superseded:** the allow/deny outcomes are executed through the real tool pipeline by `solutions/l4.probe.patch.yml`. What remains unverified in this lesson is the `ask` path. Observing them requires a tool call, which requires a provider. The lesson separates what the boot proves from what only a call can prove, rather than presenting the former as the latter.

## Evidence: L3 the plugin_manager layer boundary

Lesson 3's last gap was its `plugin_manager` claim, and executing it corrected the claim:

```
[l3-probe] initial: 115 row(s) total; l3 rows:
[l3-probe] disabled l3-uses-clock: {"application":"failed","error":{"code":"unkno…
[l3-probe] bundles: 11 total; kit bundle present: true
[l3-probe] ids containing "l3-uses-clock": (none)
```

The manager lists the profile's rows and the kit's *bundle*, and cannot see or toggle the rows that bundle contributes. The lesson now teaches the distinction and uses the bundle patch for the reverse experiment. Recorded as ADR-0025 and asserted by `solutions/verify-l3.sh`.

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

Worth recording: with the filter removed, the same sweep also reported `AuthorizationService`, `PlatformAccount`, `llm-pi-ai`, and `TypertGatewayService` as PENDING **in a healthy profile**. None are broken. That is why the diagnose row is scoped by config — a diagnostic that cries wolf is worse than none.

**Hot reload**, editing `l3/uses-clock.js` while the process ran under the `hmr` overlay with `root` set to the kit's plugin directory:

```
[l3-uses-clock] 2026-10-01T12:21:49.606Z          <- before the edit
[l3-uses-clock-EDITED] 2026-10-01T12:22:07.232Z   <- after saving, no restart
```

### Two upstream-tutorial traps found by running it

1. **`FiberState` is a `const enum`.** TypeScript erases it and the published `@deepseek-ai/cordis` does not export it, so the upstream Cordis tutorial's `import { FiberState, type Context } from '@deepseek-ai/cordis'` fails at load. Verified: `node -e "import('@deepseek-ai/cordis').then(c => console.log(c.FiberState))"` prints `undefined`. The lesson compares the stable numeric states instead.
2. **`Config` must be a real Standard Schema.** A hand-rolled `{ parse }` object fails with `TypeError: Cannot read properties of undefined (reading 'validate')`. Schemastery works and is already a bundle dependency.

## Evidence: L2 executed, tool included

**The tool's behaviour, called through the real pipeline** (`kit-plugins/l2/tool-probe.js`, ADR-0021's technique):

```
[l2-probe] default-unit:   {"isError":false,"content":[{"type":"text","text":"2 lines"}],"value":{"unit":"lines","count":2}}
[l2-probe] explicit-words: {"isError":false,"content":[{"type":"text","text":"3 words"}],"value":{"unit":"words","count":3}}
[l2-probe] explicit-chars: {"isError":false,"content":[{"type":"text","text":"17 chars"}],"value":{"unit":"chars","count":17}}
[l2-probe] invalid-unit:   {"isError":true,"error":{"message":"invalid arguments: \"unit\" must be one of [\"words\",\"lines\",\"chars\"]"}}
```

This proves four things the lesson claims, in one run: the row's `config` reaches `apply`; an explicit argument overrides it; argument validation rejects a bad value *before* `execute` runs; and `value` (canonical JSON) and `content` (rendered prose) are genuinely separate channels — visible together in a single result rather than asserted.

`solutions/verify-l2.sh` asserts all four, plus the rendered-prose pairing.

**Narrowed, not eliminated:** whether a *model* chooses to call this tool, and whether it restates the value well, is a question about the model rather than the tool, and remains outside the kit's verification.

### Earlier evidence

## Evidence: L2 executed (except the model call)

All three behavioural claims were executed against the running harness.

**The plugin loads through the bundle**, proving its `@deepseek-ai/dsh-tools` and `@deepseek-ai/schemastery` imports resolve and its config reaches `apply`:

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

This corrected an earlier draft that paraphrased the error and omitted the `$` prefix Cordis supplies.

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

A defect was found and fixed during this verification: placing the patch file *inside* the plugin directory made `'./l2/wordcount.ts'` resolve to a nested `solutions/l2/l2/wordcount.ts`. The lesson now documents that trap explicitly.

**Deliberately not verified:** `--dump-config` composes config rows and does **not** run Schemastery validation, so the claim that an invalid `defaultUnit` is rejected at load remains unproven. It needs a harness boot with the plugin mounting.

## Evidence: L1 executed

The L1 mechanics were booted against the real harness before the lesson was written, which is how two footguns were found and fixed in the lesson text:

**Patch composition.** `dsh --profile web --patch <overlay> --dump-config` composed the overlay row correctly. Two failure modes were observed and are now documented in the lesson's troubleshooting table:

- A bare `- id: <new-id>` entry failed with `patch: entry "<new-id>" not found` — new rows require `- insert:`.
- A `name` written relative to the workspace root silently resolved to a doubled path (`exploration/plugins/exploration/plugins/l1/hello.ts`) — the specifier is relative to the **patch file**.

**Full lifecycle observed.** Booting `dsh --profile web --patch <overlay> --port 0 --no-open` produced, in order:

```
[l1-hello] apply() ran — plugin is ACTIVE
[l1-hello] effect registered
dsh web: http://127.0.0.1:<port>/?token=...
[l1-hello] disposer ran — plugin is DISPOSED   (on shutdown)
```

This confirms `LOADING → ACTIVE → UNLOADING → DISPOSED`, that effects unwind on unload, and that the disposer runs on graceful shutdown.

**Sandbox limitation.** The agent file sandbox blocked `dsh` from writing `~/.dsh/profiles/web/cordis.yml` (`EPERM: operation not permitted`). Every lesson therefore instructs readers to run boot commands in their own shell. This is an environment fact, not a DSH defect.

## CI workflows

| Workflow | Status |
|---|---|
| `site` (environment-free checks, Pages deploy) | Documented. Its checks all pass locally; the Actions orchestration is not exercised here. |
| `verify against dsh` (full per-lesson suite at the pinned commit) | **Steps verified locally; YAML validated, not executed.** The command sequence — install the CLI shim, provision the profiles, `check:target`, `check:kit` — was run locally with `dsh` resolved only from that shim, reporting `20 passed, 0 failed` (`16` when this row was written; the suite has grown since). The workflow files themselves are now parsed and structurally checked by `pnpm run check:configs` (triggers, jobs, `runs-on`, steps, and for this workflow that it uses the pinned commit and asserts it). GitHub Actions cannot be run from the authoring environment, so the orchestration is still unverified. |

### Configuration artifacts are now machine-checked

A malformed workflow **never runs, and Actions reports nothing** — the failure is silence, which is why it is worth a check rather than care. `pnpm run check:configs` parses every shipped machine-read config (both workflows, `kit.target.json`, `okf-base.yaml`, `package.json`, the bundle manifest) and asserts the fields each consumer actually reads.

Three failure modes were confirmed to fire, not assumed:

```
probe 1 (YAML syntax error)         -> parse error reported
probe 2 (step with neither uses nor run) -> job "build" step 4 has neither "uses" nor "run"
probe 3 (commitShort not a prefix of commit) -> kit.target.json: dsh.commitShort is not a prefix of dsh.commit
```

## Not verified at all

Everything below is genuinely open. An earlier version of this section also listed "model-call-dependent outcomes in L5, L7, L8 and L9" and "the plugins have not been mounted" — both were wrong: those outcomes are executed (keyless against the mock, or opt-in with a real provider), and every lesson plugin is mounted in the compositions the suite boots.

- Any **client/UI plugin authoring** (React conversation nodes) — out of scope of the curriculum.
- **A model CHOOSING to call a lesson's own tool.** The kit drives tool calls by scripting them, which is what makes them deterministic: L2's `word_count`, L5's `skill`, L7's session-query tools and L9's `bash` are all dispatched for real, but the *decision* is scripted. L8's agent-control phase is the exception — there a real model chooses `send_message` and `interrupt_agent` — and L4's `ask` path needs a real approval flow rather than a scripted decision.
- The L9 **Python SDK** snippet — a real upstream example that is documented here, not executed.
- The **magnitude** of L8's cost comparison. The attribution across agents is measured (26 tokens for one turn against 57 for a fan-out); a realistic *price* is a property of a provider's price list, not of the harness.

## Verification backlog

Ordered by value:

1. Run L2–L6 end-to-end against `0.2.0-rc.2` and promote each to **Executed**.
2. Replace the L9 Python placeholder with a tested snippet, or delete the step.
3. Add a `scripts/verify.sh` that boots each lesson overlay headlessly and asserts on `--json` output, so this file can be regenerated mechanically.
4. Re-run the whole curriculum on the next DSH release and record the version bump, including any import-path or command changes.
