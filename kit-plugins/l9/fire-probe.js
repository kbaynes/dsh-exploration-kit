import Schema from '@deepseek-ai/schemastery'

export const name = 'l9-fire-probe'
export const inject = ['agents', 'schedule', 'sessionQuery']

export const Config = Schema.object({
  /** Off by default: this creates a task that fires. */
  enabled: Schema.boolean().default(false),
  /** Seconds until the task is due. */
  afterSeconds: Schema.number().default(2),
  /** How long to wait for it to fire, in milliseconds. */
  waitMs: Schema.number().default(25000),
})

/**
 * Tests Lesson 9's DELIVERY claim: a due task resumes the session and the agent works on it.
 *
 * Storage was already verified in two processes; delivery is the half that needs a provider, and
 * the mock provider supplies one (ADR-0027). So this schedules a task a couple of seconds out,
 * waits, and then asks what happened:
 *
 *   - does the schedule report a delivery?
 *   - did a turn actually run in the session (an assistant message in the log)?
 */
export function apply(ctx, config) {
  if (!config?.enabled) return

  const timer = setTimeout(async () => {
    let handle
    try {
      handle = await ctx.agents.create({
        sessionId: `session-l9-fire-${Date.now()}`,
        meta: { cwd: process.cwd() },
      })
      const session = handle.agent.session

      const record = await ctx.schedule.create(session.id, {
        title: 'l9 fire probe',
        prompt: 'The scheduled task fired; report that you ran.',
        after_seconds: config.afterSeconds,
      })
      console.log(`[l9-fire] scheduled ${record.id} to fire in ${config.afterSeconds}s`)
      console.log(`[l9-fire] waiting up to ${config.waitMs}ms for delivery`)

      const deadline = Date.now() + config.waitMs
      let deliveries = 0
      let shapeLogged = false
      while (Date.now() < deadline) {
        await new Promise(resolve => setTimeout(resolve, 2000))
        try {
          // Per-TASK, and `limit` is required ("a safe integer from 1 through 100").
          const history = await ctx.schedule.history({ sessionId: session.id, id: record.id, limit: 10 })
          if (!shapeLogged) {
            console.log(`[l9-fire] history shape: ${JSON.stringify(history)?.slice(0, 200)}`)
            shapeLogged = true
          }
          const entries = history?.receipts ?? history?.entries ?? history?.deliveries ?? history?.items ?? []
          deliveries = Array.isArray(entries) ? entries.length : (history?.latest ? 1 : 0)
          if (deliveries > 0) break
        } catch (error) {
          if (!shapeLogged) {
            console.log(`[l9-fire] history unavailable: ${error.message}`)
            shapeLogged = true
          }
        }
      }
      console.log(`[l9-fire] deliveries reported: ${deliveries}`)

      // Did a turn actually run? An assistant message in the log is the durable evidence.
      const log = await ctx.sessionQuery.readSession(session.id)
      const types = (log?.events ?? []).map(event => event.type)
      const assistant = types.filter(type => type === 'assistant/message').length
      console.log(`[l9-fire] assistant messages in the session: ${assistant}`)
      console.log(`[l9-fire] event types: ${types.join(',')}`)
    } catch (error) {
      console.log(`[l9-fire] FAILED: ${error.message}`)
      console.log(String(error.stack ?? '').split('\n').slice(1, 4).join('\n'))
    } finally {
      try { await handle?.dispose() } catch { /* already gone */ }
      console.log('[l9-fire] done')
    }
  }, 1500)

  ctx.effect(() => () => clearTimeout(timer))
  console.log('[l9-fire] ACTIVE — will schedule a task and wait for it to fire')
}
