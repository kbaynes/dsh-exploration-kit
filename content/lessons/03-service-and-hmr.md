---
type: Exploration Lesson
title: "L3 — Services, isolation, and hot reload"
description: Provide your own ctx service, force a consumer into PENDING and back, then hot-edit a running plugin and inspect the live loader tree.
resource: dsh
tags: [deepseek-harness, lesson, services, dependency-injection, hmr, plugin-inventory]
timestamp: 2026-09-30
---

# L3 — Services, isolation, and hot reload

**Goal.** By the end of this lesson you own a `ctx.yourService`, you have watched a
consumer wait in `PENDING` and activate when the provider arrives, and you have
changed a plugin's behavior in a **running** harness by editing a file.

**Why here.** L1 and L2 mounted code that nobody else consumed. Services are how
plugins cooperate, and the reload path is what makes every later lesson fast to
iterate on.

## Concepts taught

| Concept | What you learn |
|---|---|
| `Service` subclass | Providing a named capability as `ctx.<key>` |
| Declaration merging | Making `ctx.yourService` typecheck for consumers |
| `inject` ordering | Dependencies, not file position, decide load order |
| `PENDING` as a legitimate state | A missing provider is silent, not an error |
| Service isolation | Two groups seeing different instances of one service name |
| Hot module replacement | `dsh-hmr` unloads and reloads a changed plugin |
| Live tree inspection | Plugin inventory, the registry API, and `plugin_manager` |

Reference: [plugin model](https://github.com/deepseek-ai/deepseek-harness/blob/main/docs/harness/plugins.md) and the repository's
[services tutorial](https://github.com/deepseek-ai/deepseek-harness/blob/main/docs/cordis-tutorial/03-services.md).

## Prerequisites

L1 and L2 complete, including the patch-file mechanics and the meaning of `PENDING`.

## Step 1 — Provide a service

Create `<kit>/plugins/l3/clock.ts`:

```ts
import { Service, type Context } from '@deepseek-ai/cordis'

declare module '@deepseek-ai/cordis' {
  interface Context {
    lessonClock: LessonClockService
  }
}

export class LessonClockService extends Service {
  constructor(ctx: Context) {
    super(ctx, 'lessonClock')
  }

  stamp(label: string) {
    return `[${label}] ${new Date().toISOString()}`
  }
}

export const name = 'l3-clock'

export function apply(ctx: Context) {
  ctx.plugin(LessonClockService)
}
```

Two independent pieces are doing work: `super(ctx, 'lessonClock')` registers the
runtime service under that key, and the `declare module` block is TypeScript
declaration merging that makes `ctx.lessonClock` typecheck everywhere. The merge
generates no code — without it the service still works, but consumers lose types.
A `Service` subclass **is** a plugin, so `ctx.plugin(...)` mounts it like any other.

## Step 2 — Consume it, and lose it

Create `<kit>/plugins/l3/uses-clock.ts`:

```ts
import type { Context } from '@deepseek-ai/cordis'

export const name = 'l3-uses-clock'
export const inject = ['lessonClock']

export function apply(ctx: Context) {
  console.log(ctx.lessonClock.stamp('l3-uses-clock'))
}
```

Mount both from `<kit>/plugins/l3.patch.yml`:

```yaml
- insert:
    - id: l3-clock
      name: './l3/clock.ts'
    - id: l3-uses-clock
      name: './l3/uses-clock.ts'
```

Boot and confirm the stamp prints. Now the experiment: comment out the `l3-clock`
entry and boot again. The consumer prints **nothing at all** and the process does
not error. It is `PENDING`, because a required service is unavailable and Cordis
cannot know whether the provider will appear later.

This is the lesson's most valuable moment. In L1 you learned that a throwing
`apply` is loud; here you learn that a missing dependency is silent. Almost every
"my plugin does nothing" report is this state.

## Step 3 — Enumerate the states directly

Create `<kit>/plugins/l3/diagnose.ts` to stop guessing:

```ts
import { FiberState, type Context } from '@deepseek-ai/cordis'

export const name = 'l3-diagnose'

export function apply(ctx: Context) {
  setTimeout(() => {
    for (const runtime of ctx.registry.values()) {
      for (const fiber of runtime.fibers) {
        if (fiber.state === FiberState.PENDING) {
          console.log(`${fiber.name} is PENDING — a required service is missing`)
        }
      }
    }
  }, 1000)
}
```

Mount it alongside the others, remove the clock provider again, and boot. The
diagnostic names the stranded plugin. Keep this file — it is your instrument for
the rest of the path.

## Step 4 — Turn on hot reload

The base bundle mounts `dsh-hmr` with `root: []`, which retains only explicit
configuration watches. To watch a source tree, configure the existing entry from
your overlay rather than inserting a second one:

`<kit>/plugins/l3.hmr.patch.yml`:

```yaml
- id: hmr
  config:
    root: ['./<kit>/plugins']
```

Boot with the plugins patch and this one. Then, **with the process running**, edit
`uses-clock.ts` — change the label inside `stamp('...')` and save. Expected:

```
[l3-uses-clock] ...        <- old instance
... hmr reload plugin at .../uses-clock.ts
[l3-...] ...               <- new output from the reloaded instance
```

What actually happened: HMR unloaded your plugin (all its effects unwound — this
is why they are *effects*), re-read the module, and called `apply` again. The same
machinery reloads the config file itself, which is why entries need stable `id`s
from L1.

If you see nothing, HMR is probably disabled in your composition: the base bundle
gates it behind the launcher's `profileContext`, and the headless, SDK, and ACP
bundles disable it in YAML. Restart after an edit is the fallback behavior.

## Step 5 — Inspect the live tree

Three read-only ways in, cheapest first:

1. **Plugin inventory.** The web GUI's settings surface includes a plugin inventory
   panel backed by `@deepseek-ai/dsh-host-plugin-inventory`, which projects the
   current Loader tree: entry id, module specifier, effective enablement, and the
   root fiber phase. Loader remains the sole lifecycle authority — this service
   owns no history and no mutation.
2. **`plugin_manager`.** The model-facing tool can `list_plugins`, `list_bundles`,
   and `set_plugin` to enable or disable a row. Every action requires
   danger-full-access or approval, and changes affect **every** session in the
   profile. Try asking the agent to list plugins, then disable a non-essential one
   and watch the tree change.
3. **Cordis runtime inspection.** With the `cordis-host-runner` composition
   present, the `cordis_inspect_list` and `cordis_inspect_query` tools read the
   live registry.

Then do the reverse experiment: disable your `l3-uses-clock` row from
`plugin_manager` and observe the consumer disappear without a restart.

## Verification

1. With the provider present, the consumer prints a stamp on boot.
2. With the provider removed, the consumer prints nothing and no error appears.
3. Your `diagnose.ts` instrument names the stranded plugin as `PENDING`.
4. Editing `uses-clock.ts` while running produces a reload line and new output.
5. `list_plugins` shows your entry ids and their enablement.

## Exit check — you should now be able to explain

- Why the loader can declare two plugins "independent" even though one needs the other.
- What `inject` buys at runtime versus what the `declare module` block buys at compile time.
- Why a plugin author should prefer an effect over a manual `try/finally` teardown.
- What service isolation (`isolate`) changes, and when a deployment needs it — the
  architecture doc's table names it for per-session capability sets.

## Further exploration

- **Service isolation.** Define a group with an `isolate` realm and mount two
  differently configured providers of one service name. This is the mechanism
  behind per-session capability sets, which L8 uses for agent presets.
- **Runtime-defined packages.** The `extensions/` packages (`tool-cordis`,
  `cordis-host-runner`, `cordis-client-runner`, `ui-cordis`) let a definition be
  evaluated into a live plugin, host-side and in the browser. It is the same model
  you just used, with the source arriving at runtime instead of from disk.

## Next

[L4 — Build a policy gate](./04-policy-waterfalls.md).
