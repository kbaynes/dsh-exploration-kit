---
type: ADR
title: "ADR-0038 — A command in this repository must run on Linux as well as macOS"
description: A documented command must run on Linux as well as macOS, because the platform-specific failure is silent.
status: Accepted
timestamp: 2026-10-06
---

# ADR-0038 — A command in this repository must run on Linux as well as macOS

## Status

Accepted

## Context

**The placeholder token is written `<placeholder>` throughout this record, never literally.** Spelling it out would make this ADR another *definition site* for it, which is what `scripts/check-placeholders.mjs` scans for — so the first draft of this record tripped the publication gate and blocked the very export it describes. That is the mechanism [PUBLISHING.md](../PUBLISHING.md) warns grows its exclusion list; the fix is to not add to the list. The commands below are otherwise the ones that were run.

The kit was developed on macOS and every shell command in it was written there. A reader following the publication procedure on Linux would have hit this line in [PUBLISHING.md](../PUBLISHING.md):

```sh
| xargs sed -i '' 's/<placeholder>/<your-github-owner>/g'
```

BSD `sed` (macOS) takes `-i` followed by a **separate** argument, the backup suffix, and `''` means "no backup". GNU `sed` (Linux) takes the suffix **attached**, so it reads that empty string as the *script* and treats `'s/<placeholder>/.../g'` as a filename. The two platforms disagree about the same characters, and the disagreement is silent rather than loud: the substitution does not happen, no error names the reason, and the step appears to have run.

What it breaks is the one thing the step exists for. The token stays in the tree, so `check:placeholders` reports the real owner as a placeholder and the publication gate can never pass — a failure that looks like a stale token rather than a portability bug in the command that was supposed to remove it.

This is the second time a platform difference produced a silent no-op here, and the first was worse. `solutions/verify-l7.sh` used `timeout`, which is GNU coreutils and absent on macOS; the command did not run at all and the check **passed on empty output** ([VERIFIED.md](../VERIFIED.md) records it). That one was previously treated as a fixed bug. It is really an instance of a rule the repository had not written down, which is why the same class of defect returned in `PUBLISHING.md`.

The same audit found the pattern in adjacent forms, none of which fail loudly:

- `UseKeychain` is a macOS-only `ssh_config` directive; OpenSSH on Linux rejects it as a bad configuration option.
- Arch packages `gh` as `github-cli`, and its rolling `nodejs` is a much newer major than the kit's pinned 22.23.x, which is a separate package (`nodejs-lts-jod`). A documented `pacman -S gh` or an assumed `nodejs` installs the wrong thing or nothing.
- `~/.local/bin` is where `pipx`, `uv`, and the `dsh` shim put their executables, and Arch does not add it to `PATH`. Every such tool then reads as "not installed".

## Decision

**A shell command that this repository documents or runs must work on Linux as well as macOS, and must fail loudly where it cannot.** Concretely:

- **No `sed -i` without an attached suffix.** `sed -i.bak` is the one form both implementations read the same way; the backup is removed immediately so it cannot be committed. A `while IFS= read -r` loop replaces `xargs` here, because it keeps one edit and one cleanup per file.
- **No macOS-only directive in a shared config.** `UseKeychain` appears only in a `uname`-guarded branch; Linux gets `IdentityFile` and `AddKeysToAgent`.
- **A package name is per manager.** Where a manager spells a tool differently or ships a different version, the command names that manager's package rather than assuming the usual one.
- **Do not reach for a tool because it is present on the author's machine.** `perl -pi` would have been the portable one-liner, but `perl` is in Arch `core` and **not** in the `base` metapackage, so it is not guaranteed on a minimal install. The kit's dependencies are the only guarantee; `sed` is POSIX.
- **A portability claim is tested before it is written down.** The substitution recipe was re-run on a scratch export with the token injected into both a substitutable file and an excluded one: the first changed, the others did not, no `.bak` survived, and `check:placeholders` passed afterwards.

## Consequences

- **The publication procedure runs on the machine the reader actually has.** The cost is a slightly longer recipe: a `while` loop instead of a pipeline into `xargs`.
- **Platform differences are now a review question, not a surprise.** The repository is macOS-developed and Linux-expected, so a command that only runs on one of them is a defect in the same class as a check that cannot run.
- **`VERIFIED.md` still records macOS as the verified platform.** This decision makes the commands portable; it does not make the lessons verified on Linux. That requires an actual run, and the ledger must keep saying so until one happens.
- **The workspace-level setup guide inherits the rule.** `SETUP-NEW-MACHINE.md` and `scripts/setup-new-machine.sh` detect `apt-get`, `dnf`, `pacman`, or `brew` (native manager first) and report a pinned-Node mismatch rather than replacing the system Node.

## Evidence

The two implementations disagreeing about the same characters. BSD `sed` on the development machine, then GNU `sed` 4.5 run for this record in a Linux container (`docker run --entrypoint sh <linux image>`):

```
$ sed -i '' 's/<placeholder>/exampleuser/g' f.md      # BSD: edits, no backup
token exampleuser here

$ sed -i '' 's/<placeholder>/exampleuser/g' f.md      # GNU 4.5: '' is the script
sed: can't read s/<placeholder>/exampleuser/g: No such file or directory
exit=2
token <placeholder> here                              # unchanged: the substitution did not happen

$ sed -i.bak 's/<placeholder>/exampleuser/g' f.md     # both: edits, and the backup is removable
token exampleuser here
```

The failure mode is the one that matters: on GNU `sed` the token survives. A pipeline that ignores the exit status reports success, and the visible symptom is a leftover placeholder — the portability bug disguised as the thing the gate is looking for.

The recipe, tested on a scratch export with the token injected into a substitutable file and into two excluded definition sites (the exclusion pipeline is abbreviated here as `<exclusions>` to fit the width):

```
$ grep -rl <placeholder> --exclude-dir=node_modules . | grep -vE <exclusions> | while IFS= read -r f; do sed -i.bak 's/<placeholder>/exampleuser/g' "$f" && rm -f "$f.bak"; done
$ grep -n 'probe' README.md
166:Placeholder probe: exampleuser              # substituted
$ grep -n 'Excluded probe' PLAN.md
622:Excluded probe: <placeholder>              # definition site untouched
$ find . -name '*.bak' -not -path './node_modules/*'
$ pnpm run check:placeholders
no pre-publication placeholders found
```

The package facts, as returned by the Arch package database API rather than from memory:

```
$ curl -s 'https://archlinux.org/packages/search/json/?q=nodejs-lts'
nodejs-lts-jod   22.23.3   provides nodejs=22.23.3   conflicts nodejs
nodejs           26.10.0   the current release the `nodejs` name resolves to
$ curl -s 'https://archlinux.org/packages/search/json/?name=github-cli'
github-cli       2.102.0   (a search for 'gh' finds nothing)
```
