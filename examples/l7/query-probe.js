import Schema from '@deepseek-ai/schemastery'

export const name = 'l7-probe'
export const inject = ['agents', 'sessionQuery']

export const Config = Schema.object({
  /** Off by default: this creates a session and queries history. */
  enabled: Schema.boolean().default(false),
  /** 'write' creates and appends; 'read' only re-reads a fixed session id. */
  mode: Schema.union(['query', 'write', 'read']).default('query'),
  /** The fixed session id used by the write/read modes. */
  sessionId: Schema.string().default('session-l7-durability'),
  delayMs: Schema.number().default(1800),
  /** The five model-facing tool names Lesson 7 enables. */
  expectedTools: Schema.array(Schema.string()).default([
    'session_search', 'session_event_search', 'session_trace', 'session_event_trace', 'session_event_read',
  ]),
})

/**
 * Verifies Lesson 7's substance WITHOUT a model.
 *
 * `ctx.sessionQuery` is the service behind the five model-facing tools. The tools add
 * schema, prompt, and workspace authorization; the service is what a code caller uses, so
 * the same store and the same reads can be exercised here directly.
 *
 * It also checks WHERE the five tools register. Lesson 7 says a live root Agent's scope,
 * which is a claim about `agent.ctx` rather than the global registry — the kind of claim
 * that quietly stops being true.
 */
export function apply(ctx, config) {
  if (!config?.enabled) return

  const timer = setTimeout(async () => {
    let handle
    try {
      if (config.mode === 'read') {
        // Second boot: does a session holding a plugin-declared event type still read?
        try {
          const reopened = await ctx.sessionQuery.readSession(config.sessionId)
          const eventCount = (reopened?.events ?? []).length
          console.log(`[l7-probe] RE-READ ok: ${eventCount} event(s) from ${config.sessionId}`)
        } catch (error) {
          console.log(`[l7-probe] RE-READ FAILED: ${error.message}`)
        }
        try {
          const sessions = await ctx.sessionQuery.listSessions()
          const found = sessions.some(record => JSON.stringify(record).includes(config.sessionId))
          console.log(`[l7-probe] listSessions includes it: ${found}`)
        } catch (error) {
          console.log(`[l7-probe] listSessions FAILED: ${error.message}`)
        }
        return
      }

      const marker = `l7-probe-marker-${Date.now()}`
      const useFixed = config.mode === 'write'
      handle = await ctx.agents.create({
        sessionId: useFixed ? config.sessionId : `session-l7-probe-${Date.now()}`,
        meta: { cwd: process.cwd() },
      })
      const session = handle.agent.session
      session.append('l6/step', { label: marker, count: 1 })
      console.log(`[l7-probe] created ${session.id} with a distinctive marker`)

      const sessions = await ctx.sessionQuery.listSessions()
      // The record shape is not the session id at the top level, so find it by scanning
      // the serialized record rather than guessing a field name.
      const mine = sessions.find(record => JSON.stringify(record).includes(String(session.id)))
      console.log(`[l7-probe] listSessions: ${sessions.length} total; mine found: ${Boolean(mine)}`)
      if (mine) console.log(`[l7-probe] my record: ${JSON.stringify(mine).slice(0, 200)}`)
      else if (sessions.length) console.log(`[l7-probe] a record looks like: ${JSON.stringify(sessions[0]).slice(0, 200)}`)

      const log = await ctx.sessionQuery.readSession(session.id)
      const events = log?.events ?? []
      console.log(`[l7-probe] readSession: ${events.length} event(s); marker present: ${JSON.stringify(events).includes(marker)}`)

      try {
        // Filter clauses are ANDed, in an ARRAY, and each clause carries a `kind`.
        // A bare `{ text }` is rejected with "session unknown filter kind (missing)".
        const byType = await ctx.sessionQuery.filterEvents(session.id, [{ kind: 'type', values: ['l6/step'] }])
        console.log(`[l7-probe] filterEvents by type: ${Array.isArray(byType) ? byType.length : typeof byType} match(es)`)

        // Literal-text filtering searches SEMANTIC text, which the harness derives only
        // from event types it knows. A plugin-declared type contributes none, so its
        // payload is invisible to text search even though the event is in the log.
        const byText = await ctx.sessionQuery.filterEvents(session.id, [{ kind: 'text', text: marker }])
        console.log(`[l7-probe] filterEvents by text: ${Array.isArray(byText) ? byText.length : typeof byText} match(es) for an invented type's payload`)
      } catch (error) {
        console.log(`[l7-probe] filterEvents unavailable: ${error.message}`)
      }

      try {
        // The search request field is `query`; `text` is the *filter* field.
        const page = await ctx.sessionQuery.searchSessions({ query: marker })
        const hits = page?.results ?? page?.sessions ?? page
        console.log(`[l7-probe] searchSessions: ${Array.isArray(hits) ? hits.length : typeof hits} hit(s)`)
      } catch (error) {
        console.log(`[l7-probe] searchSessions failed: ${error.message}`)
      }

      const nameOf = schema => schema.name ?? schema.function?.name
      const agentNames = (handle.agent.ctx?.tools?.schemas?.() ?? []).map(nameOf).filter(Boolean)
      const found = config.expectedTools.filter(tool => agentNames.includes(tool))
      console.log(`[l7-probe] lesson tools in the AGENT scope: ${found.length}/${config.expectedTools.length}`)
      if (found.length !== config.expectedTools.length) {
        const globalNames = (ctx.tools?.schemas?.() ?? []).map(nameOf).filter(Boolean)
        const globalFound = config.expectedTools.filter(tool => globalNames.includes(tool))
        console.log(`[l7-probe] lesson tools in the GLOBAL scope instead: ${globalFound.length}`)
      }
    } catch (error) {
      console.log(`[l7-probe] FAILED: ${error.message}`)
      console.log(String(error.stack ?? '').split('\n').slice(1, 4).join('\n'))
    } finally {
      try { await handle?.dispose() } catch { /* already gone */ }
      console.log('[l7-probe] done')
    }
  }, config.delayMs)

  ctx.effect(() => () => clearTimeout(timer))
  console.log('[l7-probe] ACTIVE — will query session history')
}
