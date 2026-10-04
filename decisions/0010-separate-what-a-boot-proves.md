---
type: ADR
title: "ADR-0010 — Separate what a boot proves from what a session proves"
description: Separate what a boot proves from what a session proves.
status: Accepted
timestamp: 2026-10-01
---

# ADR-0010 — Separate what a boot proves from what a session proves

## Status

Accepted

## Context

A plugin that loads has proven that its imports resolve, its config validates, and its `apply` completed. It has **not** proven that its behaviour is correct. Those are different claims, and conflating them is how a curriculum ends up asserting things nobody checked.

Concretely: Lesson 4's gate loads and prints its confinement root, but whether it denies the right writes needs a tool call. Lesson 2's tool registers, but whether the model can call it needs a provider.

## Decision

Each lesson states separately what is observable without a provider and what needs a session, and [VERIFIED.md](../VERIFIED.md) records the second set as unverified rather than implying it from the first.

## Consequences

- Boot-time claims — a plugin activated, a row composed, a service failed loudly — are cheap and testable offline, and carry most of the teaching value in the early lessons.
- Session-dependent claims accumulate in a backlog instead of being quietly assumed. See the verification backlog in [VERIFIED.md](../VERIFIED.md).
- Some lessons cannot be fully verified in this project's development environment. That is recorded as a fact about the project, not hidden.

## Evidence

Every lesson's `VERIFIED.md` row names its gaps explicitly, and each lesson has a "Requires a session, and therefore a provider" list distinct from its offline checks.
