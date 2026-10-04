---
type: ADR
title: "ADR-0002 — Never cite upstream documentation paths without checking them"
description: Never cite upstream documentation paths without checking them.
status: Accepted
timestamp: 2026-10-01
---

# ADR-0002 — Never cite upstream documentation paths without checking them

## Status

Accepted

## Context

The kit links to DeepSeek Harness documentation by absolute GitHub URL so it works standalone. Fourteen such links pointed at paths that **do not exist upstream** — every `docs/harness/*` and `docs/operations/*` link.

The cause is subtle and repeatable: those paths came from a *workspace knowledge bundle* whose concepts are authored at virtual paths. The real DSH repository has no `docs/harness/` or `docs/operations/` directory at all. A plausible-looking path is exactly the kind of thing an author cannot tell apart from a real one.

## Decision

Upstream links are verified against a real checkout before being committed, by `scripts/check-upstream-links.mjs`. A path that does not resolve in the checkout fails the check.

## Consequences

- An upstream link must resolve to a file that exists, or the reference is reworded rather than linked. Five `docs/operations/*` references had no counterpart anywhere and became prose.
- The check needs a checkout, so it is a maintainer check and cannot run in CI. CI covers internal links; a human or agent with a checkout covers upstream ones.
- Documentation paths are not a stable API. Expect to re-verify each DSH release.

Rejected alternative: trusting a link because it reads plausibly. It produced fourteen 404s in one pass.

## Evidence

`solutions/verify-l2.sh` and friends assert what they can locally; `pnpm run check:upstream <checkout>` is what catches this class. The fourteen paths are listed in [PLAN.md](../PLAN.md) under the audit register.
