---
type: Exploration Lesson
title: "L4 — Build a policy gate"
description: Intercept tool calls with a waterfall listener, deny by policy, add a monotonic guard, and route filesystem and sandbox policy through the seams that already own it.
resource: dsh
tags: [deepseek-harness, lesson, policy, waterfalls, events, sandbox, permissions]
timestamp: 2026-09-30
---

# L4 — Build a policy gate

**Goal.** By the end of this lesson you have a plugin that denies a tool call by policy, a second one whose denial nothing can undo, and a clear map of which policies already exist so you extend rather than duplicate them.

**Why here.** L1–L3 taught you to add capability. This lesson is the first that *removes* or constrains capability — the skill that separates a demo harness from a deployable one.

## Concepts taught

| Concept | What you learn |
|---|---|
| `inject = ['tools']` | Why a service must be declared before it can be touched |
| `tools/pre-execute` | The reorderable allow / deny / ask decision point |
| Waterfall dispatch | A listener receives `(...args, next)`, delegates with `next()`, or short-circuits |
| The decision union | `{kind:'allow'}`, `{kind:'deny', reason}`, `{kind:'ask', reason?}`, `{kind:'cancel'}` |
| Monotonic guards | `ctx.tools.guard()` — a denial no later listener can reverse |
| The full pipeline | pre-execute → guards → execute → post-execute → finalizeContent → result |
| `!!js` in a config row | Compute the confinement root at load time |
| `fs/*` policy | `fs/write-intent` and `fs/edit-intent` waterfalls |
| Sandbox seam | `ctx.sandbox` confines spawned processes; providers are swappable |
| Credential redaction | Context-level redaction rather than tool-level string matching |

Reference: the repository's [extension cookbook permission-gate example](https://github.com/deepseek-ai/deepseek-harness/blob/main/docs/cookbook/extension-cookbook.md), `packages/core/tools/README.md`, and the [plugin model](https://github.com/deepseek-ai/deepseek-harness/blob/main/docs/user/develop/framework/index.md) for waterfall semantics.

## Prerequisites

L1–L3 complete. L3 in particular: you need the reload loop to iterate on a policy without restarting, and you have seen what a missing `inject` reports.

## Step 1 — A working deny-by-policy gate

Open `<kit>/kit-plugins/l4/write-scope.js`, wired into the bundle:

```js
import { resolve, sep } from 'node:path'
import Schema from '@deepseek-ai/schemastery'

export const Config = Schema.object({
  allowedRoot: Schema.string().default(resolve(process.env.KIT_SANDBOX ?? process.cwd(), 'l4-sandbox')),
})

export const name = 'l4-write-scope'
export const inject = ['tools']

function isMutatingFsTool(name) {
  return name === 'write' || name === 'edit' || name === 'str_replace_editor'
}

function targetPath(exec) {
  const args = exec.arguments ?? {}
  const value = args.path ?? args.file_path ?? args.filePath
  return typeof value === 'string' ? value : undefined
}

export function apply(ctx, config) {
  const ALLOWED = resolve(config.allowedRoot)

  ctx.on('tools/pre-execute', async (exec, next) => {
    if (!isMutatingFsTool(exec.name)) return next()

    const target = targetPath(exec)
    if (target === undefined) {
      return { kind: 'ask', reason: `${exec.name} without a resolvable path` }
    }

    const absolute = resolve(target)
    if (absolute !== ALLOWED && !absolute.startsWith(ALLOWED + sep)) {
      return { kind: 'deny', reason: `writes are confined to ${ALLOWED}` }
    }
    return next()
  })

  console.log(`[l4-write-scope] ACTIVE — writes confined to ${ALLOWED}`)
}
```

Four details are the whole lesson:

- **`return next()` delegates.** A listener that only observes must call `next()`, or it silently vetoes the pipeline. `next()` resolves to the downstream decision, not to permission.
- **Returning *without* `next()` is a short-circuit.** That is the design for single-decision events: a policy listener owns the decision.
- **`exec.arguments` is frozen and deliberately not rewritable.** The repository states that `tools/pre-execute` cannot rewrite arguments, because logged and rendered args would desync from what actually ran. Read them; do not normalize them here.
- **`inject = ['tools']` is mandatory.** Without it, touching `ctx.tools` throws `Error: cannot get property "tools" without inject` at load. This was hit while building the lesson — the service is *not* ambient, and the loader tells you so.

### Supplying the sandbox root

The path must be absolute, and `process.cwd()` is the **checkout**, not the kit — so a relative default would confine writes to the wrong tree. The plugin's own default reads `KIT_SANDBOX`, an escape hatch for throwaway experiments; the bundle row computes the real value with `!!js` from `KIT_ROOT`, evaluated at load time:

```yaml
    - id: l4-write-scope
      name: dsh-exploration-kit-plugins/l4/write-scope.js
      config:
        allowedRoot: !!js "process.env.KIT_ROOT ? process.env.KIT_ROOT + '/l4-sandbox' : undefined"
```

Boot with `KIT_ROOT` pointing at your kit, and confirm the plugin's own line names the tree it will defend:

```sh
KIT_ROOT=<kit> dsh --profile kitdemo --port 0 --no-open
```

```
[l4-write-scope] ACTIVE — writes confined to <kit>/l4-sandbox
```

## Step 2 — Test the gate

With a model available, ask the agent to write a file **outside** `l4-sandbox` and confirm the call is denied with your reason string; then ask for a write inside it and confirm it succeeds.

Both outcomes matter. A gate you have only seen deny is a gate you have not tested — an over-broad policy that blocks everything looks identical to a working one until you try the permitted case.

**No API key?** You can still verify everything except the decision itself: the listener registers, the plugin loads, and the configured root reaches `apply`. The allow/deny outcome is the one claim that needs a tool call, and it is recorded as unverified in [VERIFIED.md](https://github.com/kbaynes/dsh-exploration-kit/blob/main/VERIFIED.md) rather than asserted.

## Step 3 — Make a denial irreversible

A waterfall is reorderable: another listener registered after yours could, in principle, decide differently. When a rule genuinely must hold, use the monotonic guard instead. It also lives in the bundle, at `<kit>/kit-plugins/l4/guard.js`:

```js
export const name = 'l4-guard'
export const inject = ['tools']

export function apply(ctx) {
  ctx.tools.guard(exec => {
    if (exec.name === 'bash' && /rm\s+-rf\s+\//.test(JSON.stringify(exec.arguments ?? {}))) {
      return 'refusing a recursive delete of the filesystem root'
    }
    return undefined
  })

  console.log('[l4-guard] ACTIVE — monotonic guard registered')
}
```

`inject` is required here too, for the same reason as the waterfall listener.

Registered guards run **after** the extensible `tools/pre-execute` waterfall, and a returned reason denies the call and cannot be turned back into permission by a later listener. Use the waterfall for configurable, per-deployment policy; use the guard for invariants that must not be negotiable.

## Step 4 — Know the pipeline you are standing in

Every call runs a fixed pipeline. Put your hook at the right stage:

| Stage | Use it for |
|---|---|
| `tools/pre-execute` | Extensible allow / deny / ask policy — the reorderable layer |
| registered guards | Monotonic owner policy that nothing can undo |
| `tools/execute` | Wrapping dispatch for deadline, retry, or metrics (only `exec.signal` is replaceable) |
| `tools/post-execute` | Inspecting or replacing the result, blocking with corrective feedback, attaching context |
| definition-owned `finalizeContent` | The final content transform |
| `tools/result` | Observe-only: the immutable final outcome |

A common mistake is reaching for `post-execute` to implement a *policy* — by then the side effect already happened. Decide before dispatch.

## Step 5 — Prefer the policy that already exists

Before writing another gate, check whether the harness already owns the concern. Your `write-scope` plugin overlaps with existing machinery, and the right move in production is usually to configure it rather than reimplement it:

- **Filesystem intent events.** `fs/write-intent` and `fs/edit-intent` are waterfalls emitted by `tool-fs` and `tool-str-replace-editor`, consumed by `fs-observation-policy`. Policy that is genuinely about *files* belongs here, where it also covers non-tool writers.
- **Sandbox.** `ctx.sandbox` confines spawned processes and has swappable providers — `sandbox-local`, `sandbox-windows-acl`, and `sandbox-ssh` for remote execution. Filesystem and subprocess providers share one execution world, so pointing them at a remote sandbox moves Bash, PTY, and LSP with them, with no provider forks.
- **Permission presets and approval.** `permission-presets` and `user-approval` own the human-interaction side; `tools/pre-execute` returning `{kind:'ask'}` routes into that machinery instead of inventing a prompt.
- **Credential redaction.** `dsh-credentials` redacts at the context level. Do not build string-matching secret filters in a tool wrapper.

Then deliberately break something: relax your `write-scope` to allow everything and confirm that the sandbox policy still confines what it was configured to confine. Defense in depth means your gate is not the only thing standing.

## Verification

**This lesson's decisions do not need a model after all.** `ctx.tools.execute()` takes the same pipeline a model-direct call takes — pre-execute policy, guards, dispatch — so a probe can dispatch a synthetic call and observe the result. It is the technique [ADR-0021](https://github.com/kbaynes/dsh-exploration-kit/blob/main/decisions/0021-exercise-the-tool-pipeline-without-a-model.md) records, and it ships as `<kit>/kit-plugins/l4/policy-probe.js`.

Run it:

```sh
KIT_ROOT=<kit> dsh --profile kitdemo \
  --patch <kit>/solutions/l4.probe.patch.yml --port 0 --no-open
```

```
[l4-probe] write-outside: GATE-DENIED  ...writes are confined to <kit>/l4-sandbox
[l4-probe] write-inside:  OTHER-DENIED ...sandbox: file access denied under workspace-write mode
```

Read those two lines carefully — they are the lesson.

1. **Outside the root is denied by your gate**, and the reason string is yours.
2. **Inside the root is *not* denied by your gate.** It is stopped by a second, independent policy: DSH's own filesystem sandbox, because the target sits outside the agent's workspace. That is what defense in depth looks like, and it is the reason a gate is not the only thing you rely on.
3. **A gate that denied everything would also pass (1).** Only (2) proves it discriminates. Always test the permitted case.

Still needs a provider: `ask` decisions, which require a real approval flow, and the undo-ability of the guard against *another live listener*.

Two argument-name traps this probe hit, both worth knowing:

- dsh's filesystem tools take **`file_path`**, not `path`. The wrong key is rejected by argument validation *before* any policy runs, so it looks like a denial when it is not.
- `ctx.tools.execute()` requires a **`signal`**; omitting it fails with a bare `Cannot read properties of undefined (reading 'aborted')`.

## Exit check — you should now be able to explain

- Why a listener that forgets `next()` changes behavior rather than doing nothing.
- The difference in authority between `tools/pre-execute` and `ctx.tools.guard()`.
- Why argument rewriting is forbidden before dispatch.
- Which of your policy ideas belong to `fs/*`, to `ctx.sandbox`, and to the tool pipeline respectively.
- Why the sandbox root could not simply be a path relative to the process's working directory.

## Next

[L5 — Assemble context deliberately](./05-context-assembly.md).
