---
type: Exploration Lesson
title: "L1 — Mount your first plugin"
description: Get a real plugin into the running harness, watch it become ACTIVE, and make it fail and wait in PENDING so the fiber state machine stops being abstract.
resource: dsh
tags: [deepseek-harness, lesson, plugins, cordis, lifecycle, fiber]
timestamp: 2026-09-30
---

# L1 — Mount your first plugin

**Goal.** By the end of this lesson you have a plugin you wrote loading inside the
real `dsh` harness, and you have observed three of its five lifecycle states with
your own eyes. No model calls are needed.

**Why first.** Every capability in the [feature map](../feature-map.md)
is a plugin. Until you have mounted one and watched it fail, the rest of the path
is vocabulary. See the [learning path](../learning-path.md) for where
this sits.

## Concepts taught

| Concept | What you learn |
|---|---|
| The plugin tree | A running dsh is an ordered stack of config rows, each mounting one plugin module |
| Patch overlays | `--patch <file>` adds rows on top of the profile without editing the profile |
| Plugin shapes | Function, object, and `Service` subclass — and when each is used |
| The fiber | The runtime handle for one loaded plugin instance |
| Lifecycle | `PENDING → LOADING → ACTIVE → UNLOADING → DISPOSED`, plus `FAILED` |
| Loud failure | A throwing `apply` is fatal, not skipped |
| Effects | A registration that is undone when the plugin unloads |

Reference: [plugin model](https://github.com/deepseek-ai/deepseek-harness/blob/main/docs/user/develop/framework/index.md), and the repository's own
[first-plugin tutorial](https://github.com/deepseek-ai/deepseek-harness/blob/main/docs/cordis-tutorial/01-first-plugin.md).

## Prerequisites

- The `deepseek-harness` source checkout, `pnpm run build` already run.
- `dsh` on `PATH`. See [installing the dsh CLI](https://github.com/deepseek-ai/deepseek-harness/blob/main/docs/development.md).
- A terminal. **Do not** use the GUI's own agent bash tool for the boot step: the
  default file sandbox blocks `dsh` from writing its composed profile under
  `~/.dsh`, and the boot will fail with `EPERM`. Run these commands in your own
  shell.

## Step 1 — Write the plugin

Create `<kit>/plugins/l1/hello.ts` in the workspace:

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

A function plugin named-exports `apply(ctx)`. The optional `name` export is
diagnostic metadata only. `ctx.effect(fn)` runs the body during load and keeps the
returned disposer for unload — this is how you own a resource (timer, connection,
watcher) that Cordis does not already manage.

## Step 2 — Compose it with a patch overlay

Create `<kit>/plugins/l1.patch.yml`:

```yaml
- insert:
    - id: l1-hello
      name: './l1/hello.ts'
```

Three things are load-bearing here, and each was verified by running it:

- **New rows go under `insert:`.** A top-level `- id: ...` entry targets an
  *existing* row id for override; targeting a new id does **not** fail the boot —
  it prints `patch: entry "<id>" not found` as a warning and silently skips the
  patch. The symptom is a missing row in `--dump-config`, not an error, which is
  why this one costs people time.
- **`name` resolves relative to the patch file, not the workspace root.** The
  patch lives at `<kit>/plugins/l1.patch.yml`, so the specifier is
  `./l1/hello.ts`. Writing the workspace-relative
  `./<kit>/plugins/l1/hello.ts` silently resolves to a duplicated path
  (`<kit>/plugins/<kit>/plugins/...`).
- **`id` is stable identity.** Without one, every config re-read generates a new
  id, so the entry counts as removed-plus-added and remounts even when unchanged.

## Step 3 — Inspect the composed tree without booting

```sh
cd <path/to/deepseek-harness>
dsh --profile web --patch ./<kit>/plugins/l1.patch.yml --dump-config | grep -A3 'id: l1-hello'
```

`--dump-config` prints the tree a machine would actually boot: every bundle layer,
then the profile patch, then your overlay. Confirm your row resolved to a
`file:///.../<kit>/plugins/l1/hello.ts` URL. `--dump-config-schema` prints
the JSON Schema for entries and patches without mounting anything.

## Step 4 — Boot it and watch the lifecycle

```sh
dsh --profile web --patch ./<kit>/plugins/l1.patch.yml --port 0 --no-open
```

Use a random port so you do not collide with any GUI already running. Expected
output:

```
[l1-hello] apply() ran — plugin is ACTIVE
[l1-hello] effect registered
dsh web: http://127.0.0.1:<port>/?token=...
```

Press Ctrl-C. The shutdown path unwinds effects, so you should then see:

```
[l1-hello] disposer ran — plugin is DISPOSED
```

You have now witnessed `LOADING → ACTIVE → UNLOADING → DISPOSED`. Because your
plugin injects nothing, it never entered `PENDING`.

## Step 5 — Make it FAIL

Change `apply` to throw before anything else:

```ts
export function apply(ctx: Context) {
  throw new Error('apply exploded')
}
```

Save and boot again. The process dies with your error. This is the design: a
plugin that fails to load is a **loud failure**, not a skipped entry. Read the
stack trace — the loader tells you which entry failed.

Revert the throw.

## Step 6 — Make it PEND

Add a dependency on a service nobody provides:

```ts
export const inject = ['definitelyNotAService']
```

Boot again. Now there is no error and no log line — the plugin sits in `PENDING`
forever, because a required service is absent and the provider might still arrive
later. This is the failure mode that costs people hours: **silence is PENDING.**
Remember it; L3 teaches you to enumerate the states directly.

Revert `inject` before continuing.

## Verification

You have passed L1 when all four hold:

1. `--dump-config` shows your `l1-hello` row with a correct `file://` URL.
2. A boot prints the `apply()` line and the effect line.
3. Ctrl-C prints the disposer line.
4. You can state, without looking it up, what `PENDING` means and why it prints
   nothing.

## Exit check — you should now be able to explain

- Why list position in a config file does not determine load order.
- The difference between a plugin shape and a plugin *instance*.
- Why `--dump-config` is not sufficient evidence that a plugin will work.
- What an "effect" is, and what happens to one when its plugin unloads.

## Troubleshooting

| Symptom | Cause |
|---|---|
| `patch: entry "x" not found` (warning, boot continues) | You used `- id:` for a new row; wrap it in `- insert:` |
| Module resolves to a doubled path | `name` is patch-file-relative, not workspace-relative |
| `EPERM ... ~/.dsh/profiles/web/cordis.yml` | The agent file sandbox is blocking `dsh`; run in your own shell |
| No output at all, no error | Your plugin is `PENDING` on an unavailable service |
| Process exits immediately with a stack trace | `apply` threw — this is `FAILED` |

## Next

[L2 — Register a tool, compose with config](./02-tool-and-effects.md)
turns this skeleton into something the model can actually call.
