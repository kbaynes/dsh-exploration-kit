---
type: ADR
title: "ADR-0017 — The harness state has one source of truth, and a gate holds the rest to it"
description: The harness state has one source of truth, and a gate holds the rest to it.
status: Accepted
timestamp: 2026-10-01
---

# ADR-0017 — The harness state has one source of truth, and a gate holds the rest to it

## Status

Accepted

## Context

The harness version and commit are necessarily written in several places, because each serves a different reader:

- `VERIFIED.md` — the ledger heading
- `README.md` — the compatibility note
- `ROADMAP.md` — the status banner
- `PLAN.md` — the tag-format example
- `kit-plugins/package.json` — the pinned dependencies
- `solutions/verify-l7.sh`, `verify-l9.sh` — the default version

A survey when this was first checked found the version or commit in **eight** independent locations. Every one is a claim about what was verified, so a drift between any two of them is a false claim — and drift is invisible until someone reads two of them side by side.

## Decision

`kit.target.json` is the single source of truth for the harness state. It records the version, upstream tag, full commit and its abbreviation, branch, capture date, profile names, pinned opt-in packages, and the toolchain versions.

`scripts/check-target.mjs` holds every other record to it, and `scripts/verify-target.sh` asserts the live profiles actually carry the pinned packages. Both run in `check:kit` and in CI.

The check distinguishes **bundle dependencies** (what the kit's own plugins import) from **profile-installed packages** (what a lesson overlay mounts). A first version of this check confused the two and wrongly reported the opt-in packages as un-pinned; the distinction is now enforced in both directions, so a future reader cannot "fix" the manifest by adding dependencies the kit does not use.

## Consequences

- Moving to a new harness version is one edit plus re-verification, and any record left behind fails loudly and names itself.
- A record cannot be updated in isolation. That is the point: the failure mode being prevented is exactly a partial update.
- The check needs a checkout to validate live state, so it reports the two modes distinctly rather than pretending to have checked what it could not reach.
- The gate was verified by injecting a drift (`commitShort` -> `deadbeef0`) and confirming it failed, naming `PLAN.md` as the disagreeing record. Shipping a gate without proving it fires would repeat the mistake it exists to prevent.

Rejected alternative: generating the prose records from the config. The ledger's rows carry human judgement about what was executed, which is not derivable from a version string. Holding the records to a shared source is the right amount of automation.

## Evidence

`pnpm run check:target` passes; the injected-drift probe failed with `PLAN tag example — PLAN.md does not contain "+dsh.0.2.0-rc.2.gdeadbeef0"`.
