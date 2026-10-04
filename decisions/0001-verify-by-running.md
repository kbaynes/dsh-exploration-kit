---
type: ADR
title: "ADR-0001 — Verify a mechanism by running it before teaching it"
description: Verify a mechanism by running it before teaching it.
status: Accepted
timestamp: 2026-10-01
---

# ADR-0001 — Verify a mechanism by running it before teaching it

## Status

Accepted

## Context

Teaching a mechanism from documentation is not evidence that it works. Twice in this project a lesson was written from authoritative-looking sources and would have failed for every reader.

- The kit taught loading lesson plugins by pointing a `--patch` overlay at a loose file. That works only for a plugin importing nothing from dsh. The first plugin that imported `@deepseek-ai/dsh-tools` failed to load, and **every** lesson depended on the broken mechanism.
- Lesson 3 documented importing `FiberState` because the upstream Cordis tutorial shows it. It is not a runtime export (see [ADR-0006](0006-fiberstate-is-erased.md)).

Both were invisible to reading and obvious to running.

## Decision

Every mechanism a lesson teaches is executed before the lesson text is written. Where execution is impossible because a claim needs a model provider, the lesson says so explicitly and the claim is recorded as unverified in [VERIFIED.md](../VERIFIED.md).

## Consequences

- Writing time goes up: the first plugin was built, booted, and debugged before its lesson existed.
- Some claims stay honestly unverified for a long time. That is preferred over a lesson that reads confidently and fails.
- The verification ledger becomes a first-class artifact rather than a formality, and it must distinguish *designed*, *documented*, and *executed*.

Rejected alternative: write all nine lessons from the docs first, then test. Cheaper up front, and it produced the broken bundle mechanism described above — which would have shipped to readers who would then have concluded the harness was at fault.

## Evidence

The bundle pivot is recorded with quoted output in [VERIFIED.md](../VERIFIED.md) under "Design pivot". Lesson 3's `FiberState` finding is under "Two upstream-tutorial traps found by running it".
