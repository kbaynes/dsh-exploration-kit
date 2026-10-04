---
type: ADR
title: "ADR-0018 — A pristine install must exit 0, and pnpm 11 requires build approval for that"
description: A pristine install must exit 0, and pnpm 11 requires build approval for that.
status: Accepted
timestamp: 2026-10-02
---

# ADR-0018 — A pristine install must exit 0, and pnpm 11 requires build approval for that

## Status

Accepted

## Context

A publication dry run — exporting the committed tree and following the README from
scratch — found that `pnpm install` **exits 1** on a pristine checkout:

```
[ERR_PNPM_IGNORED_BUILDS] Ignored build scripts: esbuild@0.21.5

Run "pnpm approve-builds" to pick which dependencies should be allowed to run scripts.
```

Three things made this worse than it looks:

1. **The install still populates `node_modules`.** A developer who runs `pnpm install`
   and then `pnpm run build` sees everything work, and the non-zero exit goes unnoticed.
2. **CI would have failed on the first run.** GitHub Actions treats a non-zero exit as
   a failed step, so the difference between "works locally" and "works" would have
   surfaced publicly rather than here.
3. **The second dependency root failed separately.** The bundle's install
   (`pnpm --dir kit-plugins install`) does not inherit the repository root's pnpm
   settings, so fixing one root did not fix the other.

The setting is not guessable. Neither `ignoredBuiltDependencies`, `neverBuiltDependencies`,
nor `onlyBuiltDependencies` — in `.npmrc` or in `pnpm-workspace.yaml` — silenced it.
`dangerouslyAllowAllBuilds: true` did, but it approves *every* dependency's build script
to solve a problem with exactly one.

## Decision

`pnpm-workspace.yaml` approves the build **by name**, in both dependency roots:

```yaml
allowBuilds:
  esbuild: true
```

This is the form pnpm 11 itself generates when you run `pnpm approve-builds`. It is
narrow (one package), explicit (a reader can see what is approved and why), and
verified from a pristine tree twice in a row.

A pristine `pnpm install` must exit 0. That is now part of the publication dry run.

## Consequences

- A reader following the README from a clean clone gets exit 0, so a real failure in a
  later step is not masked by a known-broken first step.
- esbuild's postinstall runs. It is the standard platform-binary fetch, and the
  alternative was leaving every consumer's install exit code broken.
- The approval must be repeated for any future dependency root, because settings do not
  propagate across roots. The two files carry a comment saying so.
- `scripts/check-units.mjs` still explains a missing `kit-plugins/node_modules`
  distinctly, since that is a different failure (a root that was never provisioned).

Rejected: tolerating the non-zero exit in `setup` by inspecting the log. It would hide
the next, real install failure behind the same suppression.

## Evidence

The dry run — `git archive HEAD` into an empty directory, `pnpm run setup`, then
`pnpm run check:kit` — now reports `setup exit=0` and `8 passed, 0 failed` for the checks
that need no DSH checkout. Before this change the same procedure failed at the install.
