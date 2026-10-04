---
type: ADR
title: "ADR-0003 — Lesson plugins ship as a dsh bundle, addressed by package name"
description: Lesson plugins ship as a dsh bundle, addressed by package name.
status: Accepted
timestamp: 2026-10-01
---

# ADR-0003 — Lesson plugins ship as a dsh bundle, addressed by package name

## Status

Accepted

## Context

A plugin row in a `--patch` overlay resolves its `name` relative to the patch file. A relative path to a loose source file cannot import dsh packages, because pnpm symlinks only *declared* dependencies, so `@deepseek-ai/dsh-tools` is unreachable from an arbitrary directory:

```
dsh: warning: 1 entry did not activate
l2-wordcount (.../wordcount.ts): failed to import
```

Reproduced both outside the checkout and from inside `packages/`, so it is module resolution rather than a path bug. It is also how every external dsh plugin works: third-party plugins are bundles installed into a profile.

## Decision

Lesson exercises live in `kit-plugins/`, a real dsh bundle declaring `dsh.bundle`, with rows named by package (`dsh-exploration-kit-plugins/l2/wordcount.js`). It is installed into a profile with `dsh plugin --profile <name> add link:<kit>/kit-plugins`.

## Consequences

- The bundle manifest must declare the dsh packages a plugin imports under both `peerDependencies` and `devDependencies`, so the running installation's copy wins at resolution time while local development still typechecks.
- Dependencies are pinned to the DSH release under test and bumped with each verification pass.
- `--patch` overlays remain useful for one thing: overriding an installed row's `config` in place. The lessons teach that use explicitly.

Rejected alternative: importing dsh packages by absolute path from a loose file. It works in one checkout, breaks everywhere else, and teaches nothing transferable.

## Evidence

[VERIFIED.md](../VERIFIED.md) "Design pivot" quotes the failure, the composed row, and the successful boot: `[l2-wordcount] ACTIVE — defaultUnit=lines`.
