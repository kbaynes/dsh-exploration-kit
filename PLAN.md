# Implementation Plan

The working plan for taking the DSH Exploration Kit from scaffold to published curriculum. Detailed and checkbox-driven: tick items as they are completed, and keep [ROADMAP.md](ROADMAP.md) in sync as the fast status view.

## Guiding rules

These constrain every task below. They are the reason the plan is shaped this way.

1. **Verified means run.** A lesson step is verified only when it was executed against a real DSH checkout and the observed result recorded in [VERIFIED.md](VERIFIED.md). Design is not implementation; documentation is not verification.
2. **One lesson, one seam.** Each lesson introduces exactly one new extension point, so a failure is attributable.
3. **Ship the working artifact.** Every lesson's exercise exists in `solutions/` (answer key) and `examples/` (exactly as presented). Building the reference solution *is* the test.
4. **Nothing unpublishable ships in `content/`.** Labs, drafts, and dead ends stay out of the bundle, because that is what the site renders.
5. **Version honesty.** Every claim carries the DSH version it was verified against. When upstream changes, the ledger changes with it.
6. **Prerequisites are explicit.** A reader on a clean checkout must not have to guess what a lesson assumes.

## Status legend

`[ ]` not started · `[~]` in progress · `[x]` done · `[-]` decided against (with the reason recorded inline)

---

## Phase 0 — Groundwork

Get the repo consistent and its checks trustworthy before writing nine lessons against it.

- [x] Create the repo scaffold, VitePress site, and OKF bundle (`bc3c233`)
- [x] Establish `VERIFIED.md` as the verification ledger, with only L1 `Executed`
- [x] Add `scripts/check-links.mjs` and wire `pnpm run check:links`
- [x] Add the GitHub Pages workflow
- [x] Add `repository`, `homepage`, and `bugs` fields to `package.json`
- [x] Add issue templates (lesson defect, clarity feedback, template chooser) and a PR template
- [x] Document the one-time Pages enablement step and deploy topology in `README.md`
- [x] Pin the toolchain in `engines`: verified on Node 22.23.1 with pnpm 11.7.0; requires Node >=20, pnpm >=10
- [x] Verify `pnpm install --frozen-lockfile && pnpm run build` succeeds from a clean
      export of the committed tree (no inherited `node_modules`); links and OKF
      validation pass there too
- [ ] Decide and record the versioning/compatibility policy (see Phase 4.5)
- [ ] Confirm `content/log.md` is the right home for curriculum history, or move
      development history to `CHANGELOG.md` and keep `log.md` OKF-only
      *(tracked as an open decision below)*

## Phase 0.5 — Rewrite the lessons for the bundle mechanism

**Blocking all lesson work.** A verified design finding invalidated the mechanism the lessons teach: a plugin that imports anything from dsh **cannot** be loaded by pointing a `--patch` overlay at a loose file, because pnpm symlinks only declared dependencies and `@deepseek-ai/*` is unreachable from outside a dsh installation. Full evidence is in [VERIFIED.md](VERIFIED.md) ("Design pivot").

The fix is verified and in place: `kit-plugins/` is a real dsh bundle, installed with `dsh plugin --profile <name> add link:<kit>/kit-plugins`, with rows referenced by package name. Lesson 2's plugin loads and mounts its tool through it.

- [x] Reproduce and confirm the failure mode (outside and inside the checkout)
- [x] Build `kit-plugins/` as a bundle and verify the plugin loads
- [x] Pin `@deepseek-ai/*` to the release under test in the bundle manifest
- [x] Rewrite **Lesson 1** for the bundle: install step, plugin-row explanation,
      the loose-file trap, and the observed `FAILED`/`PENDING` output
- [x] Verify L1's rewritten `FAILED` and `PENDING` experiments — the observed output
      corrected two assumptions in the draft (the boot warns and continues rather
      than exiting; `PENDING` does name the missing service at startup)
- [x] Rewrite **Lesson 2** for the bundle, re-expressing last-write-wins as
      overriding an *installed* row's config, with the observed validation error
      quoted verbatim
- [x] Establish `link:` (not `file:`) as the documented install, verified: `file:`
      copies so edits do not propagate, which defeats every "edit and observe" step
- [x] Rewrite steps 2–4 of **every remaining lesson** before building it (L1–L9 done)
- [x] Rewrite **Lesson 3** for the bundle, and correct two upstream-tutorial traps
      found by running it (`FiberState` const enum, non-schema `Config`)
- [ ] Replace the `<kit>/plugins/*.patch.yml` convention with a documented
      "install the bundle, then patch config" workflow
- [ ] Update `plugins/README.md`, `examples/README.md`, `solutions/README.md`, and
      the README's repository-layout section to describe `kit-plugins/`
- [ ] Move Lesson 2's solution into `kit-plugins/l2/` and retire
      `solutions/l2/` + `solutions/*.patch.yml` (they encode the broken approach)
- [ ] Update `solutions/verify-l2.sh` to assert against the installed bundle
- [ ] Add a `kit-plugins` version-bump step to the per-release verification process
- [ ] Decide whether the bundle ships as a published npm package or stays
      `file:`-installed; record the decision below

## Phase 1 — Build, test, and review each lesson

The substance of the project. Repeat this block for each lesson. **Order is independence, not number: do lessons 1, 2, 3, 6, 4, 5, 7, 8, 9.** Lessons 1–3 and 6 need no model API key and can be finished first; 4 is testable with a provider or via PTC; 5 and 7–9 need a configured provider.

### Lesson 1 — Mount your first plugin

- [x] Implement the exercise plugin and patch overlay
- [x] Execute end-to-end and record the observed boot/shutdown cycle
- [ ] Add the exact files to `examples/l1/`
- [ ] Add the complete answer key to `solutions/l1/` with a README recording what
      was run and the DSH version
- [ ] Review the explanation for clarity and fix anything unclear
- [ ] Promote the lesson's `VERIFIED.md` row to **Executed** with evidence

### Lesson 2 — Register a tool, compose with config

- [x] Implement the `word_count` tool plus Schemastery config in `solutions/l2/`
- [x] Confirm the overlay composes and the module resolves to the right file
      (`solutions/verify-l2.sh`, executed)
- [x] Confirm two stacked `--patch` flags give last-write-wins on the config row
- [x] Fix the `output.schema` blocker: it used raw JSON Schema, but `defineTool`
      takes the value-schema DSL (`additionalProperties: false`, per-property
      `required: true`)
- [x] Confirm the tool registers at load and its schema reaches prompt assembly
      (executed: the plugin logs ACTIVE through the installed bundle)
- [x] Execute a tool call and confirm the canonical value and render path — **no provider
      needed**: a probe calls `word_count` through `ctx.tools.execute()` and the result shows
      `value` (canonical) and `content` (rendered) side by side.
- [x] Confirm an invalid enum stops the load with a field-naming error (executed;
      `--dump-config` cannot show this because it does not run validation)
- [ ] Confirm `!!js` interpolates in `config` and `disabled`
- [ ] Add the exact files to `examples/l2/`
- [ ] Review the explanation for clarity
- [x] Update the `VERIFIED.md` row to *Mostly executed* with evidence
- [x] Confirm the plugin mounts through the installed bundle (executed)

### Lesson 3 — Services, isolation, and hot reload

- [ ] Implement `clock.ts` service + declaration merge in `solutions/l3/`
- [ ] Implement the consumer and confirm it activates when the provider is present
- [ ] Confirm removing the provider strands the consumer in `PENDING` silently
- [ ] Implement `diagnose.ts` and confirm it names the stranded plugin
- [ ] Enable HMR (`root`) via the `hmr` row and confirm a live reload on save
- [ ] Confirm the inventory/`plugin_manager` listing shows the entry states
- [ ] Add the exact files to `examples/l3/`
- [ ] Review the explanation for clarity
- [ ] Update the `VERIFIED.md` row

### Lesson 4 — Build a policy gate

- [ ] Implement the `write-scope` waterfall gate in `solutions/l4/`
- [ ] Implement the monotonic `ctx.tools.guard()` example and confirm it cannot be
      undone by another listener
- [ ] Confirm the pipeline-stage table matches the real order
- [x] Decided and implemented: the lesson needs **no** provider. A probe dispatches
      synthetic calls through `ctx.tools.execute()` and classifies the denying layer, so the
      gate's decisions are asserted by `verify-l4.sh` (see ADR-0021).
- [ ] Add the exact files to `examples/l4/`
- [ ] Review the explanation for clarity
- [ ] Update the `VERIFIED.md` row

### Lesson 5 — Assemble context deliberately

- [x] Implement the turn observer and confirm the real `agent/pre-step` payload shape — it is
      `{ agent, messages, turn, step, signal }`, and the shape is now observed from a real turn:
      the observer logs `pre-step turn=1 step=1 messages=2`. The lesson was corrected to match,
      which is the change that exposed the bug in
      [ADR-0028](decisions/0028-never-stringify-a-live-event-payload.md).
- [ ] Implement the `agent.inject()` example and confirm the injected text appears
      in the replayed session after a restart
- [x] Create the skill bundle and confirm it appears in the catalog — asserted against
      the mock provider by `solutions/verify-l5.sh` phase 8: the session log carries the
      skill's name (`catalogue mentions 'repo-onboarding': true`) while the body stays out
      (`body loaded into the log: false`). The PAIR is the claim: announced on demand,
      loaded on demand.
- [x] Confirm the model CALLING the skill loads the body — `solutions/verify-l5.sh` phase 9:
      with the mock scripting a `skill` call, the body marker that phase 8 asserts is ABSENT is
      present, and the call ran through the real tool pipeline.
- [x] Confirm an add reaches the catalog without a restart — `solutions/verify-l5.sh` phase 10:
      the probe writes a new skill into a WATCHED root and runs a second session in the same
      process, which then announces both skills. It writes into a temporary root, never the kit's
      own skills directory, so a killed run cannot damage the repository.
- [ ] Confirm `includeDefaultRoots: false` + `customSkillDirs` resolves as stated
- [ ] Implement the command plugin and confirm `/l5-facts` runs with no model turn
- [ ] Add the exact files to `examples/l5/`
- [ ] Review the explanation for clarity
- [ ] Update the `VERIFIED.md` row

### Lesson 6 — Give the session durable state

- [ ] Implement the `SessionEventMap` merge in `solutions/l6/`
- [ ] Confirm `session.append` accepts the log-only event and rejects a missing
      `surfaceOp` on a surface event (let the compiler prove it)
- [ ] Implement the projection unit and confirm the fold produces the right state
- [ ] Confirm the events are visible in the session JSONL on disk
- [ ] Confirm a full restart reproduces the projection state
- [ ] Confirm the delta-carrying counter event demonstrably breaks replay
- [ ] Confirm projection removal drops the key and its cells
- [ ] Add the exact files to `examples/l6/`
- [ ] Review the explanation for clarity
- [ ] Update the `VERIFIED.md` row

### Lesson 7 — Operate the harness

- [ ] Confirm `session-query-sqlite` `openAt` values and the working config
- [ ] Enable `tool-session-query` and confirm the five tools appear
- [x] Confirm cross-workspace access fails closed with the stated error code — `solutions/verify-l7.sh`
      phase 8 drives a REAL `session_trace` call into a session under a different `cwd` (the mock
      scripts the call; the harness runs the tool), and asserts `SESSION_QUERY_TOOL_UNAUTHORIZED`
      with `isError: true`. It also compares that refusal with the one for a nonexistent id after
      normalising volatile ids: **indistinguishable**, so the target's existence does not leak.
- [x] Measure the token delta caused by mounting `tool-session-query` — **done with a real provider**: mounting the tool costs **1,664 input tokens** (14,544 vs 12,880) for the same prompt and model, with one row toggled and both runs held to a single step. The mock could never show it (a constant `input_tokens: 3`); the phase is opt-in via `DSH_REAL_PROVIDER_PATCH`. Original note, kept for the reason: **blocked by the mock, not by the harness**: the delta is an *input*-token effect, and the mock reports a constant `input_tokens: 3` whatever the request contains, so no delta is observable. Needs a provider that counts the real prompt.
- [x] Confirm `/compact` produces a measurable reduction — `solutions/verify-l7.sh` phase 7 asserts the command reports `Compacted 4 history items (~4742 tokens)` after a turn. The mock's usage is real (`input_tokens: 3`, `output_tokens` = the scripted reply's character count), so the accounting is asserted with exact numbers rather than shape alone; an earlier round asserted only the shape on the false premise that the mock reported no usage.
- [x] Confirm `session_event_read` returns an event as JSON with neighbours —
      `solutions/verify-l7.sh` phase 9: a scripted `session_event_read` call (the tool's
      `session_id` is optional, so it targets the caller's own session) returns the target event as
      a JSON block plus `Before:`/`After:` summaries. A dedicated probe prints results in FULL,
      because the first attempt reused a probe that truncated them to 700 characters — cutting off
      exactly the neighbour lists the claim is about.
- [ ] Confirm the telemetry env vars behave as documented and that config alone
      cannot disable the row
- [x] Run the invariants check against a composition including kit plugins — no violation
      reported; `solutions/verify-l7.sh` asserts it.
- [x] Run a real turn and confirm it COMPLETES — this was blocked for two rounds by a bug in
      the kit's own L5 pre-step listener, misrecorded as an upstream defect
      ([ADR-0028](decisions/0028-never-stringify-a-live-event-payload.md)). The turn now
      records its own assistant message, ends `{"kind":"completed"}`, and is searchable back
      to its own session by a marker unique to the run.
- [ ] Produce a worked cost/trajectory example and decide whether it belongs in
      the lesson
- [ ] Add the exact files to `examples/l7/`
- [ ] Review the explanation for clarity
- [ ] Update the `VERIFIED.md` row

### Lesson 8 — Orchestrate multiple agents

- [x] Run a spawned child and confirm it lacks parent context — with a real provider: a passphrase is planted in the parent, absent from the child's session log, and the child answers `NOT-TOLD` (`solutions/verify-l8.sh` phase 7, opt-in).
- [ ] Run a forked child and confirm it inherits the cut
- [ ] Execute the workflow script and confirm a dense, schema-validated array
- [ ] Confirm a failing stage drops that item to `null`
- [ ] Confirm a misused hook ends the script with a naming error
- [x] Capture the monolithic-vs-fan-out comparison with real token numbers — `solutions/verify-l8.sh` phase 6 measures **26 tokens for one turn and 57 for the same task as a fan-out** (parent 31 + child 26), summing the parent from the headless `--json` stream and the child from its **own** session log, with each half asserted non-zero. Publishing the *magnitude* stays open: the mock's input is a constant 3 and its output is a scripted reply's character count, so the totals prove attribution across agents, not a realistic price.
- [x] **Investigate the intermittent child turn** — solved, and it was not a harness fault. The base bundle's `subagent` uses the `continuable` background mode, so `run_in_background` defaults to **true**: the parent gets a handle back, the child is scheduled independently, and a one-shot headless task exits while the child is still working, leaving its session open with no `assistant/message` and no `turn/end` (5 of 10 observed runs). Passing `run_in_background: false` closes it every time (3/3, and the phase now asserts the child's turn closed rather than counting model requests). The lesson teaches the argument and the symptom.
- [x] Confirm `send_message` reaches a live child and `interrupt_agent` stops it — with a real provider: the model calls all four tools, the marker arrives in the child's log, and the child's turn closes as an abort (`solutions/verify-l8.sh` phase 8, opt-in).
- [ ] Confirm `ctx.agents.create({ seed, meta })` fork behaves as described
- [ ] Read the agent-team profile patch and decide whether L8's optional step
      should stay
- [ ] Add the exact files to `examples/l8/`
- [ ] Review the explanation for clarity
- [ ] Update the `VERIFIED.md` row

### Lesson 9 — Automate the harness

- [ ] Confirm the headless exit codes for success and failure
- [x] Confirm `--json` emits assertable tool-call events — `solutions/verify-l9.sh` phase 9
      asserts a `tool_call` naming the tool with its parsed input, and a `tool_result` sharing one
      `callId`. The result's *status* is not asserted: whether a tool can run is host-dependent
      (this machine has no usable sandbox backend), so the check asserts the stream contract.
- [ ] Confirm `--session-id` adopts an exact session and fails on unknown ids
- [x] Run the TypeScript SDK sample with a `patches` file loading a kit tool — `solutions/verify-l9.sh` phase 7: the SDK composes `sdk-minimal` from `solutions/l2.override.patch.yml`, the mock scripts a `word_count` call that omits `unit`, and the result reads `11681 chars`. The patched unit proves the patches file was loaded; the count, computed from the file by the check, proves the tool read it. The profile needs the bundle in the SDK's OWN home (`dsh` spawns with its own `DSH_HOME`), so the phase installs it there and `scripts/setup-verify-profiles.sh` does the same for the shared home.
- [ ] **Replace or delete the Python placeholder snippet** — currently
      non-runnable; either test a real call or cut the step
- [x] Confirm a schedule fires once and appears in `schedule_list` — `solutions/verify-l9.sh`
      phase 5 lists it, phase 8 confirms one delivery receipt for one firing.
- [x] Confirm a scheduled task fires and **completes its work** — `solutions/verify-l9.sh`
      phase 8: a due task records a delivery receipt, resumes the session, and the delivered
      turn ends `{"kind":"completed"}` with a second assistant message. Delivery restores the
      model from the session's logged request header, so the probe talks to the model once
      before scheduling.
- [x] Confirm a webhook rule creates exactly one Session per delivery and record the duplicate-delivery behavior — `solutions/verify-l9.sh` phase 10, and it needed **no credential**: the GitHub adapter's `secretEnv` is a credential *reference*, and credential resolution reads the process environment first, so the check supplies its own secret and signs its own payload. Asserted: a signed delivery is accepted (202) and creates exactly one Session; an unsigned request is refused as malformed (400) and a wrongly signed one as unauthenticated (401); and a **repeated delivery id runs the rule again** (2 Sessions), which is documented behavior rather than a bug, since `deliveryId` is never used for built-in deduplication. The phase picks a free port at run time and reaps on any exit, because a stray harness from an aborted run answers the next run's requests.
- [ ] Confirm the hook adapters' described role
- [ ] Add the exact files to `examples/l9/`
- [ ] Review the explanation for clarity
- [ ] Update the `VERIFIED.md` row

## Phase 2 — Test infrastructure

Turn the verified lessons into something CI can defend.

- [ ] Write `scripts/verify.sh` (or `scripts/verify.mjs`) that, per lesson, boots
      the overlay headlessly and asserts on `--json` output
- [x] Add a DSH version gate: `kit.target.json` is the single source of truth and
      `scripts/check-target.mjs` holds every other record of the harness state to it,
      including the live checkout's commit, tag, cleanliness, and the profiles' pins.
      Proven by injecting a drift and confirming it named the disagreeing file.
- [ ] Split the suite into **no-key** and **needs-provider** groups so CI can run
      the first without secrets
- [x] Add a CI workflow for the kit's own checks (links, OKF, build) — `site.yml`, on
      every push and pull request
- [x] Validate the machine-read configs themselves — a malformed workflow never runs and
      reports nothing, so `pnpm run check:configs` parses and structurally checks them.
      Three failure modes confirmed to fire.
- [x] Add a workflow for the **full** suite including per-lesson checks, cloning the
      harness at the pinned commit: `verify-against-dsh.yml`, weekly and on demand. Its
      command sequence is verified locally; the Actions YAML is not (recorded in
      `VERIFIED.md`). See [ADR-0020](decisions/0020-verify-against-the-pinned-commit.md).
- [x] **Decided against regenerating `VERIFIED.md`**: its rows carry human judgement about
      what was executed, which is not derivable from a version string. The harness-state
      *identifiers* are gated instead (see ADR-0017), which is the part that can drift mechanically.
- [x] Decided: the scheduled full-verification workflow **fails** on upstream drift, and the response is to re-verify and either fix the lesson or demote its `VERIFIED.md` row.

## Phase 3 — Whole-kit review

- [ ] Complete the technical accuracy pass across all nine lessons (from the
      lesson audit findings)
- [ ] Complete the editorial clarity pass: consistent lesson shape, terminology,
      voice, and difficulty ramp
- [ ] Verify every upstream link resolves (repo paths in the DSH checkout)
- [x] Confirmed the `feature-map.md` rows agree with the lessons — an independent audit found
      **15 pointers naming a lesson with no such content** and three capabilities missing
      entirely. All cleared or corrected, the three capabilities added, and the Lesson column
      now has a legend saying an em dash means "ships, but no lesson here covers it".
- [x] Confirmed the `learning-path.md` dependency graph — it was **missing the L7→L8 edge**,
      drawing L8 off L4/L6 against L8's own prerequisites. Graph and prose corrected.
- [ ] Check the "what this path does not cover" list is still accurate
- [ ] Have at least one other person run Lesson 1 cold on a clean machine and
      report friction points
- [ ] Have a second person run one provider-dependent lesson cold
- [ ] Add a "fast path" ramp (e.g. a 30-minute subset) and evaluate whether it
      helps completion
- [ ] Re-read [VERIFIED.md](VERIFIED.md) end to end and correct every overstatement

## Blocking defect — L6 must stop inventing an event type

Found in this round by a two-boot experiment (ADR-0024): a plugin-declared `SessionEventMap` type is writable and foldable, and makes the session **unopenable after a restart**. The lesson text is already corrected; the shipped code is not.

- [x] Rebuilt `l6/fold.js` to fold a **known** event type — `sandbox/mode`, which the
      harness itself folds in a `sandboxMode` unit — replacing the invented `l6/step`.
- [x] `l6/projection-probe.js` now runs in two phases, and `solutions/verify-l6.sh` asserts
      the **restart**, which is the claim that was wrong and therefore the one the check
      covers. It also asserts the log stays readable, so the hazard cannot return silently.
- [x] `l6/counter.js` became `l6/hazard-custom-event.js`: **disabled by default**, with a
      header saying it is a deliberate hazard and never a pattern to copy, enabled only by
      `solutions/l6.hazard.patch.yml` for the demonstration.
- [x] L6 re-promoted to Executed in `VERIFIED.md` with the two-phase evidence.
- [x] The write/restart/read test now exists for L6 and is documented as the general rule:
      in-process behaviour cannot distinguish durable state from a cache.
- [ ] Add the L7 caveat that search fails for a corpus containing an unknown event type.

## Phase 3 — outcome: editorial review complete

An independent editorial review of all nine lessons was run as a separate reviewer pass (structure, clarity, ramp, terminology, stale cross-references, verification quality, tone, concepts tables). Its findings were triaged and fixed in this pass:

**Fixed — the findings that would have misled a reader:**

1. **L2's learner-written tool was never mounted (BLOCKER).** The lesson told readers to create a scratch file that nothing referenced; every verification outcome came from the pre-shipped file. Step 1 now has the reader write **into the bundle** — the only location that can import dsh packages — and states that deleting their version removes the lesson's outcomes, which is the test that they are running their own code.
2. **L1's exit check demanded two explanations the lesson never taught** (load order, shape vs instance). Both moved to L3, where each is actually taught, and L3's exit check now names the `Service` subclass as the second plugin shape.
3. **L7's profile story was wrong**: `session-stats` is web-bundle-only but the lesson booted a base-backed profile. The step now names the profile and cites ADR-0016; the overlay description also said "two inserts" where there are three.
4. **The `link:`/`file:` rule was violated by three reader-facing instructions**, including the first install command a reader runs (README) and a "Verified fix" block in the ledger itself. All unified on `link:`; remaining `file:` mentions are descriptions of its behaviour, not instructions.
5. **L6's step 1 showed a `declare module` block inside a `.js` file** and described an import that does not exist. It now shows the shipped JSDoc pattern with the TypeScript merge as an aside.
6. **L2 and L3 claimed "every step above has been executed"** where their `VERIFIED.md` rows record provider-dependent gaps. Narrowed to match the ledger exactly.
7. **Stale cross-references**: L2's `!!js` promise pointed at L3 (the real next use is L4); the lessons index still described L1 as using a patch overlay; the learning path claimed lessons were verified by `dsh headless`, which the ledger explicitly records as never having been run.
8. **Concepts tables over-promised** in L1 (three shapes, one taught), L3 (Service isolation, further exploration only), and L8 (agent presets, met in L9).
9. **Tone**: working-note narration ("the lesson's original premise was wrong") was rewritten to state the reader-usable fact, while the failure signatures a reader must recognize were kept.

10. **Prose was column-wrapped in every markdown file.** A reader reported the files as having "weird hardcoded carriage returns". There were none — no CR bytes, no hard breaks — and this repository's own site flowed the wraps into spaces. The artifact was the *soft* break: a renderer that shows raw text or honours single newlines turns each wrap into a visible break, so the same file looked different depending on where it was read. Prose is now one line per paragraph, with `pnpm run reflow` as the formatter and `check:wrapping` as the gate ([ADR-0031](decisions/0031-prose-is-not-column-wrapped.md)).

11. **Every upstream link named the wrong branch.** All 42 links to `deepseek-ai/deepseek-harness` said `blob/main/`; the repository's default branch is `master`, so every one of them 404'd. The link checker could not catch it because it hardcoded the expected prefix as a literal — links naming another branch never matched and were never checked. `kit.target.json` had said `"branch": "master"` all along and nothing read the field. The checker now takes the branch from the pin, cross-checks it against the checkout, reads this repository's own branch from git, scans every markdown file including fenced URLs, and reports a wrong branch as a named failure ([ADR-0033](decisions/0033-a-checker-must-not-hardcode-what-it-checks.md)).

12. **Lesson 8's exit-check list was malformed** — no item 4, two 5s, two 6s, and a closing note referring to item numbers that did not exist, so "items 4, 5 and 7 remain unverified" could not be checked. Repaired, and `check:lessons` now fails on any ordered-list block whose numbering repeats or goes backwards. Continuations are still allowed, because a list may legitimately resume at 4 after an interposed explanation; only order and repetition are enforced.

**Left open deliberately:**

- [x] L7: confirmed by experiment that `@deepseek-ai/dsh-invariants` **does** resolve in
      a fresh profile, even though it is not a dependency of the base bundle, because rows
      resolve against the running installation's package tree. The lesson now teaches the
      resulting rule; recorded as [ADR-0019](decisions/0019-what-must-be-installed-vs-what-resolves.md).
- [x] Session layout verified and corrected: it is
      `$DSH_HOME/sessions/<workspace>/session-<uuid>/session.jsonl.zstd` — workspace-scoped,
      one directory per session, and compressed. The old text would have failed three ways.

**Protected as intentional (do not edit away):** the uniform lesson skeleton; the compounding artifact chain (`diagnose` instrument → L6's `sandbox/mode` fold → read back in L7 → consumed by L8's fork); the offline-vs-provider split with its explicit warning; real quoted output instead of invented samples; the upstream-tutorial corrections.

## Verification-suite performance

The full suite boots the harness 27-odd times, once or twice per lesson. It runs in about two minutes (measured: **165s**, 20 passed / 0 failed, and it now leaves zero processes behind): each boot ends when its probe reports completion rather than after a fixed wait. Two harness defects made earlier runs slower *and* unreliable — a leaked `dsh` process per boot ([ADR-0035](decisions/0035-a-background-launch-is-killed-by-the-pid-you-started.md)) and an unbounded `wait` that could hang on a process which reached its pattern but outlived `SIGKILL` ([ADR-0036](decisions/0036-never-wait-unboundedly-on-a-process-you-no-longer-need.md)).

- [x] **Replaced the blind wait with a readiness poll.** `solutions/lib.sh` provides
      `boot_and_wait <checkout> <profile> <log> <pattern> <timeout> [overlay...]`, which polls
      for the probe's own `[<lesson>-probe] done` line; all eight booting scripts use it.
      **The suite went from ~11 minutes to under 3 minutes** (1m50s at 19 checks, 165s once the real-provider phases and the L8 cost comparison were added), and the silent-failure mode is gone: a boot
      killed early used to leave an empty log, which a check asserting on a pattern's *absence*
      would still pass. The motivation was concrete — a fixed 18-second wait made L6's second
      phase fail while its "log is readable" check passed for the wrong reason.
- [x] **The suite leaked a process per boot, then hung on one.** `boot_and_wait` killed a subshell rather than the harness, so every boot orphaned a live `dsh` — 1166 accumulated across the project and eventually hung a run for over half an hour. Fixed with `exec` plus a TERM-then-KILL grace; the second half of the same hang was an unbounded `wait` on a process that reached its pattern but outlived `SIGKILL`. Both are recorded ([ADR-0035](decisions/0035-a-background-launch-is-killed-by-the-pid-you-started.md), [ADR-0036](decisions/0036-never-wait-unboundedly-on-a-process-you-no-longer-need.md)). The suite now leaves zero processes and runs in 165s.
- [x] **Flake reproduced, explained, and fixed.** An earlier note here recorded a single 18/1
      observation as unexplained. It recurred in the run that added the L9 delivery phase, and the
      capture made it identifiable: `FAIL solution: lesson 9 — the scheduled work ran: a second
      assistant message`. The new phase had read the session log the instant a delivery receipt
      appeared, but the receipt is written when the reminder is **admitted**, before the agent runs.
      The read raced the delivered turn, and the companion assertion ("the delivered turn
      completed") passed on the *warm-up* turn's `turn/end` — a false green of exactly the kind
      this suite keeps finding. The phase now waits for a turn count exceeding the warm-up
      baseline; see [ADR-0029](decisions/0029-an-acknowledgment-is-not-a-completion.md). Two
      consecutive L9 runs and a full suite are clean.
- [ ] Consider running the per-lesson checks in parallel. They use distinct session ids and
      distinct overlays, so they are independent; the only shared resource is the harness home.
      That would need a profile or home per worker.

Neither is blocking publication. Both matter because a suite that takes eleven minutes is a suite people skip.

## Phase 4 — Publication readiness

- [x] **Prove the pristine-install path end to end** — a fresh clone in a fresh `DSH_HOME`, provisioned by `scripts/setup-verify-profiles.sh`, runs `check:kit` **20 passed / 0 failed** and leaves no processes behind; without a checkout it is 11 passed / 9 skipped. This is ADR-0018's guarantee checked on the real artifact rather than argued: generated files are absent from the clone and the OKF check plus site build still pass, because the sync runs first. Recorded in [VERIFIED.md](VERIFIED.md).
- [x] Add `PUBLISHING.md`, the runbook for the steps that no file can carry, and
      `pnpm run check:publication`, the gate that refuses until the repository is ready
- [x] Record the intended GitHub topics in `.github/topics.txt` so they survive a
      transfer, and state why the description must contain "DeepSeek Harness"
- [x] Reduced the owner substitution to a single token (`REPLACE_OWNER`) read from
      `package.json`'s `kit` field, instead of hardcoded URLs across five files
- [x] Replace the placeholder owner with `kbaynes` — the substitution was run for real, and
      `check:placeholders` now passes (`no pre-publication placeholders found`). Running it
      exposed two definition sites the exclusion list did not know about, both fixed in the
      command and in [ADR-0026](decisions/0026-a-substitution-must-not-rewrite-its-own-tooling.md):
      this repository's own ADR-0026 quotes the recipe, and `website/.vitepress/config.mts` holds
      the token as a fallback sentinel that a fork needs. The substitution also confirmed the
      gate's remaining teeth: `check:publication` still refuses, now naming only the git author.
- [x] Rewrite the git author identity — done: all commits are `Kevin Baynes <kevin1421@baynes.net>` as author and committer, the local git config matches, and `check:publication` reports READY. The tested recipe stays in PUBLISHING.md step 3 for forks. Original note: Rewrite the git author identity — **needs the maintainer identity**; the history
      currently carries `kit@example.invalid`, which is a placeholder rather than an invented
      real identity. The recipe in `PUBLISHING.md` is **tested**: a non-interactive
      `git rebase --root --exec 'git commit --amend --reset-author --no-edit'` with the identity
      in the environment rewrote all 43 commits and left the tree clean. The previously
      documented `git filter-repo` route is not usable as written — that tool is not installed
      on a stock machine.
- [ ] Decide the public repository name (working name `dsh-exploration-kit`; changing it
      means updating the VitePress `base` in the same edit)
- [x] Confirm the license choice and that `LICENSE`, `package.json`, and
      `THIRD-PARTY.md` agree
- [x] Recheck `THIRD-PARTY.md` against what the content actually derives, and reproduce
      the upstream MIT notice
- [x] Confirm the DeepSeek AI non-affiliation disclaimer is accurate and prominent
- [x] Resolved the changelog question: `content/log.md` is the curriculum history and a
      second `CHANGELOG.md` would drift from it. No second changelog.
- [ ] Confirm the Pages workflow works on a real repository (not just locally)
- [x] Dry-run: export the committed tree fresh, `pnpm run setup`, and run every check
      that needs no checkout. It found two real defects — a second dependency root that
      was never provisioned, and a pristine install exiting 1 on pnpm's ignored-build
      error while still populating `node_modules` (see
      [ADR-0018](decisions/0018-a-pristine-install-must-succeed.md)). Both fixed; the
      dry run now reports `setup exit=0` and 8 passed / 0 failed.
- [ ] Confirm `examples/` and `solutions/` are populated and accurate
- [ ] Decide on a support/feedback channel and state it in `README.md`
- [ ] Review the issue/PR templates for usefulness

## Phase 4.5 — Tag the release against a harness state

**The kit is verified against one DeepSeek Harness commit, and a release must say which.** Without this, "the lessons work" is a claim about a moving target, and a reader on a different harness state has no way to tell whether a failure is theirs or upstream's. The policy and tag format are in [VERIFIED.md](VERIFIED.md#harness-state-this-kit-targets).

- [ ] Confirm the upstream checkout was **clean** when the verification was captured.
      Debris in the harness tree invalidates the commit as an identifier of what was
      exercised. (During development, `packages/dsh-exploration-kit/` test files were
      found left in the checkout and removed — check for exactly this.)
- [ ] Confirm the tested-against table carries the **full** commit, its upstream tag,
      the branch, and the capture date.
- [ ] Confirm the kit's `packageManager`, lockfiles, and pinned optional package
      versions all match that release (see
      [ADR-0013](decisions/0013-pin-optional-package-versions.md)).
- [ ] Decide the kit version for the release and record it in `package.json`.
- [ ] Create the annotated tag in the agreed format:
      `v<kit-version>+dsh.<dsh-version>.g<short-dsh-sha>` — for the state verified
      here, `v0.1.0+dsh.0.2.0-rc.2.g639ed01539`.
- [ ] Put the harness commit, tag, and capture date in the tag message, so the claim
      travels with the tag rather than only living in a file.
- [ ] Add the harness state to the release notes and to `README.md`'s compatibility
      section, so a reader sees it without opening the ledger.
- [ ] Record the tagged harness state in [ROADMAP.md](ROADMAP.md) as the baseline for
      the next round of verification.

### When upstream moves

- [ ] Re-run `pnpm run check:kit` against the new checkout.
- [ ] Re-verify the lessons the change touches; **demote** any `VERIFIED.md` row whose
      claims no longer hold, rather than leaving a stale claim in place.
- [ ] Update the harness-state table, the pinned versions, and the tag naming
      together, so none of them can disagree.
- [ ] Tag a new release at the new commit. Retagging is re-verification, not an edit.

## Phase 5 — Publish and promote

- [ ] Create the GitHub repository and push `main`
- [ ] Enable Pages (Settings → Pages → Source: GitHub Actions) and confirm the URL
- [ ] Set the repository description to include the unambiguous phrase
      "DeepSeek Harness" and add the `dsh-plugin` topic
- [ ] Publish the site and verify the live URL renders and links work
- [ ] Announce in the DSH GitHub Discussions
- [ ] Announce in the DSH Discord
- [ ] Submit to the `awesome-dsh-plugin` registry / `dsh-plugin-catalog`
- [ ] Confirm npm keyword metadata is correct and consider publishing a thin
      wrapper package only if it adds real value
- [ ] Write a short launch post explaining the curriculum's angle (learn by
      building, one seam per lesson)
- [ ] Monitor issues and respond; track friction in the plan rather than in a
      forgotten thread

## Phase 6 — After publication

- [ ] Set up a process to re-verify all lessons on each DSH release, recording the
      version bump
- [ ] Watch upstream for breaking changes that affect the lessons and open issues
- [ ] Keep the compatibility statement in `README.md` current
- [ ] Maintain the contributor workflow in `CONTRIBUTING.md`
- [ ] Periodically prune: remove lessons that no longer pay their way, rather than
      keeping them for completeness
- [ ] Consider contributing links (not content) upstream once the kit is proven

---

## Audit findings — defect register

Two independent audits were run against the scaffold: a per-lesson technical accuracy audit against the DSH source, and a publication-readiness audit. Every item below was verified against source before being accepted. **Closed** means fixed and re-verified.

### Content defects (from the technical audit)

- [x] **BLOCKER** L2 `output.schema` used raw JSON Schema instead of the
      value-schema DSL
- [x] **BLOCKER** L6 projection used raw JSON Schema objects for
      `stateSchema`/`viewSchema`; they are Zod schemas
- [x] **BLOCKER** L6 `key: 'l6Steps'` was not declared in the projection type maps
- [x] **BLOCKER** L5 `agent.inject()` was called with a loose object; it requires a
      full `UserMessage` built by `createUserMessage`, with a producer-declared
      source kind
- [x] **BLOCKER** L8 invented `meta.seedLength`; the real fields are
      `meta.isSeeded` plus top-level `inheritedEventCount`
- [x] **MAJOR** L1 claimed a skipped patch fails the boot; it emits a warning and
      silently skips the row
- [x] **MAJOR** L5 claimed the base `skill-filesystem` row already sets
      `customSkillDirs`; it has no config at all
- [x] **MAJOR** `learning-path.md` named a nonexistent `before-context-build`
      event instead of `agent/pre-step`
- [x] **MAJOR** L7 told the reader to run the invariants check, but
      `@deepseek-ai/dsh-invariants` is mounted only by `sdk-minimal`
- [x] **MAJOR** every `docs/harness/*` and `docs/operations/*` upstream link 404'd —
      those directories do not exist upstream. 13 links remapped to verified paths;
      the 5 `docs/operations/*` checklists have no counterpart and were reworded
- [x] **MINOR** L6 said `SessionEventMap` entries may carry `@mode`; they must not
- [x] **MINOR** L6 said compaction adds three log-only events; it adds four
- [x] **MINOR** `feature-map.md` said four Cordis dispatch modes; there are five
      (`bail` was missing)
- [x] **MINOR** L1 omitted the home-patch layer from the composition order
- [x] **MINOR** L9's Python snippet was a non-runnable placeholder; replaced with
      the upstream SDK's real example
- [ ] **MINOR** L1 gives an aggregated activation diagnostic for a throwing `apply`,
      not a raw stack trace
- [ ] **MINOR** L2 says `--dump-config` shows the resolved `!!js` value; it prints
      expressions unevaluated
- [ ] **MINOR** L2 quotes a validation message with a `$` prefix Cordis does not add
- [ ] **MINOR** L5 says a skill `name` must match its directory; only kebab-case is
      enforced
- [ ] **MINOR** L9: `dsh: <code>: <message>` is the turn-error form only;
      unexpected failures print `dsh: <message>`
- [ ] **MINOR** L9 describes `dsh.bundle` and `dsh.profile` as combinable; a package
      declares one or the other
- [ ] **NIT** L9 references the GitHub review guide without a link

### Publication defects (from the readiness audit)

- [x] **BLOCKER** `.gitignore` `plugins/` + `!plugins/README.md` was dead — git never
      descends into an excluded directory, so `plugins/README.md` was untracked and
      two links to it 404'd. Fixed to `plugins/*`
- [x] **BLOCKER** three `kevinbaynes` URLs in `content/index.md` leaked into every
      built page; made relative
- [x] **BLOCKER** remaining owner placeholders normalised to a single
      `REPLACE_OWNER` token, now enforced by `check:placeholders`
- [x] **MAJOR** the Pages workflow had no `pull_request` trigger, so the link-check
      gate never ran on PRs
- [x] **MAJOR** pnpm version drift (CI pinned 10, development on 11.7.0); now pinned
      via `packageManager`
- [x] **MAJOR** `THIRD-PARTY.md` pointed at nonexistent `website/package.json` and
      `website/pnpm-lock.yaml`, and omitted the upstream MIT notice
- [x] **MAJOR** `README.md` never stated the pnpm requirement or that the lessons
      need a DSH checkout with `dsh` on `PATH`
- [x] **MAJOR** `CONTRIBUTING.md` instructed `cd website && pnpm install`, which
      contradicted the README and only worked by accident
- [x] **MINOR** issue-template labels referenced labels that will not exist; the
      defect template's relative `VERIFIED.md` link was wrong from that directory
- [x] **MINOR** branch protection for per-page `lastUpdated` dates missing
      (`fetch-depth: 0`)
- [x] **MAJOR** added `CODE_OF_CONDUCT.md` and linked it
- [x] **MINOR** added `.editorconfig`
- [x] **MINOR** added `.gitattributes` (LF normalisation, generated-file marking)
- [x] **OPTIONAL** added the site's link-preview metadata (Open Graph, Twitter card) and an
      `editLink`, both derived from the single `kit.repositoryOwner` source so the site needs no
      substitution of its own
- [x] **OPTIONAL** recorded the intended GitHub topics in `.github/topics.txt`
- [ ] **MINOR** add issue labels (`lesson-defect`, `clarity`) to the repository, or
      drop the `labels:` keys
- [ ] **OPTIONAL** record the intended GitHub topics in-repo so they survive a
      transfer
- [ ] **OPTIONAL** add Open Graph/Twitter meta and a favicon for link previews
- [ ] **OPTIONAL** add an `editLink` so readers can propose fixes from a page
- [ ] **BLOCKER (publish-time)** rewrite git history to the real author identity
      before the first public push

### New tooling added by this pass

- [x] `scripts/check-upstream-links.mjs` — validates every upstream DSH link against
      a local checkout. This class of bug (a plausible path that does not exist) is
      now caught mechanically rather than by review.
- [x] `scripts/check-placeholders.mjs` — fails while any pre-publication placeholder
      remains
- [x] `scripts/sync-site-docs.mjs` — copies root docs into the VitePress source
      root, because VitePress refuses links that escape it

## Decision records (ADRs)

The durable engineering lessons of this project are recorded in [`decisions/`](https://github.com/kbaynes/dsh-exploration-kit/blob/main/decisions/README.md) as ADRs, each with Status, Context, Decision, Consequences, and Evidence. They exist so a future agent or contributor reads the reason *before* acting and does not repeat a mistake that cost real debugging time.

`AGENTS.md` requires reading them first, `CONTRIBUTING.md` requires adding one when a new lesson is learned, and `scripts/check-decisions.mjs` (wired into CI) keeps the corpus well-formed and indexed.

The relationship between the records:

| Record | Answers | Role |
|---|---|---|
| `decisions/` (ADRs) | Why is it built this way? What should I not try? | Prevent repeats, before acting |
| `VERIFIED.md` | What has actually been executed? | Prevent overclaiming, at claim time |
| `PLAN.md` | What is left to do? | Track the work |

A defect found while building a lesson belongs in both: the ADR records the durable decision; the lesson and `VERIFIED.md` record what was observed. The PLAN audit register is the task-level view and links to the ADRs where they exist.

## Open decisions

Record decisions here as they are made, with the reason — a decision without a reason gets re-litigated.

| Decision | Options | Status |
|---|---|---|
| Public repo name | `dsh-exploration-kit` / something more discoverable | Open |
| Site hosting | GitHub Pages (current) / custom domain | GitHub Pages for now |
| Curriculum history | `content/log.md` (OKF) vs `CHANGELOG.md` | Open |
| npm package | none / thin `create-*` wrapper | Deferred until proven |
| Lesson 4 offline verification | provider / PTC `run_code` / reload-based | Open |
| Publish L8 cost numbers | yes / no | Open |

## Audit findings integration

Two independent audits were run against the scaffold: a per-lesson technical accuracy audit against the DSH source, and a publication-readiness audit. Their findings are folded into the phase tasks above; anything that could not be verified from source is recorded as an open question rather than a task.
