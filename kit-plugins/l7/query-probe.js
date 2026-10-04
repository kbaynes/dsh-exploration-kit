import Schema from '@deepseek-ai/schemastery'

export const name = 'l7-probe'
export const inject = ['agents', 'sessionQuery']

export const Config = Schema.object({
  /** Off by default: this creates a session and queries history. */
  enabled: Schema.boolean().default(false),
  /** 'query' probes the service; 'write' creates and appends; 'read' re-reads a fixed id. */
  mode: Schema.union(['query', 'write', 'read']).default('query'),
  /**
   * Append an INVENTED event type as well, to demonstrate the query layer's limits.
   *
   * Off by default because the append is contagious: a session carrying an event type the
   * harness does not know breaks full-text search for the WHOLE home (ADR-0024), so a probe that
   * did it on every run would poison the home it verifies in - which is exactly what happened
   * here before this flag existed, leaving 37 unreadable sessions behind.
   */
  appendInvented: Schema.boolean().default(false),
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
      // The session id carries the marker, so "is the marker in the log?" is answerable in both
      // modes - the invented branch appends it in an event payload, and the clean branch relies on
      // the id itself appearing in the header and events.
      const sessionId = useFixed
        ? config.sessionId
        : `session-l7-probe-${marker}`
      handle = await ctx.agents.create({ sessionId, meta: { cwd: process.cwd() } })
      const session = handle.agent.session

      // `appendInvented` chooses an event type the harness does NOT know, to demonstrate the query
      // layer's limits. The default appends a first-party log-only event, so a normal run leaves
      // the home readable.
      const appendedType = config.appendInvented ? 'l6/step' : 'sandbox/mode'
      session.append(appendedType, config.appendInvented
        ? { label: marker, count: 1 }
        : { mode: 'read-only' })
      console.log(`[l7-probe] created ${session.id}, appending '${appendedType}'`)

      const sessions = await ctx.sessionQuery.listSessions()
      const mine = sessions.find(record => JSON.stringify(record).includes(String(session.id)))
      console.log(`[l7-probe] listSessions: ${sessions.length} total; mine found: ${Boolean(mine)}`)

      const log = await ctx.sessionQuery.readSession(session.id)
      const events = log?.events ?? []
      const whole = JSON.stringify(log ?? {})
      console.log(`[l7-probe] readSession: ${events.length} event(s); marker present: ${whole.includes(session.id)}`)

      // Filters are ANDed clauses in an ARRAY, and each clause carries a `kind`. Filtering by the
      // type just appended is the positive case; filtering by an invented type is the caveat.
      // Each query is contained: one failing call must not skip the checks after it, which is how
      // a leftover poisoned session silently removed the tool-scope assertion from this probe.
      try {
        const byType = await ctx.sessionQuery.filterEvents(session.id, [{ kind: 'type', values: [appendedType] }])
        console.log(`[l7-probe] filterEvents by type '${appendedType}': ${(byType ?? []).length} match(es)`)
      } catch (error) {
        console.log(`[l7-probe] filterEvents by type threw: ${error.message}`)
      }

      try {
        const byText = await ctx.sessionQuery.filterEvents(session.id, [{ kind: 'text', text: session.id }])
        console.log(`[l7-probe] filterEvents by text: ${(byText ?? []).length} match(es)`)
      } catch (error) {
        console.log(`[l7-probe] filterEvents by text threw: ${error.message}`)
      }

      try {
        // The search request field is `query`; a page is `{ items, nextCursor? }`.
        const page = await ctx.sessionQuery.searchSessions({ query: session.id })
        console.log(`[l7-probe] searchSessions: ${(page?.items ?? []).length} hit(s)`)
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
