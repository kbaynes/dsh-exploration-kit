---
type: ADR
title: "ADR-0026 — A find-and-replace must not rewrite the files that define the token"
description: A find-and-replace must not rewrite the files that define the token.
status: Accepted
timestamp: 2026-10-02
---

# ADR-0026 — A find-and-replace must not rewrite the files that define the token

## Status

Accepted

## Context

`PUBLISHING.md` step 2 told publishers to replace the repository owner with a blanket substitution:

```sh
grep -rl 'REPLACE_OWNER' --exclude-dir=node_modules . | xargs sed -i '' 's/REPLACE_OWNER/<owner>/g'
```

Tested in a clean export, it makes publication **impossible**. The command rewrites `scripts/check-placeholders.mjs`, whose token list is the definition of "placeholder", so the checker then looks for the *real owner* and reports all 37 genuine URLs as unfinished:

```
$ grep -rl ... | xargs sed -i '' 's/REPLACE_OWNER/exampleuser/g'
$ node scripts/check-placeholders.mjs
37 placeholder occurrence(s) must be replaced before publishing:
  package.json:32  [exampleuser]
      "repositoryOwner": "exampleuser",
```

It also rewrote `PUBLISHING.md` itself, so the runbook then described "the single token `exampleuser`" — instructions that had already been executed and no longer made sense.

The same class of hazard is familiar from [ADR-0022](0022-event-payloads-are-objects-and-silent-catches-hide-that.md): a step that damages the thing that would have caught the damage.

## Decision

The substitution **excludes the files whose purpose is to name the token**, and `check-placeholders.mjs` skips them when scanning:

```sh
grep -rl 'REPLACE_OWNER' --exclude-dir=node_modules --exclude-dir=.git . \
  | grep -vE '^(\./)?(PUBLISHING|PLAN)\.md$' \
  | grep -vE '^\./scripts/check-(placeholders|publication)\.mjs$' \
  | grep -vE '^\./decisions/0026-' \
  | grep -vE '^\./website/\.vitepress/' \
  | xargs sed -i '' 's/REPLACE_OWNER/<your-github-owner>/g'
```

`PUBLISHING.md` is the runbook; `PLAN.md` records the substitution as a task; the two scripts define and enforce the vocabulary. None of them is an owner-bearing artifact, and scanning them for the token would make "ready to publish" unreachable.

## Consequences

- The substitution has a file list, not a global reach. That is the point: a global find-and-replace across a repository containing its own tooling is a footgun.
- Every artifact that *does* carry the owner — `package.json`, the lessons, `VERIFIED.md`, `README.md`, `CONTRIBUTING.md`, `THIRD-PARTY.md`, the issue templates — is still substituted and still scanned, so the gate keeps its teeth.
- **The exclusion list is part of the mechanism, and it grows.** Two more definition sites were found when the substitution was finally run for real:
  - **This ADR quotes the recipe**, so it too defines the token. Rewriting it would have left the
    record showing the real owner where it documents `<owner>` — the same self-rewriting failure
    described above, in a file written *after* the rule against it.
  - **`website/.vitepress/config.mts` holds the token only as a fallback sentinel**
    (`pkg.kit?.repositoryOwner ?? 'REPLACE_OWNER'`). Substituting it would make a fork with no
    owner configured silently point at this repository's owner. The site needs no substitution:
    it reads `package.json`. The earlier claim here that the VitePress config is substituted was
    wrong.
Both are now excluded from the command and exempted in `check-placeholders.mjs`'s `skipFiles` (the config directory is skipped wholesale), so the gate and the runbook agree.
- The runbook must be tested before it is trusted. This was found only by executing it in a clean export, which is the same rule the curriculum applies to every mechanism it teaches ([ADR-0001](0001-verify-by-running.md)) and which had not been applied to the publication procedure itself.

## Evidence

An export of the working tree, substituted with a fake owner, then checked: `check:placeholders` **passes** (it exited 1 before the fix, listing the real owner as a placeholder), `check:links` reports no broken internal links, `check:synced-links` is clean, `check:target` reports the records agree, the site builds, and the substituted owner appears in 18 built HTML files with no placeholder left in the output.
