/**
 * Finds the entry whose plugin `Config` is not a schema.
 *
 * DSH's settings plugin guards with `'toJSON' in schema`, which is TRUE for a Cordis Context proxy -
 * and *calling* `.toJSON()` on that proxy throws `cannot get property "toJSON" without inject`,
 * which is how an agent turn ends up failing inside the settings plugin. This audit walks the same
 * entry list `describe()` walks and reports which entry has a `Config` that is not a schema.
 *
 * Diagnostic only, disabled by default.
 */
export const name = 'l3-config-audit'
export const inject = ['configEditor']

export function apply(ctx) {
  const timer = setTimeout(() => {
    let entries = []
    try {
      entries = ctx.configEditor.configuration()
    } catch (error) {
      console.log(`[l3-audit] could not read the configuration: ${error.message}`)
      return
    }

    console.log(`[l3-audit] ${entries.length} entry(ies) in the configuration`)
    for (const { entry } of entries) {
      const config = entry?.fiber?.runtime?.Config
      if (config === undefined) continue
      const ctor = config?.constructor?.name ?? typeof config
      let hasToJSON = false
      let callable = 'n/a'
      try {
        hasToJSON = 'toJSON' in config
      } catch (error) {
        hasToJSON = `threw: ${error.message}`
      }
      if (hasToJSON === true) {
        try {
          const out = config.toJSON()
          callable = out === undefined ? 'returned undefined' : 'ok'
        } catch (error) {
          callable = `THREW: ${error.message}`
        }
      }
      if (callable !== 'ok' && hasToJSON !== false) {
        console.log(`[l3-audit] SUSPECT ${entry.id ?? entry.options?.id} ctor=${ctor} hasToJSON=${hasToJSON} toJSON()=${callable}`)
      }
    }
    console.log('[l3-audit] done')
  }, 1500)
  ctx.effect(() => () => clearTimeout(timer))
  console.log('[l3-audit] ACTIVE — will audit entry Configs')
}
