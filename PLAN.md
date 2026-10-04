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
- [ ] Decide and record the versioning/compatibility policy (deferred to Phase 4)
- [ ] Confirm `content/log.md` is the right home for curriculum history, or move
      development history to `CHANGELOG.md` and keep `log.md` OKF-only
      *(tracked as an open decision below)*

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

- [ ] Implement the `word_count` tool plus Schemastery config in `solutions/l2/`
- [ ] Confirm the tool registers at load and its schema reaches prompt assembly
- [ ] Execute a tool call and confirm the canonical value and render path
- [ ] Confirm an invalid enum makes the load fail with a field-naming error
- [ ] Confirm two stacked `--patch` flags give last-write-wins on the config row
- [ ] Confirm `!!js` interpolates in `config` and `disabled`
- [ ] Add the exact files to `examples/l2/`
- [ ] Review the explanation for clarity
- [ ] Update the `VERIFIED.md` row

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
- [ ] Confirm a write outside the sandbox is denied with the lesson's reason text
- [ ] Confirm a write inside the sandbox succeeds
- [ ] Implement the monotonic `ctx.tools.guard()` example and confirm it cannot be
      undone by another listener
- [ ] Confirm the pipeline-stage table matches the real order
- [ ] Decide whether the lesson needs a provider; if not, document the PTC or
      reload-based verification path that makes it testable offline
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
- [ ] Add a DSH version gate: read the installed `dsh` version and fail loudly when
      it does not match the version recorded in `VERIFIED.md`
- [ ] Split the suite into **no-key** and **needs-provider** groups so CI can run
      the first without secrets
- [ ] Add a CI workflow for the kit's own checks (links, OKF, build)
- [ ] Have `VERIFIED.md` regenerated (or validated) by the suite rather than
      hand-edited, so the ledger cannot drift from reality
- [ ] Decide what CI does when DSH upstream changes: warn, or fail the build

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

## Phase 4 — Publication readiness

- [ ] Replace every placeholder: repo owner, URLs, `base` in the VitePress config
- [ ] Set the real git author identity on the initial commit (or rewrite history)
- [ ] Decide the public repository name and make it consistent everywhere
- [ ] Confirm the license choice and that `LICENSE`, `package.json`, and
      `THIRD-PARTY.md` agree
- [ ] Recheck `THIRD-PARTY.md` against what the content actually derives
- [ ] Confirm the DeepSeek AI non-affiliation disclaimer is accurate and prominent
- [ ] Add a `CHANGELOG.md` or confirm `content/log.md` serves that purpose
- [ ] Confirm the Pages workflow works on a real repository (not just locally)
- [ ] Dry-run: clone the repo fresh, install, build, and complete Lesson 1
- [ ] Confirm `examples/` and `solutions/` are populated and accurate
- [ ] Decide on a support/feedback channel and state it in `README.md`
- [ ] Review the issue/PR templates for usefulness

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
