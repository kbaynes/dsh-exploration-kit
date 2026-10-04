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
| L1 — Mount your first plugin | **Executed** | The lifecycle cycle is verified twice — via a patch overlay originally, and again after the bundle pivot, which is what the lesson now teaches. The deliberate `FAILED` throw and the `PENDING` inject are both executed, and their real output corrected two draft assumptions in the lesson text. Nothing in this lesson is unverified. See evidence below. |
| L2 — Register a tool, compose with config | **Executed** | The plugin loads through the installed bundle; the Schemastery schema rejects an invalid value; an overlay changes the installed row's config; and the **tool itself is called through the real pipeline** by a shipped probe — the configured default reaches it, an explicit unit overrides it, invalid arguments are rejected before `execute` runs, and `value`/`content` show the canonical/render split. Outside this lesson's scope: whether a model *chooses* to call it. See evidence below. |
| L3 — Services, isolation, and hot reload | **Executed** | The service is provided as `ctx.lessonClock` and consumed; disabling the provider strands the consumer and the scoped sweep names it `PENDING`; editing a plugin file reloads it live under the `hmr` overlay; the `plugin_manager` claim is executed and **corrected** (it manages the profile's rows and whole bundles, not rows a bundle contributes — ADR-0025); and **service isolation is executed** — two groups isolating one service name each see their own provider. Two upstream-tutorial traps found by running it. Nothing in this lesson is unverified. |
| L4 — Build a policy gate | **Executed** | Both plugins load, the missing-`inject` failure was reproduced, and the gate's **decisions** are exercised through the real tool pipeline by a shipped probe: an outside write is `GATE-DENIED` with the lesson's reason, and an inside write is *not* denied by the gate (a second policy layer stops it, since the target is outside the agent's workspace). Still unverified: `ask` decisions and guard undo-ability against a live competing listener. |
| L5 — Assemble context deliberately | **Mostly executed** | Executed: all three plugins activate; `agent.inject()` is built from `createUserMessage`; injected context is proved **durable across a restart** in two processes (carried by a first-party `agent/inbox/spliced` event); the skills overlay composes; and the **command path is executed** — `/l5-facts` dispatches through `ctx.commands.execute`, returns its text, logs `command/run` + `command/done`, and records **zero model-request events**. **Not** executed: the model-visible skill catalogue, which only exists once a request is assembled. |
| L6 — Give the session durable state | **Executed** | Rebuilt on the pattern that works, and proved across a **restart in two processes**, with no model: phase one derives the session's permission mode and changes it via a real preset switch (`workspace-write` → `danger-full-access`); phase two, a fresh process, resumes the session and reports `danger-full-access` reconstructed from the persisted log. The fold uses a first-party event type, and the check fails if any plugin invents one. The earlier defect is retained as a deliberate, disabled hazard. See evidence below. |
| L7 — Operate the harness | **Mostly executed** | Executed: the overlay composes and boots with no activation warnings; the pinned package installs; and the **query service itself** is exercised without a model — `listSessions` finds the created session, `readSession` returns its log, `filterEvents` matches by type, and all five lesson tools register in a live root Agent's scope (5/5). Two limits documented and asserted: an uninterpretable session breaks search corpus-wide, and an invented event type is invisible to filters. **Not** executed: the workspace-authority refusal, token deltas, `/compact`, and the invariant findings. |
| L8 — Orchestrate multiple agents | **Mostly executed** | Executed: the orchestration primitives are confirmed mounted by the base bundle (this lesson adds no plugin); the workflow's pure core passes 7 unit tests with a fake engine; and **fork heredity is verified without a model** — a child seeded from its parent's log reports the exact inherited prefix, the `isSeeded` marker, the parent lineage, and its L6 projection already reflects the inherited event. **Not** executed: any real delegation or fan-out (a subagent turn), and the monolith-versus-fan-out cost comparison. |
| L9 — Automate the harness | **Mostly executed** | Executed: `schedule` and `webhook` are confirmed opt-in; the overlay composes and activates on a web-backed profile with no warnings while a base-backed one strands both in `PENDING`; both install pinned; a scheduled task **survives a restart**; and the **headless contract is executed keyless** against the repository's scriptable mock provider — exit 0 with the answer on stdout, exit 1 with the diagnostic on stderr, and a `--json` stream carrying `turn_start`, `turn_end`, a `text` event and a closing `final`. **Not** executed: an SDK round trip, a webhook delivery, and a task firing. |

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

## Evidence: L9 the headless contract, keyless

The remaining "needs a model" claim turned out to need a *provider*, and the repository ships a
scriptable one (`dsh-llm-mock-server`). Against it, with no API key:

```
$ DEEPSEEK_BASE_URL=$MOCK/v1 DEEPSEEK_API_KEY=mock-key dsh --profile headless ... "say hi"
mock response recovered
EXIT=0

$ ... --json "say hi"            # stream types/phases observed
session, status(turn_start), status(step_start), text, status(step_end), status(turn_end), final

$ ... against a mock scripted to fail
EXIT=1        stderr: dsh: SERVER: mock script failed
```

`solutions/verify-l9.sh` starts one mock that always succeeds and one that always fails, and
asserts eight properties across them. Recorded as ADR-0027, including that the mock consumes one
scripted entry per *request* (so one behavior per instance is deterministic) and that `turn_end`
is a phase inside a `status` event rather than an event type.

## Evidence: L9 a scheduled task survives a restart

Executed in two processes, no model — creating a task is a service call:

```
PHASE ONE   [l9-probe] created task id=schedule-0a70ae86-… title="l9 schedule probe"
            [l9-probe] listed 1 task(s): l9 schedule probe

PHASE TWO   [l9-probe] after restart, tasks for the session: 1
            [l9-probe]   title="l9 schedule probe" id=schedule-0a70ae86-…
            [l9-probe] after deleting: 0 task(s)
```

The same task id in a process that never created it, so the task is Host storage rather than
process memory. `solutions/verify-l9.sh` runs both phases and asserts all three lines.
Delivery — a due task resuming the session and the agent working on it — still needs a
provider, and the lesson says so.

**Two gotchas found on the way.** The kit bundle had to be installed into the web profile as
well as the base one, because L9's probe lives in the bundle but must run where `schedule`
can activate (ADR-0016). And the **web profile does not surface a plugin's `console.log`** —
its boot prints only the URL — so a probe there must report through a file. Both are now in
the lesson and in `scripts/setup-verify-profiles.sh`.

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

## Evidence: L4's gate decisions executed

Lesson 4's central claim was recorded as needing a provider. It does not:
`ctx.tools.execute()` runs the same pipeline a model-direct call runs, so
`kit-plugins/l4/policy-probe.js` dispatches synthetic calls and classifies the denying
layer by its reason string.

```
[l4-probe] write-outside: GATE-DENIED  {"isError":true,"error":{"message":"writes are confined to <kit>/l4-sandbox"}}
[l4-probe] write-inside:  OTHER-DENIED {"isError":true,"error":{"message":"[sandbox: file access denied under workspace-write mode]"}}
```

Two things are proven at once: the gate **enforces** (outside is denied with its own
reason), and it **discriminates** (inside is not denied by it — a second, independent
policy layer stops it, because the target is outside the agent's workspace). Enforcement
alone would be satisfied by a gate that blocks everything.

Also recorded: two traps. dsh's filesystem tools take `file_path`, not `path`, and the
wrong key is rejected by argument validation *before* policy runs — easy to misread as the
gate working. And `ctx.tools.execute()` requires a `signal`.

`bash solutions/verify-l4.sh` asserts both verdicts.

## Evidence: L8 fork heredity, verified through derived state

Executed without a model — creating and seeding sessions is not a model call:

```
[l8-probe] parent log prefix: 5 event(s), seqs 0,1,2,3,4
[l8-probe] child inheritedEventCount: 5
[l8-probe] child header isSeeded: true
[l8-probe] child parentSession: session-l8-parent-…
[l8-probe] child projection: {"mode":"read-only"}
```

The last line is the substantive one: the child's **Lesson 6 projection already reflects the
mode carried by the inherited event**, so heredity is observed through derived state rather
than through a header field alone. A projection that inferred the cut instead of reading it
would misreport forks, and this is the check that would catch it.
`solutions/verify-l8.sh` asserts all four lines.

**Two API contracts found by probing, both now in the lesson:**

```
seed event at index 0 has seq 4 (expected 0); seed must be contiguous from 0
seeded session requires an inherited event count
```

The seed must be a **prefix** of the parent's log, and `inheritedEventCount` is **mandatory**
whenever `meta.isSeeded` is set.

**A near-miss worth recording:** a truncated `grep` made me believe
`inheritedEventCount` was not on `CreateAgentOptions`, and I was one edit away from
"fixing" a snippet that was correct. The rule added after round 13 — verify before you
edit — applies to reading code as much as to writing it.

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

**Two open items from the editorial review are now closed:**

1. **`@deepseek-ai/dsh-invariants` does resolve in a fresh profile**, even though it is
   not a dependency of the base bundle. Verified by applying the L7 overlay to a profile
   that had never installed it: the two invariants rows resolved and only the uninstalled
   query tool failed to import. The mechanism is that rows resolve against the running
   installation's package tree, which a source checkout provides. The lesson now states
   the resulting rule — a row naming a package your installation contains resolves; an
   optional package it does not must be installed.
2. **The session storage layout is not flat.** It is
   `$DSH_HOME/sessions/<workspace>/session-<uuid>/session.jsonl.zstd`: workspace-scoped,
   one *directory* per session, and zstd-compressed, with a write-open publishing
   version-named successors such as `session.v4.jsonl.zstd`. L6 told readers to "open the
   session file under `$DSH_HOME/sessions/`", which would have failed three ways. Both L6
   and L7 now give the real path and note `zstd -dc` as the way to read it.

## Evidence: L6 executed — durable state across a restart

The lesson was rebuilt on `sandbox/mode`, a first-party log-only event that the harness
itself folds in a `sandboxMode` projection unit. Both phases executed, no model involved:

```
PHASE ONE (write)          dsh --profile kitdemo --patch solutions/l6.probe.patch.yml
  [l6-probe] mode at creation: {"mode":"workspace-write"}
  [l6-probe] mode after switching the preset: {"mode":"danger-full-access"}

PHASE TWO (fresh process)  dsh --profile kitdemo --patch solutions/l6.resume.patch.yml
  [l6-probe] resuming session-l6-verify-… in a fresh process
  [l6-probe] RESUMED mode: {"mode":"danger-full-access"}
```

Phase two is the whole point: on load the session replayed its persisted log, the registry
folded it, and the state was **reconstructed** rather than remembered. `solutions/verify-l6.sh`
runs both phases, generates a fresh session id per run (sessions persist, so a fixed id
fails the second run with `already exists`), and asserts that the persisted log stays
readable — the check that fails if anyone reintroduces an invented event type.

The preset switch is a real service call, the same one the `/permission` control makes, so
the probe needs no agent turn and no provider.

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

The event is writable and foldable in the process that wrote it, so the lesson's earlier
"the count comes back" claim looked true. After a restart the session is unopenable.

**It is contagious.** `searchSessions` observes whole sessions, so one such session breaks
search for the corpus:

```
[l7-probe] searchSessions failed: session-search persistence observation failed:
  session "session-l6-probe-…" contains event type "l6/step" …
```

**Why:** `validateStoredEvents` rejects stored events outside the harness's known
vocabulary unless the envelope carries `ignorable: true`; the persistence catalog states
that external plugin types are outside its inventory; `KNOWN_SESSION_EVENT_TYPES` is a
static generated set with no runtime registration; and `session.append()` cannot set
`ignorable`.

**The lesson is corrected** — Step 4 now teaches this as the trap and gives the supported
replacement, folding a known event type. This is the first finding that *invalidated* a
lesson's central claim rather than refining it, and it is recorded as ADR-0024.

## Evidence: L6 executed (and two shipped bugs found)

**The full claim, executed without a model.** `ctx.agents.create()` makes a session and
runs no turn, so the append path and the projection registry are reachable offline:

```
[l6-probe] projection before any event: {"total":0}
[l6-probe] after append count=1: {"total":1}
[l6-probe] after append count=9: {"total":9}
```

The third line is the lesson's subtle rule made observable: the event carries the
**complete post-change state**, so the fold replaces rather than accumulates — `9`, not
`1 + 9`. It also proves the event *committed*, since a projection only folds committed
events.

**Two shipped bugs found by the same probe**, recorded as ADR-0022:

```
[l6-probe] FAILED: Invalid value used as weak map key
[l6-probe] stack:
    at WeakMap.set
    at kit-plugins/l6/counter.js:9:12
```

`agent/created` delivers `{ agent, source, signal }`, not the agent. Lesson 6's counter
therefore crashed on the first real session; Lesson 5's inject plugin hit the same error,
**caught it**, and logged `skipped` — so it did nothing at all while appearing to work.
Both now destructure `{ agent }`, and the inject plugin's catch reports `FAILED` rather
than a benign skip.

Both were invisible because an `agent/created` listener that never fires looks identical
to one that works, and no boot before this created a session. `solutions/verify-l6.sh`
now fails if any plugin throws on session creation.

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

## Evidence: L5 the command path, with no model request

Executed through `ctx.commands.execute` — the dispatch path the composer uses — against a
session created by `ctx.agents.create`, which runs no turn:

```
[l5-cmd] resolved: true
[l5-cmd] outcome: {"kind":"success","text":"content/      the curriculum (OKF bundle) — start at content/index.md…"}
[l5-cmd] command events in the log: command/run, command/done
[l5-cmd] model-request events in the log: 0
```

The last line is the evidence for "needs no model turn": the session records the command's
lifecycle and **zero** model-request events. `solutions/verify-l5.sh` asserts all four lines.

## Evidence: L5 injected context survives a restart

The lesson's durability claim, tested in **two processes** because one cannot distinguish the
queue from the log — `agent/created` fires while the session is being built:

```
PHASE ONE  (create)   [l5-inject] context appended to the next admitted request
PHASE TWO  (fresh)    [l5-probe] re-read 5 event(s): permission/preset, sandbox/mode,
                                   approval/policy, agent/inbox/spliced, agent/inbox/spliced
                      [l5-probe] injected text present after restart: true
                      [l5-probe] carried by: agent/inbox/spliced
```

Two things the probe made explicit rather than assumed:

1. **The durable carrier is an inbox event, not a `user/message`.** `agent.inject()` queues
   into the agent's inbox; that queue is what persists.
2. **It is a first-party event type**, which is why the log stays readable after the restart.
   A plugin-declared carrier would have made the session unopenable (ADR-0024).

`solutions/verify-l5.sh` runs both phases and asserts the text survives, plus that the log
is readable — the check that fails if a plugin invents an event type.

**Found earlier by the same probe:** the inject plugin was reading the `agent/created`
payload as the agent, so it threw, caught the error, and logged `skipped` — doing nothing at
all while appearing to work. Fixed under ADR-0022, and the catch now reports `FAILED`.

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

## Evidence: L3 the plugin_manager layer boundary

Lesson 3's last gap was its `plugin_manager` claim, and executing it corrected the claim:

```
[l3-probe] initial: 115 row(s) total; l3 rows:
[l3-probe] disabled l3-uses-clock: {"application":"failed","error":{"code":"unkno…
[l3-probe] bundles: 11 total; kit bundle present: true
[l3-probe] ids containing "l3-uses-clock": (none)
```

The manager lists the profile's rows and the kit's *bundle*, and cannot see or toggle the
rows that bundle contributes. The lesson now teaches the distinction and uses the bundle patch
for the reverse experiment. Recorded as ADR-0025 and asserted by `solutions/verify-l3.sh`.

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

## Evidence: L2 executed, tool included

**The tool's behaviour, called through the real pipeline** (`kit-plugins/l2/tool-probe.js`,
ADR-0021's technique):

```
[l2-probe] default-unit:   {"isError":false,"content":[{"type":"text","text":"2 lines"}],"value":{"unit":"lines","count":2}}
[l2-probe] explicit-words: {"isError":false,"content":[{"type":"text","text":"3 words"}],"value":{"unit":"words","count":3}}
[l2-probe] explicit-chars: {"isError":false,"content":[{"type":"text","text":"17 chars"}],"value":{"unit":"chars","count":17}}
[l2-probe] invalid-unit:   {"isError":true,"error":{"message":"invalid arguments: \"unit\" must be one of [\"words\",\"lines\",\"chars\"]"}}
```

This proves four things the lesson claims, in one run: the row's `config` reaches
`apply`; an explicit argument overrides it; argument validation rejects a bad value
*before* `execute` runs; and `value` (canonical JSON) and `content` (rendered prose) are
genuinely separate channels — visible together in a single result rather than asserted.

`solutions/verify-l2.sh` asserts all four, plus the rendered-prose pairing.

**Narrowed, not eliminated:** whether a *model* chooses to call this tool, and whether it
restates the value well, is a question about the model rather than the tool, and remains
outside the kit's verification.

### Earlier evidence

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

## CI workflows

| Workflow | Status |
|---|---|
| `site` (environment-free checks, Pages deploy) | Documented. Its checks all pass locally; the Actions orchestration is not exercised here. |
| `verify against dsh` (full per-lesson suite at the pinned commit) | **Steps verified locally; YAML validated, not executed.** The command sequence — install the CLI shim, provision the profiles, `check:target`, `check:kit` — was run locally with `dsh` resolved only from that shim, reporting `16 passed, 0 failed`. The workflow files themselves are now parsed and structurally checked by `pnpm run check:configs` (triggers, jobs, `runs-on`, steps, and for this workflow that it uses the pinned commit and asserts it). GitHub Actions cannot be run from the authoring environment, so the orchestration is still unverified. |

### Configuration artifacts are now machine-checked

A malformed workflow **never runs, and Actions reports nothing** — the failure is silence,
which is why it is worth a check rather than care. `pnpm run check:configs` parses every
shipped machine-read config (both workflows, `kit.target.json`, `okf-base.yaml`,
`package.json`, the bundle manifest) and asserts the fields each consumer actually reads.

Three failure modes were confirmed to fire, not assumed:

```
probe 1 (YAML syntax error)         -> parse error reported
probe 2 (step with neither uses nor run) -> job "build" step 4 has neither "uses" nor "run"
probe 3 (commitShort not a prefix of commit) -> kit.target.json: dsh.commitShort is not a prefix of dsh.commit
```

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
