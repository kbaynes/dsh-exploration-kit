/**
 * Audits every active entry's plugin `Config`, and reports any that is not a working schema.
 *
 * It was written to hunt a turn-killing `cannot get property "toJSON" without inject` error. The
 * hypothesis was that some entry's `Config` was a Cordis Context proxy: the harness's settings
 * plugin guards with `'toJSON' in schema` (true for such a proxy) and then calls `schema.toJSON()`.
 * That hypothesis was WRONG, and this audit is the evidence: it reports every entry's Config as a
 * valid schema. The real cause was the kit's own Lesson 5 pre-step listener stringifying a live
 * event payload (see ADR-0028) - a reminder to audit your own plugins before blaming the harness.
 *
 * The audit is still a useful probe for a composition that will not start: an entry whose `Config`
 * is not a schema is a real failure mode, it is just not this one. Diagnostic only, off by default.
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
