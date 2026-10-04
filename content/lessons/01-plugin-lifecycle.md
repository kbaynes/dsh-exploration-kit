---
type: Exploration Lesson
title: "L1 — Mount your first plugin"
description: Get a real plugin into the running harness, watch it become ACTIVE, and make it fail and wait in PENDING so the fiber state machine stops being abstract.
resource: dsh
tags: [deepseek-harness, lesson, plugins, cordis, lifecycle, fiber]
timestamp: 2026-09-30
---

# L1 — Mount your first plugin

**Goal.** By the end of this lesson you have a plugin you wrote loading inside the real `dsh` harness as part of an installed bundle, and you have observed the fiber lifecycle — including a loud failure and a silent `PENDING`. No model calls are needed.

**Why first.** Every capability in the [feature map](../feature-map.md) is a plugin. Until you have mounted one and watched it fail, the rest of the path is vocabulary. See the [learning path](../learning-path.md) for where this sits.

## Concepts taught

| Concept | What you learn |
|---|---|
| The plugin tree | A running dsh is an ordered stack of config rows, each mounting one plugin module |
| Bundles | A package that ships a layer of plugin rows, installed into a profile |
| Plugin rows | How the loader resolves a row's `name` to actual code |
| Plugin shapes | The function shape now; the `Service` subclass arrives in L3 |
| The fiber | The runtime handle for one loaded plugin instance |
| Lifecycle | The six fiber states, including `FAILED` and `PENDING` — silent from the plugin's side, since its `apply` never runs, while the startup summary names the missing service |
| Effects | A registration that is undone when the plugin unloads |

Reference: the [plugin framework guide](https://github.com/deepseek-ai/deepseek-harness/blob/master/docs/user/develop/framework/index.md) and the repository's [first-plugin tutorial](https://github.com/deepseek-ai/deepseek-harness/blob/master/docs/cordis-tutorial/01-first-plugin.md).

## Prerequisites

- The `deepseek-harness` source checkout, `pnpm run build` already run.
- `dsh` on `PATH`. See DSH's [development guide](https://github.com/deepseek-ai/deepseek-harness/blob/master/docs/development.md).
- A terminal. **Do not** use a sandboxed agent's bash tool for the boot steps: the default file sandbox blocks `dsh` from writing its composed profile under `~/.dsh`, and the boot fails with `EPERM`. Run these commands in your own shell.

## Step 1 — Install the kit's plugin bundle

This kit ships its exercise plugins as a **bundle** — a package that contributes a layer of plugin rows to a profile. Install it once into a profile you own:

```sh
# 1. install the bundle's dependencies (it imports dsh packages)
cd <kit>/kit-plugins && pnpm install && cd -

# 2. install the bundle into a fresh profile
dsh plugin --profile kitdemo add link:<kit>/kit-plugins
```

Two details matter, and both were verified by running them:

- **Use `link:`, not `file:`.** `file:` *copies* the package, so edits you make while working the lessons do not take effect until you reinstall. `link:` symlinks it, and every edit you save below is live.
- **`dsh plugin` forwards to pnpm in the profile directory.** The first use creates the profile from the base template and appends your bundle to its `dsh.profile.bundles` list.

Confirm what got installed:

```sh
dsh plugin --profile kitdemo list
```

## Step 2 — Understand what a plugin row is

The bundle carries one file that the profile reads: `kit-plugins/cordis.patch.yml`. Open it. It is an array of patch entries, and the one that matters is an `insert` list of **plugin rows**:

```yaml
- insert:
    - id: l1-hello
      name: dsh-exploration-kit-plugins/l1/hello.ts
```

See the composed result without booting anything:

```sh
cd <path/to/deepseek-harness>
dsh --profile kitdemo --dump-config | grep -A3 'id: l1-hello'
```

`--dump-config` prints the tree a machine would actually boot — every bundle layer, then the profile's own patch — and shows your row as `dsh-exploration-kit-plugins/...`. `--dump-config-schema` prints the JSON Schema for entries and patches instead.

### The trap this mechanism avoids

You will see `--patch` overlays elsewhere in dsh's docs, and they are useful. But a row declared in an overlay resolves its `name` **relative to that patch file**, and a relative path to a loose source file cannot import dsh packages:

```
dsh: warning: 1 entry did not activate
l2-wordcount (.../wordcount.js): failed to import
```

The loader resolves the file outside the dsh installation, and pnpm symlinks only *declared* dependencies, so `@deepseek-ai/dsh-tools` is unreachable. This was observed by running it — it is why this kit ships a bundle.

A plugin that imports **nothing** from dsh does load from a loose file that way, which is worth knowing for throwaway experiments. Anything real goes in the bundle.

Naming a row by package instead means Node resolves it through the profile's own installation, which is exactly how third-party dsh plugins work.

## Step 3 — Write the plugin

Open `<kit>/kit-plugins/l1/hello.ts` — it is already there, and it is short:

```ts
import type { Context } from '@deepseek-ai/cordis'

export const name = 'l1-hello'

export function apply(ctx: Context) {
  console.log('[l1-hello] apply() ran — plugin is ACTIVE')
  ctx.effect(() => {
    console.log('[l1-hello] effect registered')
    return () => console.log('[l1-hello] disposer ran — plugin is DISPOSED')
  })
}
```

A function plugin named-exports `apply(ctx)`. The optional `name` export is diagnostic metadata only. `ctx.effect(fn)` runs the body during load and keeps the returned disposer for unload — this is how you own a resource (timer, connection, watcher) that Cordis does not already manage.

**Why a `.ts` file loads at all, and when that stops working.** Node runs `.ts` files by *erasing* types; there is no type checker in the boot path. That is enough for this file, because its only TypeScript is a type-only import that erasure removes entirely. It would **not** be enough for a `.ts` file containing an `enum`, a decorator, parameter properties, or a type-only *export* that consumers rely on — those need a real build step. Every later lesson uses plain `.js` for that reason: what runs is what you wrote, with no transpile gap between the two.

Because you installed with `link:`, this file is already live. Nothing to reinstall.

## Step 4 — Boot it and watch the lifecycle

```sh
dsh --profile kitdemo --port 0 --no-open
```

Use a random port so you do not collide with any GUI already running. Expected output:

```
[l1-hello] apply() ran — plugin is ACTIVE
[l1-hello] effect registered
[l2-wordcount] ACTIVE — defaultUnit=lines
dsh web: http://127.0.0.1:<port>/?token=...
```

Press Ctrl-C. The shutdown path unwinds effects, so you then see:

```
[l1-hello] disposer ran — plugin is DISPOSED
```

You have now witnessed `LOADING → ACTIVE → UNLOADING → DISPOSED`. The `l2-wordcount` line is the kit's next lesson already switched on — leave it for now.

Your plugin declares no `inject`, so it never entered `PENDING`.

## Step 5 — Make it FAIL

Edit `hello.ts` so `apply` throws before anything else:

```ts
export function apply(ctx: Context) {
  throw new Error('apply exploded')
}
```

Save, then boot again. The boot reports the failed entry and continues, rather than dying:

```
dsh: warning: 1 entry did not activate
l1-hello (dsh-exploration-kit-plugins/l1/hello.ts): Error: apply exploded
    at new apply (file:///<kit>/kit-plugins/l1/hello.ts:4:9)
    ...
```

This is the design — a plugin that fails to load is a **loud failure**, never a skipped entry. Note exactly what you get: the entry's `id`, its resolved module specifier, your error, and a stack frame pointing into your own file. That is enough to find the fault without adding a single `console.log`.

Restore the original `apply` before continuing.

## Step 6 — Make it PEND

Add a dependency on a service nobody provides:

```ts
export const inject = ['definitelyNotAService']
```

Boot again. Unlike the failure above, the plugin's own `apply` never runs, so you see **nothing from your plugin at all** — but the startup check does tell you what it is waiting for:

```
dsh: warning: 1 entry did not activate
l1-hello (dsh-exploration-kit-plugins/l1/hello.ts): pending (waiting for service: definitelyNotAService)
```

That message is the whole lesson. `PENDING` is a legitimate state, not an error: a service may still arrive, so the loader waits rather than failing. The cost is that a plugin stuck on a missing provider looks *silent* from the inside — your logs never appear — while the harness tells you about it once, at startup, in a summary you can easily scroll past.

Remember where to look; L3 teaches you to enumerate every fiber's state on demand.

Revert `inject` before continuing.

## Verification

1. `dsh plugin --profile kitdemo list` shows the kit's bundle installed.
2. `--dump-config` shows your `l1-hello` row named by package.
3. A boot prints the `apply()` line and the effect line.
4. Ctrl-C prints the disposer line.
5. You can state, without looking it up, why a plugin that imports a dsh package cannot be loaded from a loose file by a `--patch` overlay.

> **Where this lesson stands.** Every step above has been executed against a real harness; the exact output is quoted in [VERIFIED.md](https://github.com/kbaynes/dsh-exploration-kit/blob/main/VERIFIED.md). Nothing in this lesson needs a model provider, and nothing in it is unverified.

## Exit check — you should now be able to explain

- Why a plugin that imports a dsh package cannot be loaded from a loose file.
- Why `--dump-config` is not sufficient evidence that a plugin will work.
- What an "effect" is, and what happens to one when its plugin unloads.
- Why `link:` and `file:` installs behave differently while you are editing.

## Troubleshooting

| Symptom | Cause |
|---|---|
| `failed to import` and the entry did not activate | The plugin imports a dsh package but its row points at a loose file; ship it as a bundle and name the row by package |
| `patch: entry "x" not found` (warning, boot continues) | You used `- id:` for a new row intended as an insert; wrap it in `- insert:` |
| Edits have no effect after reinstalling | You installed with `file:` (a copy); remove and re-add with `link:` |
| `EPERM ... ~/.dsh/profiles/...` | A file sandbox is blocking `dsh`; run in your own shell |
| No output at all, no error | Your plugin is `PENDING` on an unavailable service |
| Process exits with an activation failure | `apply` threw — this is `FAILED` |

## Next

[L2 — Register a tool, compose with config](./02-tool-and-effects.md) turns this skeleton into something the model can actually call.
