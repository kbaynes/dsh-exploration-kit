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
| Service isolation | (further exploration) Two groups seeing different instances of one service name |
| Hot module replacement | `dsh-hmr` unloads and reloads a changed plugin in place |
| Live tree inspection | Plugin inventory, the registry API, and `plugin_manager` |

Reference: [plugin model](https://github.com/deepseek-ai/deepseek-harness/blob/main/docs/user/develop/framework/index.md) and the repository's
[services tutorial](https://github.com/deepseek-ai/deepseek-harness/blob/main/docs/cordis-tutorial/03-services.md).

## Prerequisites

L1 and L2 complete: the kit bundle is installed with `link:`, and you know how a
row's `config` is supplied and overridden.

## Step 1 — Provide a service

Open `<kit>/kit-plugins/l3/clock.js`, already wired into the bundle:

```js
import { Service } from '@deepseek-ai/cordis'

export class LessonClockService extends Service {
  constructor(ctx) {
    super(ctx, 'lessonClock')
  }

  stamp(label) {
    return `[${label}] ${new Date().toISOString()}`
  }
}

export const name = 'l3-clock'

export function apply(ctx) {
  ctx.plugin(LessonClockService)
  console.log('[l3-clock] service provided as ctx.lessonClock')
}
```

Two independent pieces are doing work:

- **Runtime:** `super(ctx, 'lessonClock')` registers the instance under that name,
  so any plugin can reach it as `ctx.lessonClock`. The registration is an effect —
  unloading the provider removes the service.
- **Compile time:** in the TypeScript original this is accompanied by
  `declare module '@deepseek-ai/cordis' { interface Context { lessonClock: LessonClockService } }`.
  That block is declaration merging: it adds the key to the `Context` interface so
  `ctx.lessonClock` typechecks everywhere. It generates no code, and without it the
  service still works but consumers lose type safety.

A `Service` subclass **is** a plugin, so `ctx.plugin(...)` mounts it like any other.

## Step 2 — Consume it, then strand it

`<kit>/kit-plugins/l3/uses-clock.js` consumes the service:

```js
export const name = 'l3-uses-clock'
export const inject = ['lessonClock']

export function apply(ctx) {
  console.log(ctx.lessonClock.stamp('l3-uses-clock'))
}
```

`inject` lists the services this plugin requires. Cordis holds the plugin in
`PENDING` until every listed service exists, so inside `apply`, `ctx.lessonClock` is
guaranteed ready. **Load order does not matter** — dependencies, not file order,
decide when plugins start.

Boot and confirm the stamp prints:

```sh
dsh --profile kitdemo --port 0 --no-open
```

```
[l3-clock] service provided as ctx.lessonClock
[l3-uses-clock] 2026-10-01T12:21:13.309Z
```

Now the experiment. Open `<kit>/kit-plugins/cordis.patch.yml` and add
`disabled: true` to the `l3-clock` row:

```yaml
    - id: l3-clock
      name: dsh-exploration-kit-plugins/l3/clock.js
      disabled: true
```

Boot again. The consumer prints **nothing at all**, and the stamp is gone:

```
[l3-diagnose] PENDING: l3-uses-clock — a required service is missing
...
dsh: warning: 1 entry did not activate
```

That is this lesson's most valuable moment, and it sharpens what L1 taught. The
`[l3-diagnose]` line comes from this lesson's third plugin — step 3 builds it — so you
can already see the shape of the fix before you write it. A
throwing `apply` is loud and names your file. A missing dependency produces **no
output of its own** — the consumer's `apply` never runs — and the only signal is a
line in the startup summary. Nearly every "my plugin does nothing" report is this
state.

Revert `disabled` before continuing.

## Step 3 — Enumerate the states directly

The startup summary is a hint; the registry is the source of truth. Open
`<kit>/kit-plugins/l3/diagnose.js`:

```js
export const name = 'l3-diagnose'

// FiberState is a `const enum`: TypeScript erases it, and it is NOT a runtime
// export of the published @deepseek-ai/cordis package. Importing it — as the
// upstream Cordis tutorial does — throws at load. Compare the stable numbers.
const STATE_NAMES = ['PENDING', 'LOADING', 'ACTIVE', 'FAILED', 'DISPOSED', 'UNLOADING']

export function apply(ctx, config) {
  const filter = config?.match ?? ''
  const timer = setTimeout(() => {
    let reported = 0
    for (const runtime of ctx.registry.values()) {
      for (const fiber of runtime.fibers) {
        const name = fiber.name ?? '(unnamed)'
        if (filter && !name.includes(filter)) continue
        if (fiber.state === 0) {
          console.log(`[l3-diagnose] PENDING: ${name} — a required service is missing`)
          reported += 1
        } else if (fiber.state === 3) {
          console.log(`[l3-diagnose] FAILED: ${name}`)
          reported += 1
        }
      }
    }
    console.log(`[l3-diagnose] ${reported} stranded fiber(s)`)
  }, 800)
  ctx.effect(() => () => clearTimeout(timer))
}
```

Its row carries `config: { match: 'l3-' }`, which scopes the sweep to the fibers
you are working on. **Do not skip the filter when you adapt this.** A real profile
has services legitimately waiting on optional providers — on the profile used here,
a full sweep reported `TypertGatewayService`, `AuthorizationService`,
`PlatformAccount`, and `llm-pi-ai` as PENDING at the same time. None of them are
broken. A diagnostic that cries wolf is worse than none.

Two traps worth recording, both hit while building this lesson:

- **`FiberState` is a `const enum`.** TypeScript erases it at compile time and the
  published `@deepseek-ai/cordis` does not export it, so
  `import { FiberState } from '@deepseek-ai/cordis'` — exactly what the upstream
  tutorial shows — fails at load with a `TypeError`. Compare the numbers.
- **`Config` must be a real schema.** A hand-rolled `{ parse }` object is not a
  Standard Schema and fails as `TypeError: Cannot read properties of undefined
  (reading 'validate')`. Use Schemastery, as L2 does.

With the provider restored, the scoped sweep reports the healthy case:

```
[l3-clock] service provided as ctx.lessonClock
[l3-uses-clock] 2026-10-01T12:21:13.309Z
[l3-diagnose] 0 stranded fiber(s) matching "l3-"
```

Keep this file. It is your instrument for the rest of the path.

## Step 4 — Turn on hot reload

The base bundle mounts `dsh-hmr` with `root: []`, which retains only explicit
configuration watches. To watch the kit's plugin sources, configure the existing
entry from an overlay rather than inserting a second one. The kit ships one at
`<kit>/solutions/l3.hmr.patch.yml`:

```yaml
- id: hmr
  config:
    root: ['<absolute path to>/dsh-exploration-kit/kit-plugins']
```

Substitute your absolute kit path (the loader wants a real directory, not a
placeholder), then boot with it:

```sh
dsh --profile kitdemo --patch <kit>/solutions/l3.hmr.patch.yml --port 0 --no-open
```

Now, **with the process still running**, edit `l3/uses-clock.js` and change the
label inside `stamp('...')`. Watched live, this produced:

```
[l3-uses-clock] 2026-10-01T12:21:49.606Z          <- before the edit
[l3-uses-clock-EDITED] 2026-10-01T12:22:07.232Z   <- after saving, no restart
```

What happened: HMR unloaded your plugin — every effect it owned unwound, which is
what *effect* means — re-read the module, and called `apply` again. The same
machinery reloads the config file itself, which is why entries need stable `id`s.

If you see nothing, HMR is probably disabled in your composition: the base bundle
gates it behind the launcher's `profileContext`, and the headless, SDK, and ACP
bundles disable it in YAML. Restarting after an edit is the fallback behavior.

Revert your edit — or keep it, and confirm the scoped sweep still reports zero
stranded fibers.

## Step 5 — Inspect the live tree

Three read-only ways in, cheapest first:

1. **Plugin inventory.** The web GUI's settings surface includes a plugin inventory
   panel backed by `@deepseek-ai/dsh-host-plugin-inventory`, which projects the
   current Loader tree: entry id, module specifier, effective enablement, and the
   root fiber phase. Loader remains the sole lifecycle authority — this service
   owns no history and no mutation.
2. **`plugin_manager`.** The model-facing tool can `list_plugins`, `list_bundles`,
   `set_plugin`, and `set_bundle`. Every action requires danger-full-access or
   approval, and changes affect **every** session in the profile.

   **It does not see rows contributed by a bundle**, and this lesson's rows come
   from one. Verified: in a composition whose plugin list reports 115 rows, none of
   `l1-hello`, `l2-wordcount`, `l3-clock`, or `l3-uses-clock` appears — while the
   kit's *bundle* is listed among the 11 bundles, and `set_plugin` on one of those
   ids returns `application: "failed"` with an unknown-target error. The service
   behind the tool, `ctx.pluginManager`, behaves the same way:

   ```
   [l3-probe] initial: 115 row(s) total; l3 rows:
   [l3-probe] disabled l3-uses-clock: {"application":"failed","error":{"code":"unkno…
   [l3-probe] bundles: 11 total; kit bundle present: true
   [l3-probe] ids containing "l3-uses-clock": (none)
   ```

   So `plugin_manager` manages the **profile's own rows** and whole **bundles**; a
   bundle-contributed row is invisible to it. That is the same layer boundary the
   kit's install instructions depend on — rows live in the bundle, and the profile
   composes bundles.
3. **Cordis runtime inspection.** With the `cordis-host-runner` composition
   present, the `cordis_inspect_list` and `cordis_inspect_query` tools read the
   live registry. That one reads the Loader tree, so it *does* show your rows.

Then do the reverse experiment yourself, using the mechanism that works for a
bundle-contributed row: add `disabled: true` to the `l3-uses-clock` row in
`<kit>/kit-plugins/cordis.patch.yml`, exactly as step 2 did for the provider, and
watch the consumer disappear — the same stranding, applied at the bundle layer
instead of by hand. Saving is enough, because you installed with `link:`.

## Verification

Observable without a model:

1. With the provider present, the consumer prints a stamp on boot and the scoped
   sweep reports `0 stranded fiber(s) matching "l3-"`.
2. With the provider disabled, the consumer prints **nothing** and the sweep names
   `l3-uses-clock` as `PENDING`.
3. You can explain why the full (unscoped) sweep reports several unrelated PENDING
   services in a healthy profile.
4. Editing `l3/uses-clock.js` while the process runs changes the printed stamp
   without a restart.
5. `dsh plugin --profile kitdemo list` shows the bundle, and `--dump-config` shows
   your entry ids and their enablement.

> **Where this lesson stands.** Every step above has been executed against a real
> harness; the exact output is quoted in
> [VERIFIED.md](https://github.com/REPLACE_OWNER/dsh-exploration-kit/blob/main/VERIFIED.md). What remains unverified there is
> what needs a model provider, and it is named rather than glossed.

## Exit check — you should now be able to explain

- Why list position in a config file does not determine load order, and why the loader
  can still declare two plugins "independent" even though one needs the other.
- The difference between a plugin shape and a plugin *instance* — L1 showed one shape;
  this lesson's `Service` subclass is the second.
- What `inject` buys at runtime versus what the `declare module` block buys at compile time.
- Why a plugin author should prefer an effect over a manual `try/finally` teardown.
- What service isolation (`isolate`) changes, and when a deployment needs it — the
  architecture doc's table names it for per-session capability sets.

## Further exploration

- **Re-read the diagnose plugin's two traps.** Both were found by running it, and
  both contradict the upstream Cordis tutorial as written. Finding that a tutorial
  is stale is itself a skill worth practising.
- **Service isolation.** Define a group with an `isolate` realm and mount two
  differently configured providers of one service name. This is the mechanism
  behind per-session capability sets, which L8 uses for agent presets.
- **Runtime-defined packages.** The `extensions/` packages (`tool-cordis`,
  `cordis-host-runner`, `cordis-client-runner`, `ui-cordis`) let a definition be
  evaluated into a live plugin, host-side and in the browser. It is the same model
  you just used, with the source arriving at runtime instead of from disk.

## Next

[L4 — Build a policy gate](./04-policy-waterfalls.md).
