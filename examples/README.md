# Examples

The exact files each lesson presents, so you can read or copy them instead of transcribing. **Generated** from `../kit-plugins/` — that directory is canonical, because it is what actually boots in a profile.

Regenerate after editing a lesson plugin:

```sh
node scripts/sync-examples.mjs
node scripts/sync-examples.mjs --check   # fails if this mirror has drifted
```

## Contents

| File | Lesson | What it shows |
|---|---|---|
| `l1/hello.ts` | [1](../content/lessons/01-plugin-lifecycle.md) | The smallest plugin, and why a type-only `.ts` import survives Node's type erasure |
| `l2/wordcount.js` | [2](../content/lessons/02-tool-and-effects.md) | A model-facing tool with a validated argument schema and a Schemastery `Config` |
| `l3/clock.js` | [3](../content/lessons/03-service-and-hmr.md) | Providing a `Service` as `ctx.lessonClock` |
| `l3/uses-clock.js` | [3](../content/lessons/03-service-and-hmr.md) | Consuming a service via `inject`, and what `PENDING` looks like |
| `l3/diagnose.js` | [3](../content/lessons/03-service-and-hmr.md) | Walking the fiber registry; avoids the erased `FiberState` const enum |
| `l4/write-scope.js` | [4](../content/lessons/04-policy-waterfalls.md) | A `tools/pre-execute` waterfall that denies writes outside a configured root |
| `l4/guard.js` | [4](../content/lessons/04-policy-waterfalls.md) | A monotonic `ctx.tools.guard()` denial nothing can reverse |
| `cordis.patch.yml` | all | The bundle layer: one row per exercise, named by package |

## Why these are generated rather than hand-written

A hand-maintained copy drifts. When a lesson's code and the booting code disagree, the lesson is wrong and nobody notices until a reader hits it. Mirroring the booting files — with a `--check` mode — means the disagreement is a failing check instead of a support request.

## Related

- [`../kit-plugins/`](../kit-plugins/README.md) — the canonical bundle, and why plugins must ship as one
- [`../solutions/`](../solutions/README.md) — the answer key and per-lesson verification scripts
