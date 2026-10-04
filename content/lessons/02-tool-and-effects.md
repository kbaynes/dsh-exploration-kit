---
type: Exploration Lesson
title: "L2 — Register a tool, compose with config"
description: Write a model-facing tool with a validated schema, prove config validation fails loudly, and override the row from a patch layer.
resource: dsh
tags: [deepseek-harness, lesson, tools, schemastery, config, patches, composition]
timestamp: 2026-09-30
---

# L2 — Register a tool, compose with config

**Goal.** By the end of this lesson the model has a new capability you wrote, the
tool's arguments are validated before your code runs, and you have changed the
tool's behavior from a patch layer without touching the plugin source.

**Why here.** L1 taught you to mount code. This lesson teaches the first real
extension seam — `ctx.tools` — and the config/composition mechanism every later
lesson uses to vary behavior per deployment.

## Concepts taught

| Concept | What you learn |
|---|---|
| `ctx.tools.register()` | The model-facing capability seam; schemas join prompt assembly automatically |
| `defineTool` | Typed args, a canonical output value, and a separate render step |
| Schema-driven validation | Args are validated against the spec *before* `execute` runs |
| Effect-scoped registration | Disposing the plugin fiber unregisters the tool |
| Schemastery config | Config is validated before `apply` runs, so a plugin never runs half-configured |
| Patch layers | Override a row's config from your own overlay, last write wins |
| `!!js` | Compute config or `disabled` at load time |

Reference: the repository's
[adding-a-tool cookbook](https://github.com/deepseek-ai/deepseek-harness/blob/main/docs/cookbook/adding-a-tool.md)
and its
[build-a-tool guide](https://github.com/deepseek-ai/deepseek-harness/blob/main/docs/user/develop/basic/tool.md).
Production-grade reference implementation: `packages/shell/tool-bash`.

## Prerequisites

L1 complete: you can mount a plugin from a patch file and read its boot output.

## Step 1 — A tool with a real contract

Create `<kit>/plugins/l2/wordcount.ts`:

```ts
import { readFile } from 'node:fs/promises'
import type { Context } from '@deepseek-ai/cordis'
import { defineTool } from '@deepseek-ai/dsh-tools'
import Schema from '@deepseek-ai/schemastery'

export const name = 'l2-wordcount'
export const inject = ['tools']

export interface Config {
  defaultUnit: 'words' | 'lines' | 'chars'
}

export const Config: Schema<Config> = Schema.object({
  defaultUnit: Schema.union(['words', 'lines', 'chars']).default('words'),
})

export function apply(ctx: Context, config: Config) {
  ctx.tools.register(defineTool({
    name: 'word_count',
    description: 'Count lines, words, and characters in a file.',
    parameters: {
      path: { type: 'string', required: true, description: 'Absolute path' },
      unit: { type: 'string', enum: ['words', 'lines', 'chars'] },
    },
    output: {
      schema: {
        type: 'object',
        properties: {
          unit: { type: 'string' },
          count: { type: 'number' },
        },
        required: ['unit', 'count'],
      },
      render: (_args, value) => [
        { type: 'text', text: `${value.count} ${value.unit}` },
      ],
    },
    async execute(args, exec) {
      const text = await readFile(args.path, { encoding: 'utf8', signal: exec.signal })
      const unit = args.unit ?? config.defaultUnit
      const count = unit === 'lines'
        ? text.split('\n').length - 1
        : unit === 'chars'
          ? text.length
          : text.split(/\s+/).filter(Boolean).length
      return { unit, count }
    },
  }))
}
```

Four contract rules are worth internalizing now, because every tool you write in
later lessons obeys them:

1. **`args` is typed from `parameters`** and validated for you before `execute`
   runs — types, required keys, enums, nested values. Constraints the DSL cannot
   express (non-empty string, positive number, cross-field rules) are still yours
   to check.
2. **Return one canonical JSON value matching `output.schema`.** Do not return
   content blocks and do not make callers parse prose for fields.
3. **`render` owns model-facing prose.** UI presentation is a separate concern.
4. **Honor `exec.signal`** and cancel in-flight work when it fires.

## Step 2 — Mount it

`<kit>/plugins/l2.patch.yml`:

```yaml
- insert:
    - id: l2-wordcount
      name: './l2/wordcount.ts'
```

Boot it (random port, no browser):

```sh
dsh --profile web --patch ./<kit>/plugins/l2.patch.yml --port 0 --no-open
```

Then open the printed URL, start a session, and ask: *"Use word_count on
`<some file path>`."* The model now sees the tool because registration flows into
prompt assembly automatically.

**No API key?** You can still complete this lesson's verification path: the tool's
schema is registered at load, so an invalid config (step 3) and a patch override
(step 4) are observable without a model call.

## Step 3 — Break the config on purpose

The plugin you wrote in step 1 already declares its `Config` schema — that is the
Schemastery block carrying `defaultUnit`. Two properties of that pattern matter:

- The exported `Config` is a TypeScript interface *and* a runtime schema of the
  same name, so consumers get the type and Cordis gets the validator.
- Defaults are filled in, so `apply` always receives complete, validated config.

Cordis accepts any [Standard Schema](https://standardschema.dev/) validator, but a
plain object exported as `Config` will not work.

Supply it from the patch:

```yaml
- insert:
    - id: l2-wordcount
      name: './l2/wordcount.ts'
      config:
        defaultUnit: lines
```

Now break it on purpose — set `defaultUnit: paragraphs` and boot. The plugin fails
to load with a precise error naming the field, because the schema rejects the value
before `apply` ever sees it:

```
ValidationError: invalid config:
  - $.defaultUnit ... (at defaultUnit)
```

The fiber goes to `FAILED`. This is the guarantee that a plugin never runs
half-configured. Revert to a valid value.

Do not remove the import or the pattern to "simplify" — a schema-valid config that
names an unavailable resource should still be rejected as early as the plugin can
resolve that reference. Early loud rejection is the house style.

## Step 4 — Override from your own layer

Without editing the file above, create `<kit>/plugins/l2.override.patch.yml`:

```yaml
- id: l2-wordcount
  config:
    defaultUnit: chars
```

Boot with both overlays, patch order matters:

```sh
dsh --profile web \
  --patch ./<kit>/plugins/l2.patch.yml \
  --patch ./<kit>/plugins/l2.override.patch.yml \
  --port 0 --no-open
```

A patch **replaces the targeted row's whole `config`** rather than merging into
it — which is why the base bundle's comments insist a row with mode-specific
values belongs to each mode bundle. Confirm with `--dump-config` that `chars` won.

## Step 5 — `!!js` for load-time values

Patch config values may be computed at load time:

```yaml
- id: l2-wordcount
  config:
    defaultUnit: !!js "process.env.L2_UNIT ?? 'words'"
```

`!!js` is interpolated inside an entry's `config` and its `disabled` field only;
other entry metadata stays literal. Try it, then move on — you will use `!!js`
seriously in L3 for conditional mounting.

## Verification

1. `--dump-config` shows the tool row with your resolved config.
2. An invalid enum value makes the boot fail with a validation error naming the
   field.
3. Two stacked `--patch` flags show last-write-wins on the config row.
4. With a model available, `word_count` executes and returns canonical JSON that
   the model restates correctly — proof the render step is doing its job.

## Exit check — you should now be able to explain

- Where arg validation happens relative to your `execute` body, and what it
  deliberately does not cover.
- Why registration is described as an effect, and what unregisters the tool.
- Why a patch replacing a whole config block is a feature, not an oversight.
- What `!!js` is allowed to touch.

## Further exploration

- `run_code` (PTC mode) reaches your tool for free: in a composition with
  `mode: ptc` or `both`, a program can call `await tools.word_count({...})` and
  receive the canonical value after policy. If your profile has it, try it.
- Read `packages/core/tools/README.md` for the full execution pipeline:
  `tools/pre-execute` → guards → `tools/execute` → `tools/post-execute` →
  `tools/result`. You will use it in L4.

## Next

[L3 — Services, isolation, and hot reload](./03-service-and-hmr.md).
