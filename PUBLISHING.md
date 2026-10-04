# Publishing this kit

The runbook for taking this repository public. Everything here is either a one-line
edit or a command; nothing is a judgement call except the decisions listed at the end.

**The gate is `pnpm run check:publication`.** It refuses while anything below is
outstanding, so the sequence is: fix what it names, re-run it, repeat, then publish.

## 1. Choose the public owner and name

`dsh-exploration-kit` is the working name. If you keep it, the VitePress `base` path is
already correct (`/dsh-exploration-kit/`). If you change the name, update `build.base` in
[`website/.vitepress/config.mts`](website/.vitepress/config.mts) to match, or every asset
URL on the published site will 404.

## 2. Substitute the repository owner

The owner appears as the token `REPLACE_OWNER` in prose and in `package.json`. The **site
config needs no substitution** — `website/.vitepress/config.mts` derives the social link,
the per-page edit link, and the link-preview URL from `package.json`'s `kit.repositoryOwner`,
so the site follows one source. It holds the token only as a fallback sentinel, which must stay
(see the note below). Change the token everywhere else at once:

```sh
grep -rl 'REPLACE_OWNER' --exclude-dir=node_modules --exclude-dir=.git . \
  | grep -vE '^(\./)?(PUBLISHING|PLAN)\.md$' \
  | grep -vE '^\./scripts/check-(placeholders|publication)\.mjs$' \
  | grep -vE '^\./decisions/0026-' \
  | grep -vE '^\./website/\.vitepress/' \
  | xargs sed -i '' 's/REPLACE_OWNER/<your-github-owner>/g'
```

**The exclusions are not tidiness — they are required, and the list has grown twice.**
This document, `PLAN.md`, and `scripts/check-(placeholders|publication).mjs` are where the
token is *defined*: a blanket substitution rewrites the checker's own token list, after which
it reports the real owner as a placeholder and the gate can never pass. Two more
definition sites were found after the original test:

- **`decisions/0026-*.md` quotes the substitution recipe itself.** Rewriting it would leave the
  ADR showing `kbaynes` where it documents `<owner>`, quietly destroying the evidence for the
  rule it exists to record. That is the same self-rewriting failure the ADR is about,
  reappearing in a file written after it.
- **`website/.vitepress/config.mts` holds the token only as a FALLBACK**
  (`pkg.kit?.repositoryOwner ?? 'REPLACE_OWNER'`). It is a sentinel for a fork with no owner
  configured, not a placeholder for this repository's owner, so it must keep saying
  `REPLACE_OWNER` — otherwise a fork silently points at your account. The site config needs no
  substitution at all: it reads `package.json`'s `kit.repositoryOwner`.

Both files are also exempted in `scripts/check-placeholders.mjs`'s `skipFiles` (the config
directory is skipped wholesale), so the gate and the procedure now agree. The lesson is worth
stating plainly: **every new file that mentions the token becomes a definition site, and the
exclusion list is part of the mechanism, not documentation of it.**

Then confirm nothing is left:

```sh
pnpm run check:placeholders
```

That check exists because a published repository containing `REPLACE_OWNER` produces
broken links and a site pointing at a stranger's account.

**This procedure is tested**, not assumed: in a clean export with a fake owner, the gate
passes, the link checks are clean, the site builds, and the owner appears in the built HTML.
The exclusions above are what make it work — see
[ADR-0026](decisions/0026-a-substitution-must-not-rewrite-its-own-tooling.md).

## 3. Set the git author identity

The current history was authored by `DSH Exploration Kit <kit@example.invalid>`, which is
a placeholder so that no real identity was invented on your behalf. Rewrite it before the
first push — after the push it is permanent, and GitHub will never link those commits to
an account.

**Tested, non-interactive recipe** — rewrites every commit's author and committer in one
pass, using the identity in the environment:

```sh
GIT_AUTHOR_NAME="<Your Name>" GIT_AUTHOR_EMAIL="<you>@users.noreply.github.com" \
GIT_COMMITTER_NAME="<Your Name>" GIT_COMMITTER_EMAIL="<you>@users.noreply.github.com" \
GIT_SEQUENCE_EDITOR=: git rebase --root --exec 'git commit --amend --reset-author --no-edit'
```

Verified on this repository: all 43 commits came back with the new identity, `git status`
stayed clean, and the objects verify. The rebase leaves dangling objects, which is normal —
`git gc --prune=now` if you want them gone.

Alternative, if you would rather not preserve the development history at all — and for a
curriculum whose history is scaffolding, this is a defensible choice:

```sh
rm -rf .git && git init && git add -A
git -c user.name="<Your Name>" -c user.email="<you>@users.noreply.github.com" commit -m "Initial commit"
```

**Not recommended as written:** `git filter-repo` is the usual tool for this and it is **not
installed** on a stock machine (`command -v git-filter-repo` fails). It needs
`pip install git-filter-repo` first, which is another thing to go wrong before a first push.

`pnpm run check:publication` fails while the placeholder identity is still in the history,
which is what makes this step impossible to forget.

## 4. Repository description and topics

These decide whether anyone finds it, and they are not carried by the files. Set them in
the repository settings:

**Description** — must contain the unambiguous phrase *DeepSeek Harness*, because the
bare token `dsh` collides with hundreds of unrelated projects:

> A hands-on, nine-lesson curriculum for learning DeepSeek Harness by building real plugins.

**Topics** — [`.github/topics.txt`](.github/topics.txt) lists the intended set so it
survives a repository transfer.

## 5. Create the repository and push

```sh
git remote add origin git@github.com:<owner>/dsh-exploration-kit.git
git push -u origin main
```

## 6. Enable GitHub Pages

Settings → Pages → Build and deployment → **Source: GitHub Actions**. The workflow is
already committed and needs no secrets. Then confirm the run succeeded and that the
published URL matches the `base` path from step 1.

## 7. Tag the release against its harness state

See [VERIFIED.md](VERIFIED.md#harness-state-this-kit-targets) and
[PLAN.md](PLAN.md) Phase 4.5. The tag records which DeepSeek Harness commit the lessons
were verified against:

```sh
git tag -a 'v0.1.0+dsh.0.2.0-rc.2.g639ed01539' -m 'Verified against DeepSeek Harness 0.2.0-rc.2
commit 639ed015397290b3745d163aafe02ffee4aa3f84, captured 2026-10-01'
git push origin --tags
```

## 8. Promote

- Announce in the DeepSeek Harness GitHub Discussions and Discord.
- Submit to the community plugin registry (`awesome-dsh-plugin` /
  `dsh-plugin-catalog`).
- The npm keywords in `package.json` are already set; they matter if you later publish a
  package.

Promote only after `pnpm run check:kit` passes in full. A curriculum that does not run
generates exactly the wrong kind of attention.

## Decisions still open

| Decision | Options | Default taken |
|---|---|---|
| Public repository name | `dsh-exploration-kit` / something else | Kept |
| Curriculum history | `content/log.md` (OKF) vs `CHANGELOG.md` | `content/log.md`; no second changelog |
| npm package | none / thin wrapper | None — deferred until the content is proven |
| Support channel | Issues only / Discussions too | Issues, with two templates |
| L4 offline verification | provider / PTC / reload-based | Documented as needing a call |
| Publish L8 cost numbers | yes / no | Not yet measured |
