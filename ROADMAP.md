# Roadmap — at a glance

A fast status view. The detailed task list with checkboxes lives in
[PLAN.md](PLAN.md); this file is what you read in five seconds.

**Current phase: 0 — Groundwork.** Only Lesson 1 is verified. Nothing is published.

| Phase | Goal | Status |
|---|---|---|
| 0 | Groundwork — version pin, baseline checks, issue templates | 🔄 In progress |
| 1 | Build, test, and review each lesson | ⬜ Not started |
| 2 | Test infrastructure — automated verification in CI | ⬜ Not started |
| 3 | Whole-kit review — editorial and technical pass | ⬜ Not started |
| 4 | Publication readiness — placeholders, licensing, metadata | ⬜ Not started |
| 5 | Publish and promote | ⬜ Not started |
| 6 | After publication — maintenance and contributions | ⬜ Not started |

## Lesson status

| # | Lesson | Implemented | Tested | Reviewed |
|---|---|---|---|---|
| 1 | Mount your first plugin | ⬜ | ✅ | ⬜ |
| 2 | Register a tool, compose with config | ⬜ | ⬜ | ⬜ |
| 3 | Services, isolation, and hot reload | ⬜ | ⬜ | ⬜ |
| 4 | Build a policy gate | ⬜ | ⬜ | ⬜ |
| 5 | Assemble context deliberately | ⬜ | ⬜ | ⬜ |
| 6 | Give the session durable state | ⬜ | ⬜ | ⬜ |
| 7 | Operate the harness | ⬜ | ⬜ | ⬜ |
| 8 | Orchestrate multiple agents | ⬜ | ⬜ | ⬜ |
| 9 | Automate the harness | ⬜ | ⬜ | ⬜ |

"Tested" means executed end-to-end against a real DSH checkout and recorded in
[VERIFIED.md](VERIFIED.md). Designing a lesson is not implementing it.

## The gate that matters

**Do not promote the kit until every lesson is Implemented and Tested.** A
curriculum that does not run is worse than no curriculum, because the people who
try it conclude the harness is broken.
