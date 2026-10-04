---
type: ADR
title: "ADR-0008 — Declare every context service with inject"
description: Declare every context service with inject.
status: Accepted
timestamp: 2026-10-01
---

# ADR-0008 — Declare every context service with inject

## Status

Accepted

## Context

A plugin that touches `ctx.tools` without declaring it fails at load:

```
l4-guard (dsh-exploration-kit-plugins/l4/guard.js): Error: cannot get property "tools" without inject
```

Context services are not ambient. `inject` is what makes a service available, and it is
also what orders loading: a plugin waits in `PENDING` until its dependencies exist. The
failure mode when `inject` is missing is unambiguous; the failure mode when the
*dependency* is missing is quiet by design (see
[ADR-0010](0010-separate-what-a-boot-proves.md)).

## Decision

Every plugin declares the services it uses: `export const inject = ['tools']`,
`['commands']`, `['agents']`, `['sessionProjections']`. A plugin needing an optional
service uses `ctx.inject([...], callback)` rather than touching the key optimistically.

## Consequences

- Load order comes from declared dependencies, never from position in the config file.
- Removing a provider strands its consumers in `PENDING`, which the Lesson 3 diagnostic
  makes visible rather than mysterious.
- A plugin cannot quietly depend on a service that happens to be present in one
  composition; the declaration is the contract.

## Evidence

[VERIFIED.md](../VERIFIED.md) "Evidence: L4 plugins load (decisions unverified)" quotes
the failure and the fix.
