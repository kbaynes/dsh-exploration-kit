import Schema from '@deepseek-ai/schemastery'
import { createUserMessage } from '@deepseek-ai/dsh-llm'

export const name = 'l9-fire-probe'
export const inject = ['agents', 'schedule', 'sessionQuery']

export const Config = Schema.object({
  /** Off by default: this creates a task that fires. */
  enabled: Schema.boolean().default(false),
  /**
   * Provider route and model for the probe's own turn, and the route the delivery restores.
   * A programmatic `agents.create()` must state both (ADR-0028).
   */
  provider: Schema.string().default('deepseek-official'),
  model: Schema.string().default('deepseek-flash'),
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
        agentOptions: { provider: config.provider, model: config.model },
      })
      const session = handle.agent.session

      // Talk to the model ONCE before scheduling. This is not decoration: delivery to a session
      // that has never made a request resumes with no model at all, and the turn then dies on
      // `prompt variable "{{model}}" has no value`. A session with a logged request header
      // restores its provider/model on resume (api-session-controller's installSelection reads
      // the header back), which is the realistic shape of a scheduled follow-up anyway.
      handle.agent.followup(createUserMessage({
        content: [{ type: 'text', text: 'Warm the session up before scheduling.' }],
        source: { kind: 'user' },
      }))
      await handle.agent.whenIdle()
      const warmed = (await ctx.sessionQuery.readSession(session.id))?.events ?? []
      const warmupTurns = warmed.filter(event => event.type === 'turn/end').length
      console.log(`[l9-fire] warm-up turn produced ${warmed.filter(event => event.type === 'assistant/message').length} assistant message(s)`)
      console.log(`[l9-fire] the session logged a request header: ${warmed.some(event => event.type === 'request/header')}`)

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
          // The documented field is `records` (oldest-first retained deliveries); `lastDelivery`
          // is the most recent receipt on its own. The earlier guess-list here omitted `records`,
          // so a delivery that had actually happened still reported zero.
          const entries = history?.records
            ?? (history?.lastDelivery === undefined ? [] : [history.lastDelivery])
          deliveries = Array.isArray(entries) ? entries.length : 0
          if (deliveries > 0) {
            console.log(`[l9-fire] delivery receipt: ${JSON.stringify(entries[entries.length - 1])?.slice(0, 200)}`)
            break
          }
        } catch (error) {
          if (!shapeLogged) {
            console.log(`[l9-fire] history unavailable: ${error.message}`)
            shapeLogged = true
          }
        }
      }
      console.log(`[l9-fire] deliveries reported: ${deliveries}`)

      // Did a turn actually run? An assistant message in the log is the durable evidence.
      //
      // WAIT for the delivered turn to CLOSE first. The receipt is written when the reminder is
      // admitted, which is before the agent finishes the work, so reading the log at the moment
      // delivery is observed can catch the turn mid-flight - and then the "last turn/end" is the
      // warm-up's, so a turn that did complete reads as one that did not. Waiting on a turn count
      // that exceeds the warm-up baseline is what makes both assertions measure the delivery.
      let log = await ctx.sessionQuery.readSession(session.id)
      const endsOf = snapshot => (snapshot?.events ?? []).filter(event => event.type === 'turn/end').length
      const settleDeadline = Date.now() + config.waitMs
      while (endsOf(log) <= warmupTurns && Date.now() < settleDeadline) {
        await new Promise(resolve => setTimeout(resolve, 1000))
        log = await ctx.sessionQuery.readSession(session.id)
      }
      const types = (log?.events ?? []).map(event => event.type)
      const assistant = types.filter(type => type === 'assistant/message').length
      console.log(`[l9-fire] assistant messages in the session: ${assistant}`)
      // The LAST turn is the delivered one, so its reason is what says whether the scheduled work
      // completed or merely started.
      const lastEnd = [...(log?.events ?? [])].reverse().find(event => event.type === 'turn/end')
      console.log(`[l9-fire] the delivered turn ended: ${JSON.stringify(lastEnd?.data?.reason)?.slice(0, 160) ?? '(no turn/end)'}`)
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
