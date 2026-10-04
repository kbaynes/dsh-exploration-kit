---
type: ADR
title: "ADR-0012 — The curriculum, the bundle, and examples are one source of truth"
description: The curriculum, the bundle, and examples are one source of truth.
status: Accepted
timestamp: 2026-10-01
---

# ADR-0012 — The curriculum, the bundle, and examples are one source of truth

## Status

Accepted

## Context

Three copies of a lesson's code can exist: the text in the lesson, the file in the
bundle that actually boots, and a copy in `examples/` for readers. A hand-maintained
copy drifts, and a lesson whose text disagrees with the booting code is wrong in a way
nobody notices until a reader hits it.

The same problem appears at the content level: the site must not re-render from a second
copy of `content/`.

## Decision

`kit-plugins/` is canonical because it is what boots. `examples/` is **generated** from
it by `scripts/sync-examples.mjs`, with a `--check` mode wired into CI and into
`pnpm run check:examples`. The VitePress site reads `content/` in place via `srcDir`.
Root documents are copied into the bundle at build time by `scripts/sync-site-docs.mjs`
rather than duplicated.

## Consequences

- A drift between lesson text and runnable code becomes a failing check instead of a
  support request.
- `examples/` must never be edited directly; the generated copy carries a banner saying
  so.
- VitePress refuses links that escape its source root, which is why root documents are
  synced in rather than linked across the boundary.
- **A synced root document cannot link relatively to anything outside `content/`.** Its
  copy sits inside the site root, so `decisions/README.md` resolves to
  `content/decisions/README.md`, which does not exist. This broke the build three
  times — twice in `VERIFIED.md`, once in `CONTRIBUTING.md` — and the fix is always the
  same: a synced root document references the ADR corpus by **absolute repository URL**.
  Documents that are not synced (`AGENTS.md`, `README.md`) may link relatively.

That last point is the kind of rule that is obvious once stated and invisible three
times in practice, which is why it is written down here instead of being rediscovered.

### Self-referencing absolute URLs are links too

Making synced documents use absolute repository URLs created a blind spot: every check
treated `https://github.com/<owner>/<repo>/blob/main/...` as external and skipped it, so
a self-link to a file that does not exist checked green. Two further gaps surfaced while
fixing that:

- `check-links.mjs` only scanned `content/`, so **root-level documents were never
  checked at all** — `README.md` could link anywhere.
- Its path resolution mixed a relative `root` with an absolute `import.meta.dirname`,
  so the repository identity was read from the wrong directory and self-URL detection
  never ran.

Now: the checker scans root documents as well as the bundle, resolves a self-URL to its
local path, and reports it like any other link — *scoped to this repository's identity*
from `package.json`'s `kit` field. Scoping matters: an unscoped pattern makes every
upstream DSH vendor link look broken, which is exactly what the first attempt did.

The publication step is therefore a single edit to `kit.repositoryOwner`, not a
find-and-replace across the repository.

Rejected alternative: hand-maintaining `examples/`. It is the kind of copy that looks
fine for a month and then quietly lies.

## Evidence

`pnpm run check:examples` passes and is enforced in
[`.github/workflows/site.yml`](../.github/workflows/site.yml).
