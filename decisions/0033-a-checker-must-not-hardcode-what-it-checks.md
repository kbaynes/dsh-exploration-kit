---
type: ADR
title: "ADR-0033 — A checker must not hardcode the value it is supposed to validate"
description: A checker must not hardcode the value it is supposed to validate.
status: Accepted
timestamp: 2026-10-03
---

# ADR-0033 — A checker must not hardcode the value it is supposed to validate

## Status

Accepted

## Context

Every DeepSeek Harness link in this kit pointed at `deepseek-ai/deepseek-harness/blob/main/...`. The repository's default branch is **`master`** — `origin/HEAD -> origin/master`, one branch, no `main` — so all 42 of those links were 404s. A reader reported it.

Three separate things had to be true for that to survive:

1. **The checker hardcoded the very value it was checking.** `scripts/check-upstream-links.mjs` opened by defining `prefix` as the literal string `https://github.com/deepseek-ai/deepseek-harness/blob/master/`, then searched each line for that exact prefix and validated only the *path* after it. A link naming `blob/main/...` never matched, so it was not checked at all — not "checked and passed" but invisible. A checker that embeds the expected answer cannot detect that the answer is wrong, and a code fence is not needed to make that point.

2. **The single source of truth already said `master`.** `kit.target.json` records `"branch": "master"` alongside the pinned commit and tag. Nothing read it: `check-target.mjs` and `verify-target.sh` both ignore the field. The correct value was written down, in the one file this repository calls authoritative ([ADR-0017](0017-one-source-of-truth-for-the-harness-state.md)), and had no gate.

3. **Two thirds of the file set were never scanned.** The old checker walked `content/` only, and stripped fenced code before scanning. `README.md`, `AGENTS.md`, `THIRD-PARTY.md` and `CONTRIBUTING.md` were out of scope entirely, and so was every URL shown inside a code fence — including the ones lessons put in front of a reader as real links.

The same failure shape as [ADR-0026](0026-a-substitution-must-not-rewrite-its-own-tooling.md): the check participates in the mechanism it is meant to police.

## Decision

A checker reads the value it validates from a source of truth, and fails when that value and reality disagree.

For every GitHub link in the kit, `scripts/check-upstream-links.mjs` now:

- **reads the expected upstream branch from `kit.target.json`** (`dsh.branch`), and cross-checks it against the checkout's actual branch, so a stale pin fails with `kit.target.json says "main", the checkout is on "master"` rather than silently redefining what "correct" means;
- **reads this repository's own branch from git**, so a self-link that names `main` when the repository is on `master` fails the same way — the mirror image of the bug reported here;
- **compares each link's branch with the expectation**, and reports every site that disagrees;
- **scans every markdown file in the repository**, fences included, skipping only generated and vendored trees. A lesson that shows a reader a URL must show a working one;
- **strips sentence punctuation** from a captured path and **skips documented URL forms** (`.../blob/master/...`, which names no real path) rather than flagging its own prose.

## Consequences

- The reported bug cannot recur silently: a wrong branch is now a named failure with the file and line, and the test was exercised in both directions (a deliberately reverted link fails; restoring it passes).
- The recorded `dsh.branch` finally has a consumer, which is what made it worth recording. A stale pin is now an error rather than a comment.
- Coverage roughly doubled: root docs and fenced URLs are checked for the first time. That immediately caught a self-link with a trailing period that the old punctuation-naive matcher would have mangled.
- The check is stricter than before in a way that could inconvenience a contributor: a URL inside an illustrative code fence must now be real. That is the intent — the alternative is a lesson that teaches a 404.
- **The general rule is now recorded rather than re-learned:** a validator must not contain the expected value as a literal, and a fact in the source of truth must have a consumer. Both failures here are instances of that.

## Evidence

The reported bug, and what the pin had been saying all along:

```
$ git -C <checkout> symbolic-ref refs/remotes/origin/HEAD
refs/remotes/origin/master

$ grep '"branch"' kit.target.json
    "branch": "master",

# 42 links, all invisible to the old checker because it searched for this exact prefix:
$ grep -rho 'deepseek-ai/deepseek-harness/blob/main/[^) ]*' --include=*.md . | wc -l
      42
```

Both failure modes, exercised deliberately:

```
$ sed -i '' 's|deepseek-harness/blob/master/|deepseek-harness/blob/main/|' README.md
$ pnpm run check:upstream
1 link(s) name the WRONG BRANCH — every one 404s:
  deepseek-ai/deepseek-harness/blob/main/docs/development.md
      should be "master", not "main"
      README.md:52

$ sed -i '' 's|"branch": "master"|"branch": "main"|' kit.target.json
$ pnpm run check:upstream
The pinned branch and the checkout disagree — one of them is stale:
  deepseek-ai/deepseek-harness: kit.target.json says "main", the checkout is on "master"
```

And the clean state, with the branch coverage stated in the output:

```
$ pnpm run check:upstream
checked 39 distinct GitHub link(s)
  deepseek-ai/deepseek-harness uses branch "master" (pinned; checkout has "master")
  kbaynes/dsh-exploration-kit uses branch "main"
  ignored: REPLACE_OWNER/dsh-exploration-kit (not this kit's repositories)
  ignored 2 documented URL form(s) that name no real path
every link resolves, and every link names the branch its repository uses
```
