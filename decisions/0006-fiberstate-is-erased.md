---
type: ADR
title: "ADR-0006 — FiberState is a const enum and must not be imported at runtime"
description: FiberState is a const enum and must not be imported at runtime.
status: Accepted
timestamp: 2026-10-01
---

# ADR-0006 — FiberState is a const enum and must not be imported at runtime

## Status

Accepted

## Context

The upstream Cordis tutorial shows:

```ts
import { FiberState, type Context } from '@deepseek-ai/cordis'
```

That throws at load. `FiberState` is declared `export const enum`, which TypeScript erases at compile time, and the published `@deepseek-ai/cordis` does not export it as a runtime value. Verified directly:

```
$ node -e "import('@deepseek-ai/cordis').then(c => console.log(c.FiberState))"
undefined
```

An agent copying the tutorial into a plugin produces a plugin that cannot load.

## Decision

Compare the documented numeric state values instead of importing the enum, and say why in a comment. `kit-plugins/l3/diagnose.js` is the reference implementation.

The same trap applies to any `const enum` re-exported for typing: if it is not a value at runtime, a plugin cannot import it.

## Consequences

- The state numbers become a local contract. They are stable in the documented ordering, but a breaking change upstream would not be caught by a type error.
- The lesson records the discrepancy with the upstream tutorial, so a reader who finds the tutorial is not left thinking they made the mistake.
- `solutions/verify-l3.sh` asserts the import is absent, so the mistake cannot silently return.

## Evidence

[VERIFIED.md](../VERIFIED.md) "Two upstream-tutorial traps found by running it".
