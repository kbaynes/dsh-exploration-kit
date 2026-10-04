# Roadmap — at a glance

A fast status view. The detailed task list with checkboxes lives in [PLAN.md](PLAN.md); this file is what you read in five seconds.

**Verified harness state:** DSH `0.2.0-rc.2` at `639ed015397290b3745d163aafe02ffee4aa3f84` (tag `dsh-v0.2.0-rc.2`), captured 2026-10-01. Kit releases are tagged against this so the relationship survives; see [VERIFIED.md](VERIFIED.md#harness-state-this-kit-targets) and [PLAN Phase 4.5](PLAN.md).

**Current phase: 4 — Publication readiness.** All nine lessons are built and executed; the kit is one owner substitution away from publishable, and publication is deliberately held until more hardening is done.

**Every exit-check item in all nine lessons is now executed.** The last three needed a real model rather than the scriptable keyless provider, and all three were closed against the operator's own OpenRouter credential: L7's input-token delta from mounting a tool (**1,664 tokens**), and L8's "a child does not know the parent's conversation" and "a model chooses `send_message` and `interrupt_agent`". Those checks are **opt-in** (`DSH_REAL_PROVIDER_PATCH`), so the default suite stays keyless and prints `SKIP` for them. The only thing still unproven anywhere is the *magnitude* of L8's cost comparison, which is a property of a price list rather than of the harness.

A turn-killing bug in the kit's **own** Lesson 5 listener (`JSON.stringify` of a live event payload — see [ADR-0028](decisions/0028-never-stringify-a-live-event-payload.md)) had been misrecorded as an upstream harness defect for two rounds. Fixing it closed the L5 skill catalogue, L7's completed turn, and L9's delivery, all of which are now asserted by the suite rather than described as unverified.

| Phase | Goal | Status |
|---|---|---|
| 0 | Groundwork — version pin, baseline checks, issue templates | ✅ Done |
| 0.5 | Rewrite lessons for the verified bundle mechanism | ✅ All nine rewritten |
| 1 | Build, test, and review each lesson | ✅ All nine built and executed |
| 2 | Test infrastructure — automated verification in CI | ✅ 20 checks, version gate, full CI run (~3m), leaves no processes behind |
| 3 | Whole-kit review — editorial and technical pass | ✅ Two independent audits triaged and fixed |
| 4 | Publication readiness — placeholders, licensing, metadata | ✅ owner `kbaynes`, author identity set, `check:publication` 6/6 READY |
| 4.5 | Tag the release against a harness state | ⬜ Pending publication |
| 5 | Publish and promote | ⬜ Not started |
| 6 | After publication — maintenance and contributions | ⬜ Not started |

## Lesson status

Legend: ✅ done · 🟡 partial · ⬜ not started

| # | Lesson | Implemented | Tested | Reviewed |
|---|---|---|---|---|
| 1 | Mount your first plugin | ✅ | ✅ | ✅ |
| 2 | Register a tool, compose with config | ✅ | ✅ | ✅ |
| 3 | Services, isolation, and hot reload | ✅ | ✅ | ✅ |
| 4 | Build a policy gate | ✅ | 🟡 | ✅ |
| 5 | Assemble context deliberately | ✅ | ✅ | ✅ |
| 6 | Give the session durable state | ✅ | ✅ | ✅ |
| 7 | Operate the harness | ✅ | ✅ | ✅ |
| 8 | Orchestrate multiple agents | ✅ | ✅ | ✅ |
| 9 | Automate the harness | ✅ | ✅ | ✅ |

"Tested" means executed end-to-end against a real DSH checkout and recorded in [VERIFIED.md](VERIFIED.md). Designing a lesson is not implementing it. A 🟡 means part of a lesson's verification is still open, and the ledger row names which part — today only Lesson 4, whose `ask` path needs a real approval flow rather than a scripted decision.

## The gate that matters

**Do not promote the kit until every lesson is Implemented and Tested.** A curriculum that does not run is worse than no curriculum, because the people who try it conclude the harness is broken.
