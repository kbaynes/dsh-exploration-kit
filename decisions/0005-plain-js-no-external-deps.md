---
type: ADR
title: "ADR-0005 — Keep lesson plugins dependency-free at runtime"
description: Keep lesson plugins dependency-free at runtime.
status: Accepted
timestamp: 2026-10-01
---

# ADR-0005 — Keep lesson plugins dependency-free at runtime

## Status

Accepted

## Context

A curriculum is run on machines with no relationship to this repository. Every runtime import is something that can fail before the lesson starts, and every one must be declared in the bundle manifest and version-matched to the reader's harness.

## Decision

Lesson plugins import only what the harness itself guarantees: `@deepseek-ai/cordis` and the dsh packages being taught. No third-party libraries, utilities, or helpers.

## Consequences

- The bundle manifest stays small and auditable, so a version bump is a short list.
- A reader cannot be blocked by an unrelated dependency resolution failure.
- Convenience libraries cannot be used to make a lesson prettier. The lessons are about harness seams, and hand-rolling a few lines keeps the seam visible.

Exception: a lesson may import a package **because teaching that package is the point** — Schemastery in Lesson 2, Zod in Lesson 6. Then it is declared like any other dependency and pinned with the rest.

## Evidence

`kit-plugins/package.json` declares six dsh packages and nothing else. Lessons 2 and 3 use Schemastery precisely because schemas are the subject.
