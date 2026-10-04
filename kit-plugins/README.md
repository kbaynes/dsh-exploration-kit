# Kit plugins — the bundle you install

This directory is a **dsh bundle**: the package that carries every lesson's
exercise plugin into a running harness. It replaces the kit's original approach of
pointing a `--patch` overlay at a loose `.ts` file.

## Why a bundle, and not a `--patch` overlay

The kit originally had learners do this:

```yaml
- insert:
    - id: l1-hello
      name: './l1/hello.ts'      # relative to the patch file
```

That **does not work** for a plugin that imports anything from dsh. The loader
resolves the relative path to a file outside the dsh installation, and that file's
`import { defineTool } from '@deepseek-ai/dsh-tools'` cannot resolve: pnpm symlinks
only *declared* dependencies, so `@deepseek-ai/dsh-tools` is not reachable from an
arbitrary directory. The boot reports:

```
dsh: warning: 1 entry did not activate
l2-wordcount (...): failed to import
```

This was verified by booting it — see [VERIFIED.md](../VERIFIED.md). It is not a
theoretical concern; it is the first thing that happens.

A plugin that imports **nothing** from dsh does load that way, which is why
Lesson 1's hello-world works. Anything more real must be a bundle.

## How the bundle mechanism works

The bundle declares its contribution in `package.json`:

```json
"dsh": { "bundle": { "patch": "./cordis.patch.yml" } }
```

and its patch rows reference the package **by name**:

```yaml
- insert:
    - id: l2-wordcount
      name: dsh-exploration-kit-plugins/l2/wordcount.js
```

Then you install it into a profile:

```sh
dsh plugin --profile kitdemo add file:/path/to/dsh-exploration-kit/kit-plugins
```

`dsh plugin` forwards to pnpm in the profile directory, links the package, and
appends it to the profile's `dsh.profile.bundles` list. From then on the plugin
resolves through the profile's installation, which is exactly how third-party dsh
plugins work.

## Dependencies

dsh packages that must share an instance with the host are declared in **both**
`peerDependencies` and `devDependencies`, as the upstream publish guide requires:
the peer entry makes the running installation's copy win at resolution time, and
the devDependency copy serves local development and type checking.

Versions are pinned to the dsh release the kit is verified against
(see [VERIFIED.md](../VERIFIED.md)). Bump them with the verification pass.

```sh
pnpm install     # inside this directory, before installing into a profile
```

## Layout

```
cordis.patch.yml   the bundle layer: one row per lesson exercise
l2/wordcount.js    Lesson 2's tool plugin
```

Rows are added as each lesson is built. `plugins/` at the repository root remains
the learner's own scratch space for writing the exercises themselves.
