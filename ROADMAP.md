# Roadmap — at a glance

A fast status view. The detailed task list with checkboxes lives in
[PLAN.md](PLAN.md); this file is what you read in five seconds.

**Verified harness state:** DSH `0.2.0-rc.2` at
`639ed015397290b3745d163aafe02ffee4aa3f84` (tag `dsh-v0.2.0-rc.2`), captured
2026-10-01. Kit releases are tagged against this so the relationship survives; see
[VERIFIED.md](VERIFIED.md#harness-state-this-kit-targets) and
[PLAN Phase 4.5](PLAN.md).

**Current phase: 1 — Building lessons.** Lessons 1–2 built and verified; nothing is published yet.

| Phase | Goal | Status |
|---|---|---|
| 0 | Groundwork — version pin, baseline checks, issue templates | ✅ Done |
| 0.5 | Rewrite lessons for the verified bundle mechanism | 🔄 L1–L7 done; L8–L9 to go |
| 1 | Build, test, and review each lesson | 🔄 In progress (1–2 of 9) |
| 2 | Test infrastructure — automated verification in CI | 🔄 `check:kit` runner + unit tests landed |
| 3 | Whole-kit review — editorial and technical pass | ⬜ Not started |
| 4 | Publication readiness — placeholders, licensing, metadata | ⬜ Not started |
| 4.5 | Tag the release against a harness state | ⬜ Not started |
| 5 | Publish and promote | ⬜ Not started |
| 6 | After publication — maintenance and contributions | ⬜ Not started |

## Lesson status

Legend: ✅ done · 🟡 partial · ⬜ not started

| # | Lesson | Implemented | Tested | Reviewed |
|---|---|---|---|---|
| 1 | Mount your first plugin | ✅ | ✅ | ⬜ |
| 2 | Register a tool, compose with config | ✅ | 🟡 | ⬜ |
| — | **Lessons need rewriting to install the bundle** — see PLAN Phase 0.5 | | | |
| 3 | Services, isolation, and hot reload | ✅ | 🟡 | ⬜ |
| 4 | Build a policy gate | ✅ | 🟡 | ⬜ |
| 5 | Assemble context deliberately | ✅ | 🟡 | ⬜ |
| 6 | Give the session durable state | ✅ | 🟡 | ⬜ |
| 7 | Operate the harness | ✅ | 🟡 | ⬜ |
| 8 | Orchestrate multiple agents | ⬜ | ⬜ | ⬜ |
| 9 | Automate the harness | ⬜ | ⬜ | ⬜ |

"Tested" means executed end-to-end against a real DSH checkout and recorded in
[VERIFIED.md](VERIFIED.md). Designing a lesson is not implementing it. A partial 🟡
means the mechanism was executed but the lesson's own exercise was not.

## The gate that matters

**Do not promote the kit until every lesson is Implemented and Tested.** A
curriculum that does not run is worse than no curriculum, because the people who
try it conclude the harness is broken.
