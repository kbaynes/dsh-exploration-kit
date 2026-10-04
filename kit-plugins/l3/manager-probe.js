import Schema from '@deepseek-ai/schemastery'

export const name = 'l3-probe'
export const inject = ['pluginManager']

export const Config = Schema.object({
  /** Off by default: this toggles a real plugin row. */
  enabled: Schema.boolean().default(false),
  /** The row Lesson 3's step 5 asks the reader to disable and re-enable. */
  target: Schema.string().default('l3-uses-clock'),
  delayMs: Schema.number().default(1500),
})

/**
 * Tests Lesson 3's runtime-management claim without a model.
 *
 * The lesson tells the reader to disable the consumer's row from the `plugin_manager` tool
 * and watch it disappear without a restart. The tool is model-facing; the SERVICE behind it
 * is `ctx.pluginManager`, and it is callable directly — so the same reverse experiment runs
 * here with no provider involved.
 *
 * It re-enables what it disabled. The change would also persist to the profile patch, which
 * is another reason verification belongs in a disposable harness home (ADR-0023).
 */
export function apply(ctx, config) {
  if (!config?.enabled) return

  const timer = setTimeout(async () => {
    try {
      const report = async label => {
        const plugins = await ctx.pluginManager.listPlugins()
        const mine = plugins.filter(p => String(p.id).startsWith('l3-'))
        console.log(`[l3-probe] ${label}: ${plugins.length} row(s) total; l3 rows: ${mine.map(p => `${p.id}=${p.enabled ? 'enabled' : 'disabled'}`).join(', ')}`)
        return plugins
      }

      await report('initial')
      const before = await ctx.pluginManager.setPluginEnabled(config.target, false)
      console.log(`[l3-probe] disabled ${config.target}: ${JSON.stringify(before).slice(0, 120)}`)
      await report('after disable')

      const after = await ctx.pluginManager.setPluginEnabled(config.target, true)
      console.log(`[l3-probe] re-enabled ${config.target}: ${JSON.stringify(after).slice(0, 120)}`)
      await report('after re-enable')

      const bundles = await ctx.pluginManager.listBundles()
      console.log(`[l3-probe] bundles: ${bundles.length} total; kit bundle present: ${bundles.some(b => String(b.name).includes('exploration-kit'))}`)

      // Where do the KIT's rows appear? The manager's view is worth inspecting rather than
      // assumed: the lesson tells the reader to toggle a row, so the row must be visible.
      const all = await ctx.pluginManager.listPlugins()
      const ids = all.map(p => String(p.id))
      for (const probeOf of ['l1-hello', 'l2-wordcount', 'l3-clock', 'l3-uses-clock', 'exploration']) {
        const hits = ids.filter(id => id.includes(probeOf))
        console.log(`[l3-probe] ids containing "${probeOf}": ${hits.length ? hits.join(', ') : '(none)'}`)
      }
      console.log(`[l3-probe] sample ids: ${ids.slice(0, 6).join(', ')}`)
      const shapes = Object.keys(all[0] ?? {})
      console.log(`[l3-probe] entry fields: ${shapes.join(', ')}`)
    } catch (error) {
      console.log(`[l3-probe] FAILED: ${error.message}`)
      console.log(String(error.stack ?? '').split('\n').slice(1, 4).join('\n'))
    } finally {
      console.log('[l3-probe] done')
    }
  }, config.delayMs)

  ctx.effect(() => () => clearTimeout(timer))
  console.log('[l3-probe] ACTIVE — will toggle a plugin row at runtime')
}
