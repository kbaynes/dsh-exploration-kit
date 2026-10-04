---
type: ADR
title: "ADR-0009 — Environment-specific paths come from configuration at load time"
description: Environment-specific paths come from configuration at load time.
status: Accepted
timestamp: 2026-10-01
---

# ADR-0009 — Environment-specific paths come from configuration at load time

## Status

Accepted

## Context

The first version of the Lesson 4 policy gate computed its confinement root as
`resolve(process.cwd(), 'kit-plugins/l4/sandbox')`. The dsh process runs from the
*checkout*, not the kit, so the guard silently defended a directory nobody would write
to — a policy that looked correct and enforced nothing.

The same class of error nearly recurred when an absolute path was about to be committed
into `solutions/l5.skills.patch.yml`. It would have been correct on exactly one machine.

## Decision

No absolute environment path is committed. The bundle row computes it at load time with
`!!js` from an environment variable:

```yaml
      config:
        allowedRoot: !!js "process.env.KIT_ROOT ? process.env.KIT_ROOT + '/l4-sandbox' : undefined"
```

`solutions/l5.skills.patch.yml` uses the same `KIT_ROOT` convention.

## Consequences

- A reader supplies one variable rather than editing tracked files, and nothing
  machine-specific enters git history.
- The `undefined` branch falls back to the plugin's own default, so a missing variable
  degrades rather than crashing — which means the plugin must **print the resolved
  path** so the reader can see which tree it chose.
- `!!js` is evaluated for `config` and `disabled` only; other entry metadata stays
  literal. `--dump-config` prints the expression unevaluated, so the printed path is
  the only way to see the value.

Rejected alternative: a path relative to `process.cwd()`. It is silently wrong whenever
the process starts somewhere other than the kit.

## Evidence

[VERIFIED.md](../VERIFIED.md) "Evidence: L4 plugins load (decisions unverified)" shows
the resolved root.
