# Implementation Plan

The working plan for taking the DSH Exploration Kit from scaffold to published
curriculum. Detailed and checkbox-driven: tick items as they are completed, and
keep [ROADMAP.md](ROADMAP.md) in sync as the fast status view.

## Guiding rules

These constrain every task below. They are the reason the plan is shaped this way.

1. **Verified means run.** A lesson step is verified only when it was executed
   against a real DSH checkout and the observed result recorded in
   [VERIFIED.md](VERIFIED.md). Design is not implementation; documentation is not
   verification.
2. **One lesson, one seam.** Each lesson introduces exactly one new extension
   point, so a failure is attributable.
3. **Ship the working artifact.** Every lesson's exercise exists in `solutions/`
   (answer key) and `examples/` (exactly as presented). Building the reference
   solution *is* the test.
4. **Nothing unpublishable ships in `content/`.** Labs, drafts, and dead ends stay
   out of the bundle, because that is what the site renders.
5. **Version honesty.** Every claim carries the DSH version it was verified
   against. When upstream changes, the ledger changes with it.
6. **Prerequisites are explicit.** A reader on a clean checkout must not have to
   guess what a lesson assumes.

## Status legend

`[ ]` not started · `[~]` in progress · `[x]` done · `[-]` decided against (with
the reason recorded inline)

---

## Phase 0 — Groundwork

Get the repo consistent and its checks trustworthy before writing nine lessons
against it.

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

**Blocking all lesson work.** A verified design finding invalidated the mechanism
the lessons teach: a plugin that imports anything from dsh **cannot** be loaded by
pointing a `--patch` overlay at a loose file, because pnpm symlinks only declared
dependencies and `@deepseek-ai/*` is unreachable from outside a dsh installation.
Full evidence is in [VERIFIED.md](VERIFIED.md) ("Design pivot").

The fix is verified and in place: `kit-plugins/` is a real dsh bundle, installed
with `dsh plugin --profile <name> add file:<kit>/kit-plugins`, with rows referenced
by package name. Lesson 2's plugin loads and mounts its tool through it.

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

The substance of the project. Repeat this block for each lesson. **Order is
independence, not number: do lessons 1, 2, 3, 6, 4, 5, 7, 8, 9.** Lessons 1–3 and
6 need no model API key and can be finished first; 4 is testable with a provider
or via PTC; 5 and 7–9 need a configured provider.

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

- [ ] Implement `turn-observer.ts` and confirm the real `agent/pre-step` payload
      shape, then correct the lesson to match it
- [ ] Implement the `agent.inject()` example and confirm the injected text appears
      in the replayed session after a restart
- [ ] Create the skill bundle and confirm it appears in the catalog
- [ ] Confirm a rename/add reaches the catalog without a restart
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
- [ ] Confirm cross-workspace access fails closed with the stated error code
- [ ] Measure the token delta caused by mounting `tool-session-query`
- [ ] Confirm `/compact` produces a measurable reduction
- [ ] Confirm the telemetry env vars behave as documented and that config alone
      cannot disable the row
- [ ] Run the invariants check against a composition including kit plugins
- [ ] Produce a worked cost/trajectory example and decide whether it belongs in
      the lesson
- [ ] Add the exact files to `examples/l7/`
- [ ] Review the explanation for clarity
- [ ] Update the `VERIFIED.md` row

### Lesson 8 — Orchestrate multiple agents

- [ ] Run a spawned child and confirm it lacks parent context
- [ ] Run a forked child and confirm it inherits the cut
- [ ] Execute the workflow script and confirm a dense, schema-validated array
- [ ] Confirm a failing stage drops that item to `null`
- [ ] Confirm a misused hook ends the script with a naming error
- [ ] Capture the monolithic-vs-fan-out comparison with real token numbers and
      decide whether to publish the numbers
- [ ] Confirm `ctx.agents.create({ seed, meta })` fork behaves as described
- [ ] Read the agent-team profile patch and decide whether L8's optional step
      should stay
- [ ] Add the exact files to `examples/l8/`
- [ ] Review the explanation for clarity
- [ ] Update the `VERIFIED.md` row

### Lesson 9 — Automate the harness

- [ ] Confirm the headless exit codes for success and failure
- [ ] Confirm `--json` emits assertable tool-call events
- [ ] Confirm `--session-id` adopts an exact session and fails on unknown ids
- [ ] Run the TypeScript SDK sample with a `patches` file loading a kit tool
- [ ] **Replace or delete the Python placeholder snippet** — currently
      non-runnable; either test a real call or cut the step
- [ ] Confirm a schedule fires once and appears in `schedule_list`
- [ ] Confirm a webhook rule creates exactly one Session per delivery and record
      the duplicate-delivery behavior
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
- [x] Decided: the scheduled full-verification workflow **fails** on upstream drift, and
the response is to re-verify and either fix the lesson or demote its `VERIFIED.md` row.

## Phase 3 — Whole-kit review

- [ ] Complete the technical accuracy pass across all nine lessons (from the
      lesson audit findings)
- [ ] Complete the editorial clarity pass: consistent lesson shape, terminology,
      voice, and difficulty ramp
- [ ] Verify every upstream link resolves (repo paths in the DSH checkout)
- [ ] Confirm the `feature-map.md` rows agree with the lessons that exercise them
- [ ] Confirm the `learning-path.md` dependency graph still matches the lessons
- [ ] Check the "what this path does not cover" list is still accurate
- [ ] Have at least one other person run Lesson 1 cold on a clean machine and
      report friction points
- [ ] Have a second person run one provider-dependent lesson cold
- [ ] Add a "fast path" ramp (e.g. a 30-minute subset) and evaluate whether it
      helps completion
- [ ] Re-read [VERIFIED.md](VERIFIED.md) end to end and correct every overstatement

## Blocking defect — L6 must stop inventing an event type

Found in this round by a two-boot experiment (ADR-0024): a plugin-declared `SessionEventMap`
type is writable and foldable, and makes the session **unopenable after a restart**. The
lesson text is already corrected; the shipped code is not.

- [ ] Refactor `kit-plugins/l6/counter.js` to stop appending `l6/step`, and refactor
      `l6/fold.js` to fold a **known** event type (`tool/result`), accumulating as it goes.
- [ ] Update `l6/projection-probe.js` and `solutions/verify-l6.sh` to the new event and to
      assert the **restart** path — which is the claim that was wrong, so it must be the one
      the check covers.
- [ ] Decide whether `l6-counter.js` survives at all: keeping it as a deliberate hazard
      risks a reader enabling it. If it stays, its row and comments must say it is a
      demonstration, never a pattern to copy.
- [ ] Re-promote L6's `VERIFIED.md` row to Executed once the two-boot check passes.
- [ ] Add the same write/restart/read test to any other place the kit writes durable plugin
      state.
- [ ] Add the L7 caveat that search fails for a corpus containing an unknown event type.

## Phase 3 — outcome: editorial review complete

An independent editorial review of all nine lessons was run as a separate reviewer
pass (structure, clarity, ramp, terminology, stale cross-references, verification
quality, tone, concepts tables). Its findings were triaged and fixed in this pass:

**Fixed — the findings that would have misled a reader:**

1. **L2's learner-written tool was never mounted (BLOCKER).** The lesson told readers
   to create a scratch file that nothing referenced; every verification outcome came
   from the pre-shipped file. Step 1 now has the reader write **into the bundle** — the
   only location that can import dsh packages — and states that deleting their version
   removes the lesson's outcomes, which is the test that they are running their own
   code.
2. **L1's exit check demanded two explanations the lesson never taught** (load order,
   shape vs instance). Both moved to L3, where each is actually taught, and L3's exit
   check now names the `Service` subclass as the second plugin shape.
3. **L7's profile story was wrong**: `session-stats` is web-bundle-only but the lesson
   booted a base-backed profile. The step now names the profile and cites ADR-0016;
   the overlay description also said "two inserts" where there are three.
4. **The `link:`/`file:` rule was violated by three reader-facing instructions**,
   including the first install command a reader runs (README) and a "Verified fix"
   block in the ledger itself. All unified on `link:`; remaining `file:` mentions are
   descriptions of its behaviour, not instructions.
5. **L6's step 1 showed a `declare module` block inside a `.js` file** and described an
   import that does not exist. It now shows the shipped JSDoc pattern with the
   TypeScript merge as an aside.
6. **L2 and L3 claimed "every step above has been executed"** where their `VERIFIED.md`
   rows record provider-dependent gaps. Narrowed to match the ledger exactly.
7. **Stale cross-references**: L2's `!!js` promise pointed at L3 (the real next use is
   L4); the lessons index still described L1 as using a patch overlay; the learning
   path claimed lessons were verified by `dsh headless`, which the ledger explicitly
   records as never having been run.
8. **Concepts tables over-promised** in L1 (three shapes, one taught), L3 (Service
   isolation, further exploration only), and L8 (agent presets, met in L9).
9. **Tone**: working-note narration ("the lesson's original premise was wrong") was
   rewritten to state the reader-usable fact, while the failure signatures a reader
   must recognize were kept.

**Left open deliberately:**

- [x] L7: confirmed by experiment that `@deepseek-ai/dsh-invariants` **does** resolve in
      a fresh profile, even though it is not a dependency of the base bundle, because rows
      resolve against the running installation's package tree. The lesson now teaches the
      resulting rule; recorded as [ADR-0019](decisions/0019-what-must-be-installed-vs-what-resolves.md).
- [x] Session layout verified and corrected: it is
      `$DSH_HOME/sessions/<workspace>/session-<uuid>/session.jsonl.zstd` — workspace-scoped,
      one directory per session, and compressed. The old text would have failed three ways.

**Protected as intentional (do not edit away):** the uniform lesson skeleton; the
compounding artifact chain (`diagnose` instrument → `l6/step` events → read back in L7 →
consumed by L8's fork); the offline-vs-provider split with its explicit warning;
real quoted output instead of invented samples; the upstream-tutorial corrections.

## Phase 4 — Publication readiness

- [x] Add `PUBLISHING.md`, the runbook for the steps that no file can carry, and
      `pnpm run check:publication`, the gate that refuses until the repository is ready
- [x] Record the intended GitHub topics in `.github/topics.txt` so they survive a
      transfer, and state why the description must contain "DeepSeek Harness"
- [x] Reduced the owner substitution to a single token (`REPLACE_OWNER`) read from
      `package.json`'s `kit` field, instead of hardcoded URLs across five files
- [ ] Replace the placeholder owner — **needs the real GitHub owner**; then
      `pnpm run check:placeholders` passes
- [ ] Rewrite the git author identity — **needs the maintainer identity**; the history
      currently carries `kit@example.invalid`, which is a placeholder rather than an
      invented real identity
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

**The kit is verified against one DeepSeek Harness commit, and a release must say
which.** Without this, "the lessons work" is a claim about a moving target, and a
reader on a different harness state has no way to tell whether a failure is theirs or
upstream's. The policy and tag format are in
[VERIFIED.md](VERIFIED.md#harness-state-this-kit-targets).

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

Two independent audits were run against the scaffold: a per-lesson technical
accuracy audit against the DSH source, and a publication-readiness audit. Every
item below was verified against source before being accepted. **Closed** means
fixed and re-verified.

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
- [ ] **MINOR** add `.gitattributes` (LF normalisation,
      `pnpm-lock.yaml linguist-generated`)
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

The durable engineering lessons of this project are recorded in
[`decisions/`](https://github.com/REPLACE_OWNER/dsh-exploration-kit/blob/main/decisions/README.md) as ADRs, each with Status, Context, Decision,
Consequences, and Evidence. They exist so a future agent or contributor reads the
reason *before* acting and does not repeat a mistake that cost real debugging time.

`AGENTS.md` requires reading them first, `CONTRIBUTING.md` requires adding one when
a new lesson is learned, and `scripts/check-decisions.mjs` (wired into CI) keeps the
corpus well-formed and indexed.

The relationship between the records:

| Record | Answers | Role |
|---|---|---|
| `decisions/` (ADRs) | Why is it built this way? What should I not try? | Prevent repeats, before acting |
| `VERIFIED.md` | What has actually been executed? | Prevent overclaiming, at claim time |
| `PLAN.md` | What is left to do? | Track the work |

A defect found while building a lesson belongs in both: the ADR records the durable
decision; the lesson and `VERIFIED.md` record what was observed. The PLAN audit
register is the task-level view and links to the ADRs where they exist.

## Open decisions

Record decisions here as they are made, with the reason — a decision without a
reason gets re-litigated.

| Decision | Options | Status |
|---|---|---|
| Public repo name | `dsh-exploration-kit` / something more discoverable | Open |
| Site hosting | GitHub Pages (current) / custom domain | GitHub Pages for now |
| Curriculum history | `content/log.md` (OKF) vs `CHANGELOG.md` | Open |
| npm package | none / thin `create-*` wrapper | Deferred until proven |
| Lesson 4 offline verification | provider / PTC `run_code` / reload-based | Open |
| Publish L8 cost numbers | yes / no | Open |

## Audit findings integration

Two independent audits were run against the scaffold: a per-lesson technical
accuracy audit against the DSH source, and a publication-readiness audit. Their
findings are folded into the phase tasks above; anything that could not be
verified from source is recorded as an open question rather than a task.
