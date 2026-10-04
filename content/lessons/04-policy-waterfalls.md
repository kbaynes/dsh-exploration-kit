---
type: Exploration Lesson
title: "L4 — Build a policy gate"
description: Intercept tool calls with a waterfall listener, deny by policy, add a monotonic guard, and route filesystem and sandbox policy through the seams that already own it.
resource: dsh
tags: [deepseek-harness, lesson, policy, waterfalls, events, sandbox, permissions]
timestamp: 2026-09-30
---

# L4 — Build a policy gate

**Goal.** By the end of this lesson you have a plugin that denies a tool call by
policy, a second one whose denial nothing can undo, and a clear map of which
policies already exist so you extend rather than duplicate them.

**Why here.** L1–L3 taught you to add capability. This lesson is the first that
*removes* or constrains capability — the skill that separates a demo harness from
a deployable one.

## Concepts taught

| Concept | What you learn |
|---|---|
| `tools/pre-execute` | The reorderable allow / deny / ask decision point |
| Waterfall dispatch | A listener receives `(...args, next)`, delegates with `next()`, or short-circuits |
| The decision union | `{kind:'allow'}`, `{kind:'deny', reason}`, `{kind:'ask', reason?}`, `{kind:'cancel'}` |
| Monotonic guards | `ctx.tools.guard()` — a denial no later listener can reverse |
| The full pipeline | pre-execute → guards → execute → post-execute → finalizeContent → result |
| `fs/*` policy | `fs/write-intent` and `fs/edit-intent` waterfalls |
| Sandbox seam | `ctx.sandbox` confines spawned processes; providers are swappable |
| Credential redaction | Context-level redaction rather than tool-level string matching |

Reference: the repository's
[extension cookbook permission-gate example](https://github.com/deepseek-ai/deepseek-harness/blob/main/docs/cookbook/extension-cookbook.md),
`packages/core/tools/README.md`, and the [plugin model](https://github.com/deepseek-ai/deepseek-harness/blob/main/docs/user/develop/framework/index.md) for
waterfall semantics.

## Prerequisites

L1–L3 complete. L3 in particular: you need the reload loop to iterate on a policy
without restarting.

## Step 1 — A working deny-by-policy gate

Create `<kit>/plugins/l4/write-scope.ts`:

```ts
import { resolve, sep } from 'node:path'
import type { Context } from '@deepseek-ai/cordis'
import type { PreToolDecision, ToolExecution } from '@deepseek-ai/dsh-tools'

const ALLOWED_ROOT = resolve(process.cwd(), '<kit>/plugins/l4/sandbox')

function isMutatingFsTool(name: string) {
  return name === 'write' || name === 'edit' || name === 'str_replace_editor'
}

function targetPath(exec: ToolExecution): string | undefined {
  const args = exec.arguments as Record<string, unknown>
  const value = args.path ?? args.file_path ?? args.filePath
  return typeof value === 'string' ? value : undefined
}

export const name = 'l4-write-scope'

export function apply(ctx: Context) {
  ctx.on('tools/pre-execute', async (exec, next): Promise<PreToolDecision> => {
    if (!isMutatingFsTool(exec.name)) return next()

    const target = targetPath(exec)
    if (target === undefined) {
      return { kind: 'ask', reason: `${exec.name} without a resolvable path` }
    }

    const absolute = resolve(process.cwd(), target)
    if (absolute !== ALLOWED_ROOT && !absolute.startsWith(ALLOWED_ROOT + sep)) {
      return { kind: 'deny', reason: `writes are confined to ${ALLOWED_ROOT}` }
    }
    return next()
  })
}
```

Three details are the whole lesson:

- **`return next()` delegates.** A listener that only observes must call `next()`
  or it silently vetoes the pipeline. `next()` resolves to the downstream
  decision, not to permission.
- **Returning without `next()` is a short-circuit.** That is the design for
  single-decision events: a policy listener owns the decision.
- **`exec.arguments` is frozen and deliberately not rewritable.** The repository
  states outright that `tools/pre-execute` cannot rewrite arguments, because
  logged and rendered args would desync from what actually ran. Read them; do not
  try to normalize them here.

Create the allowed directory and mount the plugin from
`<kit>/plugins/l4.patch.yml`:

```yaml
- insert:
    - id: l4-write-scope
      name: './l4/write-scope.ts'
```

## Step 2 — Test the gate

With a model available, ask the agent to write a file outside
`<kit>/plugins/l4/sandbox` and confirm the call is denied with your reason
string, then ask for a write inside the sandbox and confirm it succeeds.

Without a model, exercise the gate directly through the same runtime by using
`run_code` in a PTC composition, or simply trust the reload loop: change the
`reason` text and watch it appear on the next denied call. Either way, confirm
**both** outcomes — a gate you have only seen deny is a gate you have not tested.

## Step 3 — Make a denial irreversible

A waterfall is reorderable: another listener registered after yours could, in
principle, decide differently. When a rule genuinely must hold, use the monotonic
guard instead:

```ts
export function apply(ctx: Context) {
  ctx.tools.guard(exec => {
    if (exec.name === 'bash' && /rm\s+-rf\s+\//.test(JSON.stringify(exec.arguments))) {
      return 'refusing a recursive delete of the filesystem root'
    }
    return undefined
  })
}
```

Registered guards run **after** the extensible `tools/pre-execute` waterfall, and a
returned reason denies the call and cannot be turned back into permission by a
later listener. Use the waterfall for configurable, per-deployment policy; use the
guard for invariants that must not be negotiable.

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

A common mistake is reaching for `post-execute` to implement a *policy* — by then
the side effect already happened. Decide before dispatch.

## Step 5 — Prefer the policy that already exists

Before writing another gate, check whether the harness already owns the concern.
Your `write-scope` plugin overlaps with existing machinery, and the right move in
production is usually to configure it rather than reimplement it:

- **Filesystem intent events.** `fs/write-intent` and `fs/edit-intent` are
  waterfalls emitted by `tool-fs` and `tool-str-replace-editor`, consumed by
  `fs-observation-policy`. Policy that is genuinely about *files* belongs here,
  where it also covers non-tool writers.
- **Sandbox.** `ctx.sandbox` confines spawned processes and has swappable
  providers — `sandbox-local`, `sandbox-windows-acl`, and `sandbox-ssh` for remote
  execution. Filesystem and subprocess providers share one execution world, so
  pointing them at a remote sandbox moves Bash, PTY, and LSP with them, with no
  provider forks.
- **Permission presets and approval.** `permission-presets` and `user-approval`
  own the human-interaction side; `tools/pre-execute` returning `{kind:'ask'}`
  routes into that machinery instead of inventing a prompt.
- **Credential redaction.** `dsh-credentials` redacts at the context level. Do not
  build string-matching secret filters in a tool wrapper.

Then deliberately break something: relax your `write-scope` to allow everything
and confirm that the sandbox policy still confines what it was configured to
confine. Defense in depth means your gate is not the only thing standing.

## Verification

1. A write outside the sandbox is denied with your exact reason string.
2. A write inside the sandbox succeeds.
3. A guard denial survives even with your waterfall listener returning `next()`.
4. You can name which pipeline stage would be wrong for a policy decision, and why.

## Exit check — you should now be able to explain

- Why a listener that forgets `next()` changes behavior rather than doing nothing.
- The difference in authority between `tools/pre-execute` and `ctx.tools.guard()`.
- Why argument rewriting is forbidden before dispatch.
- Which of your policy ideas belong to `fs/*`, to `ctx.sandbox`, and to the tool
  pipeline respectively.

## Next

[L5 — Assemble context deliberately](./05-context-assembly.md).
