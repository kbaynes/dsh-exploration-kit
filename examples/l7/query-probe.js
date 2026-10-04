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
  /**
   * How long to wait before accepting that the filters find nothing.
   *
   * The wait was added to test a hypothesis - that a session created in this process is live but
   * not yet in the store's index, so an immediate query finds nothing. It is NOT that: 30 seconds
   * changes nothing, a session that existed before boot reports 0 for `user/message` too, and a
   * fresh home holding a single session behaves the same. Five seconds is enough to show it.
   */
  filterWaitMs: Schema.number().default(5000),
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
      // Why these filters legitimately find nothing here, and the rule worth knowing.
      //
      // The query layer builds a searchable document ONLY for events that carry semantic text
      // (`extractSessionEventText`): user and assistant messages, tool calls and results, todo
      // writes, and turns that ended with a reason. Everything else contributes an empty string
      // and `buildSessionEventSearchDocuments` OMITS it ("structural events are omitted"). So a
      // log-only structural event such as `sandbox/mode` produces NO document, and neither a type
      // filter nor a text filter nor full-text search can ever find it - by design, not by fault.
      //
      // This session has no messages at all, so every filter below is legitimately empty. The
      // POSITIVE case (a filter finding semantic text) belongs to a session that has some, and the
      // turn phase asserts exactly that with `searchSessions(<marker>): 1 hit(s)`.
      //
      // The wait is kept, short, because it is what rules out the flush hypothesis.
      const countByType = async (type) => {
        try {
          const found = await ctx.sessionQuery.filterEvents(session.id, [{ kind: 'type', values: [type] }])
          return (found ?? []).length
        } catch (error) {
          console.log(`[l7-probe] filterEvents by type threw: ${error.message}`)
          return 0
        }
      }
      const filterStarted = Date.now()
      let typeMatches = await countByType(appendedType)
      const filterDeadline = filterStarted + config.filterWaitMs
      while (typeMatches === 0 && Date.now() < filterDeadline) {
        await new Promise(resolve => setTimeout(resolve, 1000))
        typeMatches = await countByType(appendedType)
      }
      console.log(`[l7-probe] filterEvents by type '${appendedType}': ${typeMatches} match(es) after ${Date.now() - filterStarted}ms`)

      try {
        const byText = await ctx.sessionQuery.filterEvents(session.id, [{ kind: 'text', text: session.id }])
        console.log(`[l7-probe] filterEvents by text: ${(byText ?? []).length} match(es)`)
      } catch (error) {
        console.log(`[l7-probe] filterEvents by text threw: ${error.message}`)
      }

      // DIAGNOSTIC: does the filter see SURFACE events at all? Every session has `user/message`
      // events, so a zero here means the filter is broken rather than selective.
      // The rule, measured on this session: how many of its events can the query layer index?
      const semanticTypes = new Set(['user/message', 'assistant/message', 'tool/call', 'tool/result', 'todo/write', 'turn/end'])
      const indexable = events.filter(event => semanticTypes.has(event.type)).length
      console.log(`[l7-probe] events the query layer can index (semantic-bearing): ${indexable} of ${events.length}`)
      // What the log records for the event just appended: its type, and whether the harness treats
      // it as a surface event (`surfaceOp`) or a log-only one.
      const appended = events.filter(event => event.type === appendedType)
      console.log(`[l7-probe] appended '${appendedType}' is in the log: ${appended.length > 0}; surfaceOp: ${JSON.stringify(appended.map(event => event.surfaceOp ?? null))}`)

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
