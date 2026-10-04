import { mkdtempSync, writeFileSync } from 'node:fs'
import { tmpdir } from 'node:os'
import { join } from 'node:path'
import Schema from '@deepseek-ai/schemastery'

export const name = 'l2-probe'
export const inject = ['tools']

export const Config = Schema.object({
  /** Off by default: this dispatches a real call. */
  enabled: Schema.boolean().default(false),
  delayMs: Schema.number().default(1200),
})

/**
 * Calls this lesson's own tool through the real pipeline, without a model.
 *
 * Lesson 2 registers `word_count` and claims the model can call it, receiving canonical
 * JSON rather than prose. That claim does not need a provider: `ctx.tools.execute()` runs
 * the same pipeline a model-direct call runs, so the call can be dispatched here and the
 * returned value inspected directly.
 *
 * See ADR-0021 for the technique. The `signal` field is required by the input contract;
 * omitting it fails with a bare "Cannot read properties of undefined (reading 'aborted')".
 */
export function apply(ctx, config) {
  if (!config?.enabled) return

  const timer = setTimeout(async () => {
    const dir = mkdtempSync(join(tmpdir(), 'l2-probe-'))
    const file = join(dir, 'sample.txt')
    // Deterministic content: 2 lines, 3 words, known length.
    writeFileSync(file, 'alpha beta\ngamma\n')

    const controller = new AbortController()
    const call = async (label, args) => {
      try {
        const value = await ctx.tools.execute({
          callId: `l2-probe-${label}`,
          name: 'word_count',
          arguments: args,
          signal: controller.signal,
        })
        console.log(`[l2-probe] ${label}: ${JSON.stringify(value)}`)
      } catch (error) {
        console.log(`[l2-probe] ${label}: THREW ${error.message}`)
      }
    }

    console.log('[l2-probe] dispatching word_count through the real pipeline')
    // No `unit`: the tool must fall back to its configured default (`lines` in the bundle).
    await call('default-unit', { path: file })
    // An explicit unit must override the default.
    await call('explicit-words', { path: file, unit: 'words' })
    await call('explicit-chars', { path: file, unit: 'chars' })
    // Invalid arguments must be rejected by schema validation before execute runs.
    await call('invalid-unit', { path: file, unit: 'paragraphs' })
    console.log('[l2-probe] done')
  }, config.delayMs)

  ctx.effect(() => () => clearTimeout(timer))
  console.log('[l2-probe] ACTIVE — will call word_count')
}
