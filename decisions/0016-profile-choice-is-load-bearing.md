---
type: ADR
title: "ADR-0016 — Which profile a row is applied to decides whether it activates"
description: Which profile a row is applied to decides whether it activates.
status: Accepted
timestamp: 2026-10-01
---

# ADR-0016 — Which profile a row is applied to decides whether it activates

## Status

Accepted

## Context

An inserted row does not activate merely because it composes. Two `PENDING` failures
were observed while building Lesson 9, on the base-backed `kitdemo` profile:

```
schedule (@deepseek-ai/dsh-schedule): pending (waiting for service: sessionController)
webhook  (@deepseek-ai/dsh-webhook): pending (waiting for services: agentPresets, workspaceRegistry)
```

Neither package is broken. Their required services come from the **web** bundle, and a
base-backed profile does not mount them. The same overlay on a web-backed profile
activated both with no warnings at all.

The failure mode is quiet: the rows compose, `--dump-config` shows them, and only the
startup summary mentions that they did not activate.

## Decision

A lesson that depends on a capability states **which profile** it targets, and installs
into that profile. Where a capability needs services from a specific bundle, the lesson
names the required service and the profile that provides it.

The kit's base-backed development profile (`kitdemo`) stays the default for lessons that
only need the base bundle; Lesson 9 uses a web-backed profile and says so.

## Consequences

- Lesson 9's prerequisites now name the profile, and both packages are installed into
  `web` rather than `kitdemo`.
- The `PENDING` symptom is taught as Lesson 3's mechanism appearing in a real
  composition, which is a better illustration than the contrived one it has in L3.
- `solutions/verify-l9.sh` asserts zero activation warnings **on a web profile**, so
  applying the overlay to the wrong profile fails the check.
- A reader who installs into the wrong profile sees a clean compose and a silent
  non-activation. The lesson quotes the exact message so it is recognisable.

## Evidence

[VERIFIED.md](../VERIFIED.md) "Evidence: L9 opt-in packages compose and activate" quotes
both PENDING messages and the clean web-profile boot.
