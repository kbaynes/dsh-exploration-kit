---
type: Exploration Lesson
title: "L2 — Register a tool, compose with config"
description: Write a model-facing tool with a validated schema, prove config validation fails loudly, and override the row from a patch layer.
resource: dsh
tags: [deepseek-harness, lesson, tools, schemastery, config, patches, composition]
timestamp: 2026-09-30
---

# L2 — Register a tool, compose with config

**Goal.** By the end of this lesson the model has a new capability you wrote, the tool's arguments are validated before your code runs, and you have changed the tool's behavior from a patch layer without touching the plugin source.

**Why here.** L1 taught you to mount code. This lesson teaches the first real extension seam — `ctx.tools` — and the config/composition mechanism every later lesson uses to vary behavior per deployment.

## Concepts taught

| Concept | What you learn |
|---|---|
| `ctx.tools.register()` | The model-facing capability seam; schemas join prompt assembly automatically |
| `defineTool` | Typed args, a canonical output value, and a separate render step |
| Schema-driven validation | Args are validated against the spec *before* `execute` runs |
| Effect-scoped registration | Disposing the plugin fiber unregisters the tool |
| Schemastery config | Config is validated before `apply` runs, so a plugin never runs half-configured |
| Config override | Patch an already-installed row in place, whole-`config` replacement |
| `!!js` | Compute config or `disabled` at load time |

Reference: the repository's [adding-a-tool cookbook](https://github.com/deepseek-ai/deepseek-harness/blob/main/docs/cookbook/adding-a-tool.md) and its [build-a-tool guide](https://github.com/deepseek-ai/deepseek-harness/blob/main/docs/user/develop/basic/tool.md). Production-grade reference implementation: `packages/shell/tool-bash`.

## Prerequisites

L1 complete: the kit's bundle is installed in a `link:` profile (`kitdemo`), and you can read a plugin's boot output.

## Step 1 — A tool with a real contract

**Write this one yourself, into the bundle.** Open `<kit>/kit-plugins/l2/wordcount.js` and replace its contents with the listing below.

Two things about that location are the point, and both follow from L1:

- **It has to be in the bundle.** The plugin imports `@deepseek-ai/dsh-tools` and `@deepseek-ai/schemastery`, and L1 showed what happens to a loose file that imports dsh packages: it fails to activate. The bundle is where a real plugin lives, so this is where you write it.
- **Saving is enough.** The bundle is installed with `link:`, so your file is what the row mounts the moment you save. If you delete your version, the lesson's verification outcomes disappear with it — that is the test that you are running your own code rather than a shipped artifact.

```js
import { readFile } from 'node:fs/promises'
import { defineTool } from '@deepseek-ai/dsh-tools'
import Schema from '@deepseek-ai/schemastery'

```ts
import { readFile } from 'node:fs/promises'
import type { Context } from '@deepseek-ai/cordis'
import { defineTool } from '@deepseek-ai/dsh-tools'
import Schema from '@deepseek-ai/schemastery'

export const name = 'l2-wordcount'
export const inject = ['tools']

// One export is both a TypeScript type and a runtime validator: consumers get the
// type, Cordis gets the validator that runs before apply().
export const Config = Schema.object({
  defaultUnit: Schema.union(['words', 'lines', 'chars']).default('words'),
})

export function apply(ctx, config) {
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
        additionalProperties: false,
        properties: {
          unit: { type: 'string', required: true },
          count: { type: 'number', required: true },
        },
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

Four contract rules are worth internalizing now, because every tool you write in later lessons obeys them:

1. **`args` is typed from `parameters`** and validated for you before `execute` runs — types, required keys, enums, nested values. Constraints the DSL cannot express (non-empty string, positive number, cross-field rules) are still yours to check.
2. **Return one canonical JSON value matching `output.schema`.** Do not return content blocks and do not make callers parse prose for fields.
3. **`render` owns model-facing prose.** UI presentation is a separate concern.
4. **Honor `exec.signal`** and cancel in-flight work when it fires.

## Step 2 — Mount it

Open `<kit>/kit-plugins/cordis.patch.yml`. It already has a row for this lesson:

```yaml
- insert:
    - id: l2-wordcount
      name: dsh-exploration-kit-plugins/l2/wordcount.js
      config:
        defaultUnit: lines
```

Nothing to install — L1's bundle is already linked, so this row is live. Confirm the row composed:

```sh
cd <path/to/deepseek-harness>
dsh --profile kitdemo --dump-config | grep -A4 'id: l2-wordcount'
```

Then boot it (random port, no browser):

```sh
dsh --profile kitdemo --port 0 --no-open
```

You should see the plugin's own confirmation line among the startup output:

```
[l2-wordcount] ACTIVE — defaultUnit=lines
```

That line is worth pausing on: it proves three separate things worked. The module **loaded** (so its `@deepseek-ai/dsh-tools` and `@deepseek-ai/schemastery` imports resolved), your **`Config` schema validated**, and the value reaching `apply` is `lines` — the value the row's `config` block supplied, not the schema default.

Two traps worth knowing, both encountered while building this lesson:

- **New rows go under `insert:`.** A top-level `- id: ...` entry targets an *existing* row for override. Targeting a new id does **not** fail the boot — it prints `patch: entry "<id>" not found` as a warning and silently skips the patch. The symptom is a missing row in `--dump-config`, not an error.
- **A row named by a relative file path cannot import dsh packages.** Rows in this bundle are named by *package* (`dsh-exploration-kit-plugins/...`) precisely so Node resolves them through the profile's installation. See L1 step 2.

Now open the printed URL, start a session, and ask: *"Use word_count on `<some file path>`."* The model sees the tool because registration flows into prompt assembly automatically.

**No API key?** Everything except that last sentence is still verifiable without a model: the plugin loads, the schema validates, and the config value changes. Those are steps 3 and 4.

## Step 3 — Break the config on purpose

The plugin you wrote in step 1 already declares its `Config` schema — that is the Schemastery block carrying `defaultUnit`. Two properties of that pattern matter:

- The exported `Config` is a TypeScript interface *and* a runtime schema of the same name, so consumers get the type and Cordis gets the validator.
- Defaults are filled in, so `apply` always receives complete, validated config.

Cordis accepts any [Standard Schema](https://standardschema.dev/) validator, but a plain object exported as `Config` will not work.

The bundle row supplies it. Now break it on purpose: edit the row in `<kit>/kit-plugins/cordis.patch.yml` to `defaultUnit: paragraphs` and boot again. This time the plugin never activates, and the startup summary tells you why:

```
dsh: warning: 1 entry did not activate
l2-wordcount (dsh-exploration-kit-plugins/l2/wordcount.js): ValidationError: invalid config:
  - $.defaultUnit expected "words" | "lines" | "chars" but got "paragraphs" (at defaultUnit)
    at resolveConfig (file:///<checkout>/vendor/cordis/lib/index.js:960:27)
    ...
```

The schema rejects the value **before `apply` ever sees it**, which is the guarantee that a plugin never runs half-configured. Because you installed with `link:`, a save is enough — no reinstall.

Note what is *not* here: no partial startup, no `defaultUnit` silently falling back, no log line from your `apply`. Restore `lines` before continuing.

Do not remove the schema to "simplify" — a schema-valid config that names an unavailable resource should still be rejected as early as the plugin can resolve that reference. Early loud rejection is the house style.

## Step 4 — Override an installed row's config

This is the everyday use of the overlay mechanism, and the reason L1 did not declare it dead: you often need to change a row's config **without forking the bundle that owns it**.

Create `<kit>/plugins/l2.override.patch.yml`:

```yaml
- id: l2-wordcount
  config:
    defaultUnit: chars
```

Note the shape: no `insert`, and no `name`. A top-level `- id:` entry *patches an existing row in place* — which is exactly why L1 warned that this form silently does nothing when the id does not exist yet.

Boot with your overlay applied on top of the profile:

```sh
dsh --profile kitdemo --patch <kit>/plugins/l2.override.patch.yml --port 0 --no-open
```

Watch the startup line: it now reads `defaultUnit=chars`. Confirm with `--dump-config` that `chars` won.

A patch **replaces the targeted row's whole `config`** rather than merging into it. That is why the shipped bundles' comments insist a row whose value differs by mode belongs to each mode bundle: one `config` block is the whole story, and a patch overwrites it entirely.

## Step 5 — `!!js` for load-time values

Patch config values may be computed at load time:

```yaml
- id: l2-wordcount
  config:
    defaultUnit: !!js "process.env.L2_UNIT ?? 'words'"
```

`!!js` is interpolated inside an entry's `config` and its `disabled` field only; other entry metadata stays literal. Try it in your override file, then move on — you will use `!!js` seriously in L4, to compute a policy plugin's confinement root.

One caution learned the hard way: `--dump-config` prints `!!js` expressions **verbatim, unevaluated**. So the dump shows you the expression, not the value it produced. To see the evaluated value, read the plugin's own startup line.

## Verification

Observable without a model:

1. The startup line reads `[l2-wordcount] ACTIVE — defaultUnit=lines`, proving the module loaded, the schema validated, and the row's config reached `apply`.
2. Setting `defaultUnit: paragraphs` stops the plugin activating and names the offending field.
3. Your overlay patch, applied with `--patch`, changes the startup line to `defaultUnit=chars` without you editing the bundle.

**The tool's own behaviour does not need a provider either.** `ctx.tools.execute()` runs the same pipeline a model-direct call runs, so `<kit>/kit-plugins/l2/tool-probe.js` can call `word_count` directly and you can read the result:

```sh
dsh --profile kitdemo --patch <kit>/solutions/l2.probe.patch.yml --port 0 --no-open
```

```
[l2-probe] default-unit:    {"isError":false,"content":[{"type":"text","text":"2 lines"}],"value":{"unit":"lines","count":2}}
[l2-probe] explicit-words:  {"isError":false,"content":[{"type":"text","text":"3 words"}],"value":{"unit":"words","count":3}}
[l2-probe] invalid-unit:    {"isError":true,"error":{"message":"invalid arguments: \"unit\" must be one of ..."}}
```

Four claims, one run:

1. **The row's `config` reaches the tool** — `default-unit` returns `lines`, the value the bundle row supplies, not the schema default.
2. **An explicit argument overrides it** — `explicit-words` returns `words`.
3. **Invalid arguments are rejected before `execute` runs** — the third line is an argument-validation error, not a result from your code.
4. **`value` and `content` are separate.** `content` carries the rendered prose (`"2 lines"`) while `value` carries the canonical JSON (`{"unit":"lines","count":2}`). That is the split the contract asks for, visible in a single result rather than asserted.

What still needs a model is narrower than it looks: whether a model *chooses* to call the tool, and whether it restates the value well. That is a question about the model, not about your tool.

> **Where this lesson stands.** Every step above has been executed against a real harness, and the output is quoted in [VERIFIED.md](https://github.com/kbaynes/dsh-exploration-kit/blob/main/VERIFIED.md). Nothing in this lesson needs a provider; what remains outside it is the model's own behaviour, which is named rather than glossed.

## Exit check — you should now be able to explain

- Where arg validation happens relative to your `execute` body, and what it deliberately does not cover.
- Why registration is described as an effect, and what unregisters the tool.
- Why a patch replacing a whole config block is a feature, not an oversight.
- What `!!js` is allowed to touch.
- Why an override entry has no `insert` and no `name`, and what happens if its `id` does not match an installed row.

## Further exploration

- `run_code` (PTC mode) reaches your tool for free: in a composition with `mode: ptc` or `both`, a program can call `await tools.word_count({...})` and receive the canonical value after policy. If your profile has it, try it.
- Read `packages/core/tools/README.md` for the full execution pipeline: `tools/pre-execute` → guards → `tools/execute` → `tools/post-execute` → `tools/result`. You will use it in L4.

## Next

[L3 — Services, isolation, and hot reload](./03-service-and-hmr.md).
