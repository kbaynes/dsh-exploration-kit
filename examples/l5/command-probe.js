import Schema from '@deepseek-ai/schemastery'

export const name = 'l5-cmd-probe'
export const inject = ['agents', 'commands', 'sessionQuery']

export const Config = Schema.object({
  /** Off by default: this creates a session and dispatches a command. */
  enabled: Schema.boolean().default(false),
  delayMs: Schema.number().default(1500),
})

/**
 * Tests Lesson 5's command claim without a model: that `/l5-facts` answers from plain code,
 * with no model turn.
 *
 * `ctx.commands.execute(agent, line, attachments, signal)` is the dispatch path the composer
 * uses. It needs an Agent — which `ctx.agents.create` provides without running a turn — so the
 * whole path is reachable offline.
 *
 * The second half is the interesting one: the command appends `command/run` and `command/done`
 * lifecycle events to the session and **no model request**, which is what "needs no model turn"
 * actually means in the log.
 */
export function apply(ctx, config) {
  if (!config?.enabled) return

  const timer = setTimeout(async () => {
    let handle
    try {
      handle = await ctx.agents.create({
        sessionId: `session-l5-cmd-${Date.now()}`,
        meta: { cwd: process.cwd() },
      })
      const session = handle.agent.session

      const controller = new AbortController()
      const executed = await ctx.commands.execute(handle.agent, '/l5-facts', [], controller.signal)
      console.log(`[l5-cmd] resolved: ${Boolean(executed)}`)
      const settled = executed?.result ?? executed
      console.log(`[l5-cmd] outcome: ${JSON.stringify(settled).slice(0, 240)}`)

      // The log is the evidence for "no model turn": command lifecycle events, no request.
      const log = await ctx.sessionQuery.readSession(session.id)
      const types = (log?.events ?? []).map(event => event.type)
      const commands = types.filter(type => type.startsWith('command/'))
      const requests = types.filter(type => type === 'request/header' || type === 'assistant/message')
      console.log(`[l5-cmd] command events in the log: ${commands.join(', ') || '(none)'}`)
      console.log(`[l5-cmd] model-request events in the log: ${requests.length}`)
    } catch (error) {
      console.log(`[l5-cmd] FAILED: ${error.message}`)
      console.log(String(error.stack ?? '').split('\n').slice(1, 4).join('\n'))
    } finally {
      try { await handle?.dispose() } catch { /* already gone */ }
      console.log('[l5-cmd] done')
    }
  }, config.delayMs)

  ctx.effect(() => () => clearTimeout(timer))
  console.log('[l5-cmd] ACTIVE — will dispatch /l5-facts')
}
