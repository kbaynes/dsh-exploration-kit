---
type: ADR
title: "ADR-0014 — Tag each release to the DeepSeek Harness commit it was verified against"
description: A kit release is tagged with the upstream harness commit it was verified against, because "the lessons work" is otherwise a claim about a moving target.
status: Accepted
timestamp: 2026-10-01
---

# ADR-0014 — Tag each release to the DeepSeek Harness commit it was verified against

## Status

Accepted

## Context

The kit's whole value is that its instructions work. But each lesson is verified against **one state** of a developer-preview project that changes with breaking changes. Without a link from a kit release to a harness commit:

- A reader on a newer harness cannot tell whether a failure is their setup, the kit, or upstream drift.
- A maintainer re-verifying after an upgrade has no baseline to compare against.
- `VERIFIED.md` records a commit, but nothing connects that record to a *release*, so the claim is only discoverable by reading prose.

The current state is DSH `0.2.0-rc.2`, upstream tag `dsh-v0.2.0-rc.2`, commit `639ed015397290b3745d163aafe02ffee4aa3f84`.

A related hazard was found while recording this: the harness checkout contained leftover test files (a `packages/dsh-exploration-kit/` directory from an early module-resolution experiment). A dirty checkout means the recorded commit does not identify what was actually exercised.

## Decision

A kit release is an **annotated tag** naming both versions:

```
v<kit-version>+dsh.<dsh-version>.g<short-dsh-sha>
v0.1.0+dsh.0.2.0-rc.2.g639ed01539
```

The tag message carries the full upstream commit, its tag, and the capture date, so the claim travels with the tag. The release gate and the upgrade procedure are recorded in [VERIFIED.md](../VERIFIED.md#harness-state-this-kit-targets) and [PLAN.md](../PLAN.md) Phase 4.5.

The harness state used for verification must be a **clean** tree: a commit identifier is only meaningful if the working tree matched it.

## Consequences

- Publishing becomes gated on a documented harness state, which slows the first release and every subsequent one. That cost is the point.
- Moving to a new harness commit means re-verifying and re-tagging. Retagging is not an edit to the record.
- A lesson whose claims stop holding at a new commit must be **demoted** in `VERIFIED.md` rather than left claiming verification. Demotion is the honest outcome of an upstream break, not a failure of the project.
- The kit version and the pinned optional package versions must move together with the harness state, or three records can disagree. See [ADR-0013](0013-pin-optional-package-versions.md).

Rejected alternative: one rolling "verified against latest" claim. It is cheaper and strictly less useful — it cannot tell a reader anything about the harness they hold.

## Evidence

[VERIFIED.md](../VERIFIED.md) "Tested against" records the full commit, tag, branch, capture date, and the clean-tree condition. The tag format has not yet been applied: no kit release exists, and Phase 4.5 is where it will be.
