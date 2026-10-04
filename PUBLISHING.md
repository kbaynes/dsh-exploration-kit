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

The owner appears as the single token `REPLACE_OWNER` in a handful of files. Change it
everywhere at once:

```sh
grep -rl 'REPLACE_OWNER' --exclude-dir=node_modules . | xargs sed -i '' 's/REPLACE_OWNER/<your-github-owner>/g'
```

Then confirm nothing is left:

```sh
pnpm run check:placeholders
```

That check exists because a published repository containing `REPLACE_OWNER` produces
broken links and a site pointing at a stranger's account.

## 3. Set the git author identity

The current history was authored by `DSH Exploration Kit <kit@example.invalid>`, which is
a placeholder so that no real identity was invented on your behalf. Rewrite it before the
first push — after the push it is permanent, and GitHub will never link those commits to
an account.

```sh
git rebase -i --root          # mark every commit 'edit', then:
git commit --amend --reset-author --no-edit
git rebase --continue         # repeat for each commit
```

Or, if you would rather keep the messages and only fix authorship:

```sh
git filter-repo --email-callback 'return b"<you>@users.noreply.github.com"' \
                --name-callback 'return b"<Your Name>"'
```

`pnpm run check:publication` fails while the placeholder identity is still in the history.

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
