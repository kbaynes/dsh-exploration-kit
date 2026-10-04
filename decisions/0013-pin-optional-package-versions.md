---
type: ADR
title: "ADR-0013 — Pin optional DSH package versions; npm's `latest` tag is stale"
description: Optional DSH packages publish a stale `latest` tag, so an unpinned install resolves an incompatible version that dsh rejects.
status: Accepted
timestamp: 2026-10-01
---

# ADR-0013 — Pin optional DSH package versions; npm's `latest` tag is stale

## Status

Accepted

## Context

Lesson 7 needs an optional package that no shipped bundle mounts. The obvious install
is the one a reader would type:

```sh
dsh plugin --profile kitdemo add @deepseek-ai/dsh-tool-session-query
```

It fails, and the failure is misleading:

```
dsh: installation rejected: Plugin @deepseek-ai/dsh-tool-session-query@0.0.1-rc.1 is
incompatible with dsh 0.2.0-rc.2: peerDependencies {"@deepseek-ai/dsh-tools":"^0.0.1-rc.1", ...}
```

There is nothing wrong with the package. Its npm `dist-tags.latest` is simply stale:
`0.0.1-rc.1`, while published versions run up to `0.2.0-rc.2` — the one matching the
release under test. pnpm resolves `latest` by default, so the reader gets an ancient
version and a compatibility rejection that reads like a version conflict with the
*harness*.

Verified against the registry for `@deepseek-ai/dsh-tool-session-query`,
`@deepseek-ai/dsh-session-query-sqlite`, and `@deepseek-ai/dsh-invariants`: all three
report `latest: 0.0.1-rc.1` and list `0.2.0-rc.2` among their versions.

## Decision

Every install of an optional DSH package names an explicit version matching the dsh
release under test:

```sh
dsh plugin --profile kitdemo add @deepseek-ai/dsh-tool-session-query@0.2.0-rc.2
```

The version lives in one place — [VERIFIED.md](../VERIFIED.md) "Tested against" — and
`solutions/verify-l7.sh` asserts the profile manifest carries it.

## Consequences

- The recommendation is a **tracking obligation**: when the kit moves to a new DSH
  release, the pinned versions move with it, in the same pass that re-verifies the
  lessons.
- A reader who omits the version gets a confusing rejection. The lesson quotes the
  exact message so it is recognisable.
- Optional packages installed this way are plain dependencies, not profile layers —
  dsh says so at install time (`declares no dsh.bundle`). Installing the package makes
  its code resolvable; a *row* is what mounts it.

Rejected alternative: `--accept-risk` / `allow-version`, which dsh offers. Accepting a
version the runtime has declared incompatible, in a teaching repository whose entire
value is that its instructions work, is the wrong trade.

## Evidence

[VERIFIED.md](../VERIFIED.md) "Evidence: L7 composes and activates" records the
rejection, the registry versions, the successful pinned install, and a boot with zero
activation warnings.
