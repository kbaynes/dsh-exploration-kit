# Contributing to the DSH Exploration Kit

Thanks for helping. The most valuable contributions, in order:

1. **Verification** — running a lesson end-to-end and reporting exactly what differed.
2. **Clarity fixes** — a step that confused you is a defect; say which step and what you expected.
3. **Compatibility updates** — what broke on a newer DSH version.
4. **New lessons** — appreciated, but only in the established shape.

## The verification rule

**Never mark a step verified unless you ran it.** [VERIFIED.md](VERIFIED.md) records the status of every lesson. Documented-but-unrun is a legitimate status; overstating verification is the most damaging error this repository can make. If you run a lesson, update its row and add your environment to the "Tested against" table.

## Lesson shape

Every lesson uses the same sections, in this order:

```md
---
type: Exploration Lesson
title: "L<N> — <short title>"
description: <one sentence: what the learner will have built>
resource: dsh
tags: [deepseek-harness, lesson, <topic tags>]
timestamp: <ISO date>
---

# L<N> — <short title>

**Goal.** What exists and works at the end.

**Why here.** Why this lesson follows the previous one.

## Concepts taught
| Concept | What you learn |

## Prerequisites
Which earlier lessons must be complete.

## Step <n> — <imperative title>
Explanation, then a tested code block.

## Verification
Numbered, observable checks.

## Exit check — you should now be able to explain
Open questions that prove understanding, not recall.

## Next
Link to the following lesson.
```

Rules for the body:

- **One new seam per lesson.** A lesson introduces exactly one new extension point, so a failure is attributable.
- **Every code block must be runnable as written**, or explicitly labelled as a sketch. No pseudo-API.
- **Say when something is unverified.** "This is documented but I have not run it" beats a confident claim that wastes a reader's afternoon.
- **Own your failure modes.** A troubleshooting table of ways the step breaks is worth more than another paragraph of explanation.

## Links

- **Inside the kit:** relative markdown links (`./lessons/03-....md`). These are link-checked in CI and a broken one is an error.
- **To DSH's own docs:** absolute URLs to `https://github.com/deepseek-ai/deepseek-harness/blob/master/...`, so the kit works when cloned on its own.

## When to add a decision record

If you learn something a future contributor could re-learn the hard way — a mechanism that does not work, a tool that behaves differently than its documentation, a design constraint that is not obvious — record it as an ADR in [`decisions/`](https://github.com/kbaynes/dsh-exploration-kit/blob/main/decisions/README.md), following the existing records' shape (Status, Context, Decision, Consequences, Evidence). Add it to the index there.

Evidence is not optional: if you did not run it, say so in the ADR. A decision record that reads confidently but was never verified is the exact failure [ADR-0001](https://github.com/kbaynes/dsh-exploration-kit/blob/main/decisions/0001-verify-by-running.md) exists to prevent.

`pnpm run check:decisions` fails when a record is malformed, misnumbered, or missing from the index.

## Examples are generated

`examples/` mirrors `kit-plugins/`, which is canonical because it is what the boot actually loads. After editing a lesson plugin, run `node scripts/sync-examples.mjs`. CI runs `--check` and fails on drift — a hand-edited copy that disagrees with the booting code is exactly the bug this project exists to avoid.

## Conventions

- `<kit>` means this repository's root. Exercise plugins live under `<kit>/plugins/`.
- Do not put non-concept files inside `content/` — it is an Open Knowledge Format bundle, and only `index.md` and `log.md` are reserved filenames.
- Every concept file needs frontmatter with at least `type`, `title`, and `description`.
- Do not column-wrap prose. Write one line per paragraph or list item, so the file renders identically in every viewer rather than breaking mid-sentence wherever soft breaks are honoured. `pnpm run reflow` fixes it; `pnpm run check:kit` fails if it comes back ([ADR-0031](https://github.com/kbaynes/dsh-exploration-kit/blob/main/decisions/0031-prose-is-not-column-wrapped.md)).

## Before you open a pull request

```sh
# from the repository root
pnpm run setup        # installs both dependency roots; see README

# everything that needs no DSH checkout:
pnpm run check:kit

# add the upstream-link and per-lesson checks by pointing at a checkout:
DSH_CHECKOUT=/path/to/deepseek-harness pnpm run check:kit

# validate the OKF bundle, if okflint is installed
okflint validate --manifest okf-base.yaml

# verify upstream DSH links against a local checkout
DSH_CHECKOUT=/path/to/deepseek-harness pnpm run check:upstream
```

`pnpm run check:placeholders` must pass before a release: it fails while any pre-publication placeholder token remains.

Then confirm your internal links resolve and that `VERIFIED.md` matches what you actually did.

## Code of Conduct

Participation is covered by the [Code of Conduct](https://github.com/kbaynes/dsh-exploration-kit/blob/main/CODE_OF_CONDUCT.md). Report unacceptable behavior through the repository's **Security → Report a vulnerability** channel or to a maintainer directly.

## Licensing

Contributions are MIT licensed. By opening a pull request you confirm you have the right to contribute the material and that newly derived upstream content is recorded in [THIRD-PARTY.md](THIRD-PARTY.md).
