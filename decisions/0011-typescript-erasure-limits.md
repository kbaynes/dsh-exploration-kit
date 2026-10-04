---
type: ADR
title: "ADR-0011 — Load .ts lesson plugins only for type-only imports"
description: Load .ts lesson plugins only for type-only imports.
status: Accepted
timestamp: 2026-10-01
---

# ADR-0011 — Load .ts lesson plugins only for type-only imports

## Status

Accepted

## Context

Lesson 1's plugin is a `.ts` file and loads successfully, which invites a wrong
generalisation that dsh handles TypeScript. Node **erases** types without checking them;
there is no type checker in the boot path. That is sufficient for
`import type { Context }`, which erasure removes entirely — and would fail for an
`enum`, a decorator, parameter properties, or a type-only export consumers rely on.

## Decision

Only a plugin whose TypeScript is **entirely** erasable may ship as `.ts`, and the
lesson must say so. Everything else is plain `.js`, so that what runs is what the reader
wrote with no transpile gap between the two.

## Consequences

- Readers see no build step, which keeps the early lessons approachable.
- The `.ts` lesson is a deliberate, documented special case rather than a precedent.
- Type safety in the lessons comes from the harness's published types, exercised by a
  reader's editor — not from compiling the kit.

## Evidence

Lesson 1 step 3 states the rule and its limit. Every other lesson plugin is `.js`; the
`examples/` mirror and the bundle both contain exactly one `.ts` file.
