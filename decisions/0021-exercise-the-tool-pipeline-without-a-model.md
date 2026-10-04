---
type: ADR
title: "ADR-0021 — Policy decisions are verifiable without a model, and the denying layer must be identified"
description: Policy decisions are verifiable without a model, and the denying layer must be identified.
status: Accepted
timestamp: 2026-10-02
---

# ADR-0021 — Policy decisions are verifiable without a model, and the denying layer must be identified

## Status

Accepted

## Context

Lesson 4's central claim — a write outside the configured root is denied, and a write
inside is not — was recorded as needing a model tool call, and therefore as unverified.
That put the lesson's most important assertion permanently out of reach in this
environment, along with L4's claim that its gate discriminates rather than blocking
everything.

It does not need a model. `ctx.tools.execute()` accepts a caller-supplied call and runs
the **same pipeline a model-direct call runs** — pre-execute policy, registered guards,
dispatch. A plugin can therefore dispatch a synthetic call and observe the decision.

Two traps made the first attempt misleading rather than simply broken:

1. **`signal` is required.** Omitting it fails with
   `Cannot read properties of undefined (reading 'aborted')`, which reads like a registry
   bug rather than a missing field.
2. **Reporting `isError` is not enough.** A denial from *any* policy layer looks identical
   to a denial from the gate being tested. The first run could not tell whether the
   lesson's gate, DSH's own filesystem sandbox, or something else had refused.

## Decision

Policy plugins in this kit are verified without a provider by a probe that:

- dispatches synthetic calls through `ctx.tools.execute()` with a real `AbortSignal`;
- **classifies the denying layer by the reason string**, not by `isError` alone — so a
  result is `GATE-DENIED`, `OTHER-DENIED`, or `ALLOWED`;
- asserts both enforcement *and* discrimination, because a gate that denies everything
  passes an enforcement-only check.

The probe ships as an opt-in diagnostic (`disabled: true` in the bundle) since it
dispatches real calls, and `solutions/verify-l4.sh` runs it.

Tool argument names must be taken from the tool, not assumed: dsh's filesystem tools take
`file_path`, and passing `path` is rejected by argument validation *before* any policy
runs — which is easy to misread as the gate working.

## Consequences

- L4 moves from "decisions need a provider" to verified, including the defense-in-depth
  observation: the inside write is **not** denied by the gate, and is then stopped by
  DSH's own sandbox because the target sits outside the agent's workspace.
- The technique generalises: any policy plugin in this kit can be verified the same way,
  which is why the probe is a shipped file rather than a one-off script.
- A probe dispatches real calls, so it is opt-in and its output paths are git-ignored.

## Evidence

`bash solutions/verify-l4.sh <checkout>` now reports:

```
PASS  a write outside the root is denied BY THE GATE
PASS  an inside write is not denied by the gate (verdict: OTHER-DENIED)
        it was stopped by a SECOND policy layer (DSH's own filesystem sandbox)
```

Recorded in [VERIFIED.md](../VERIFIED.md) under "Evidence: L4's gate decisions executed".
