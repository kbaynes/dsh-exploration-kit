---
type: ADR
title: "ADR-0020 — Full verification runs against the pinned commit, on a schedule"
description: Full verification runs against the pinned commit, on a schedule.
status: Accepted
timestamp: 2026-10-02
---

# ADR-0020 — Full verification runs against the pinned commit, on a schedule

## Status

Accepted

## Context

The kit publishes a claim: these lessons work against a specific DeepSeek Harness commit. Two things can quietly invalidate that claim.

1. **Verifying against `main`** makes the result a statement about whatever the harness looked like that morning, which is not the claim the kit makes.
2. **Upstream drift** is invisible until a reader hits it. Nothing in the kit's own CI would notice that a lesson had stopped being true.

Before this decision, CI ran only the checks that need no harness. The per-lesson verification — the part that actually proves the lessons — ran only on a maintainer's machine, which means it ran when someone remembered.

## Decision

A dedicated workflow, `verify against dsh`, clones `deepseek-harness` **at the commit in `kit.target.json`**, builds it, provisions the profiles, and runs the complete check set including every per-lesson script.

- **Triggered weekly and on demand, not per push.** The pinned commit does not change between pushes, and cloning plus building the harness costs minutes.
- **It asserts the checkout is the recorded commit, with a clean tree**, before running anything (`check:target`). A silent upstream change cannot make a later result meaningless.
- **The commands it runs are extracted into scripts** (`install-dsh-shim.sh`, `setup-verify-profiles.sh`) so the local reproduction and CI cannot diverge.

## Consequences

- The release gate from [ADR-0014](0014-tag-releases-to-a-harness-commit.md) is now mechanically checkable rather than a procedure someone follows.
- Weekly runs turn upstream drift into a failing build with a named lesson, instead of a reader's bug report.
- A drift failure is expected occasionally and is not an emergency: DSH is a developer preview. The response is to re-verify and either fix the lesson or demote its row in `VERIFIED.md` — per [ADR-0014](0014-tag-releases-to-a-harness-commit.md), demotion is the honest outcome of an upstream break.
- The workflow costs minutes and a full harness build per run. That is the price of verifying something that depends on another project.

## Evidence

The command sequence was executed locally through the shim a CI step installs: `check:kit` reported `16 passed, 0 failed` with `dsh` resolved only from that shim, proving the sequence does not depend on a maintainer's PATH.

**The workflow YAML itself has not been executed** — GitHub Actions cannot be run from here. Its steps are verified; the orchestration around them is not. Recorded as unverified in [VERIFIED.md](../VERIFIED.md) rather than implied by the passing local run.
