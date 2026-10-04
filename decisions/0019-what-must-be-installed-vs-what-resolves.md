---
type: ADR
title: "ADR-0019 — A row resolves against the installation; only missing packages need installing"
description: A row resolves against the installation; only missing packages need installing.
status: Accepted
timestamp: 2026-10-02
---

# ADR-0019 — A row resolves against the installation; only missing packages need installing

## Status

Accepted

## Context

Two opt-in lessons insert rows for packages that no shipped bundle mounts, and the
obvious conclusion is that both need installing. That conclusion is half right, and the
half that is wrong would send a reader through an unnecessary `dsh plugin add`.

Verified by experiment: the Lesson 7 overlay was applied to a **fresh** profile that had
never installed anything. The two `invariants` rows resolved and activated; only
`tool-session-query` failed:

```
tool-session-query (@deepseek-ai/dsh-tool-session-query): failed to import
```

`@deepseek-ai/dsh-invariants` is not even a dependency of the base bundle, yet its row
resolved. The mechanism is that a row's name resolves against the **running
installation's own package tree**, and the lessons require a source checkout, whose
workspace provides that tree.

This corrected an earlier over-generalisation in the kit's own lesson text, which had
said both packages "must be installed as well as inserted".

## Decision

The rule the lessons teach:

- A row naming a package the running dsh installation already contains **resolves**. No
  install is needed — only the row.
- A row naming a package the installation does **not** contain must be installed first
  (`dsh plugin add`, pinned per [ADR-0013](0013-pin-optional-package-versions.md)), or it
  fails to import.

Whether a given package is in the installation is answered by inspecting the
installation, not by whether a shipped bundle mounts it: mounting and presence are
different questions, which is [ADR-0015](0015-capability-tools-may-be-unmounted.md)'s
subject.

## Consequences

- Lesson 7 no longer tells a reader to install `dsh-invariants`; it explains why that
  one resolves and the query tool does not.
- An npm-installed dsh may have a different package tree from a source checkout. All
  verification here is against a source checkout — which the kit's prerequisites require
  anyway — so this is recorded rather than generalised.
- The failure signature stays the same either way, and the lessons quote it:
  `failed to import` means the row names a package the profile cannot resolve.

## Evidence

[VERIFIED.md](../VERIFIED.md) "Evidence: L7 composes and activates" records the fresh
profile experiment: the invariants rows resolved, the uninstalled query tool did not.
