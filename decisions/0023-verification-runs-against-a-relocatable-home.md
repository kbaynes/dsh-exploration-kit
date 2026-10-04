---
type: ADR
title: "ADR-0023 — Verification honours DSH_HOME, so it never has to touch the real harness home"
description: Verification honours DSH_HOME, so it never has to touch the real harness home.
status: Accepted
timestamp: 2026-10-02
---

# ADR-0023 — Verification honours DSH_HOME, so it never has to touch the real harness home

## Status

Accepted

## Context

The verification scripts boot `dsh`, which writes its composed profile under `$DSH_HOME`. In this workspace the harness home is `~/.dsh`, which sits **outside the session's writable root**, so every verification run needed an explicitly widened sandbox and therefore a human approval prompt each time.

The sandbox model offers no middle path: the modes are `read-only`, `workspace-write`, and `danger-full-access`, and `workspace-write`'s entire writable decision is

```ts
// packages/sandbox/sandbox/src/roots.ts
return [...new Set([policy.workspaceRoot, '/tmp', tmpdir()].map(canonicalPath))]
```

— one root plus the temp areas, with no allowlist for an extra directory such as `~/.dsh`.

Three scripts also read the profile manifests by literal path (`$HOME/.dsh/profiles/...`), so a relocated home would not have worked even where `dsh` itself honoured the variable.

## Decision

The kit honours `${DSH_HOME:-$HOME/.dsh}` everywhere it reads harness state, and verification is documented to run against a **relocatable** home:

```sh
export DSH_HOME=/tmp/dsh-verify
bash scripts/setup-verify-profiles.sh
DSH_CHECKOUT=/path/to/deepseek-harness pnpm run check:kit
```

`/tmp` is writable under `workspace-write`, so this needs **no sandbox relaxation and no approval prompt**, while leaving the maintainer's real `~/.dsh` untouched — which is also better hygiene: verification should not mutate the harness state a person uses.

## Consequences

- The full suite was executed unelevated under a relocated home: **18 passed, 0 failed**, with `dsh` booting, creating sessions, and composing profiles entirely under `/tmp`.
- Verification is now non-invasive by default rather than by discipline. A run cannot pollute the real profiles' pins or sessions.
- The relocated home is ephemeral, which is correct for verification: each run begins from a known-empty profiles tree, so a stale profile cannot silently make a check pass.
- `DSH_HOME` must be exported rather than passed per-command, because the lesson scripts invoke `dsh` themselves.

Rejected: switching the session to `danger-full-access`. It works, but it relaxes confinement for everything the agent does in order to solve a problem about where one tool writes its state.

## Evidence

[VERIFIED.md](../VERIFIED.md) "CI workflows" and the README's checks section record the relocated-home invocation; the 18/18 unelevated run is recorded in the round's commit.
