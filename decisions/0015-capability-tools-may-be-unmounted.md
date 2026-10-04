---
type: ADR
title: "ADR-0015 — A capability named in the docs is not necessarily mounted"
description: A capability named in the docs is not necessarily mounted.
status: Accepted
timestamp: 2026-10-01
---

# ADR-0015 — A capability named in the docs is not necessarily mounted

## Status

Accepted

## Context

Lesson 9 assumed `schedule_*` and `ctx.webhookRuntime` were available, because the tool catalog documents them. Neither package is mounted by **any** shipped bundle. They are opt-in, must be installed into a profile, and must be added by a row.

The wrong assumption looked confirmed by a false match: grepping the bundle patches for `schedule` and `webhook` returns hits — but they are telemetry tuning keys (`scheduledDelayMillis`, and a web-app variant), not these packages. A plausible hit on the wrong symbol is exactly how an unverified premise survives review.

This is the same class as [ADR-0003](0003-plugins-ship-as-a-bundle.md) and part of [ADR-0007](0007-config-needs-a-real-schema.md)'s theme: what the harness *documents* and what a given composition *mounts* are different facts.

## Decision

A capability is treated as available only after confirming it in a shipped bundle patch **or** in a composed profile. Before a lesson depends on a capability:

1. Search the bundle patches for the **package name**, not the feature word.
2. Confirm the row composes (`--dump-config`) and activates (no `not activate` warning).
3. If it is opt-in, install the pinned version and insert the row, and say so in the lesson.

## Consequences

- Verification gains a "is it even mounted?" step, which costs a minute and has already caught two lessons' worth of wrong assumptions.
- A feature-word search is not evidence. `scheduledDelayMillis` is not a schedule.
- Opt-in packages may also require services from a particular bundle, so *mounted* is not the last question — see [ADR-0016](0016-profile-choice-is-load-bearing.md).

## Evidence

[VERIFIED.md](../VERIFIED.md) "Evidence: L9 opt-in packages compose and activate" records the false match, the two opt-in packages, and the successful composition.
