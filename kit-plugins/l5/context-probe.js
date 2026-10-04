import Schema from '@deepseek-ai/schemastery'

export const name = 'l5-probe'
export const inject = ['agents', 'sessionQuery']

export const Config = Schema.object({
  /** Off by default: this creates a session and reads a log. */
  enabled: Schema.boolean().default(false),
  /** 'write' creates a named session; 'read' checks what a later process can see in it. */
  mode: Schema.union(['write', 'read']).default('write'),
  /** The fixed session id both modes use. */
  sessionId: Schema.string().default('session-l5-context'),
  /** The sentence Lesson 5's inject plugin appends. */
  expectText: Schema.string().default(
    'Exploration mode: when you explain a change, name the file it lands in.',
  ),
  delayMs: Schema.number().default(1500),
})

/**
 * Tests Lesson 5's durability claim: the context `agent.inject()` appends is present when
 * the session is replayed in a LATER process.
 *
 * That claim is what makes injection durable rather than a transient nudge, and it cannot
 * be checked in one process: `agent/created` fires while the session is being built, so an
 * in-process assertion would measure the queue rather than the log. Two processes, like
 * Lesson 6's restart test.
 */
export function apply(ctx, config) {
  if (!config?.enabled) return

  const timer = setTimeout(async () => {
    let handle
    try {
      if (config.mode === 'read') {
        const reopened = await ctx.sessionQuery.readSession(config.sessionId)
        const events = reopened?.events ?? []
        const types = events.map(event => event.type)
        console.log(`[l5-probe] re-read ${events.length} event(s): ${types.join(', ') || '(none)'}`)

        // Report WHICH event carries the text, not merely that it is somewhere in the log.
        // `agent.inject()` queues into the agent's inbox, so the durable carrier is an
        // inbox event rather than a `user/message` — worth stating rather than assuming.
        const carriers = events
          .filter(event => JSON.stringify(event).includes(config.expectText))
          .map(event => event.type)
        console.log(`[l5-probe] injected text present after restart: ${carriers.length > 0}`)
        console.log(`[l5-probe] carried by: ${carriers.join(', ') || '(nothing)'}`)
        return
      }

      handle = await ctx.agents.create({
        sessionId: config.sessionId,
        meta: { cwd: process.cwd() },
      })
      console.log(`[l5-probe] created ${handle.agent.session.id}`)
      // Give the agent/created listeners a moment; they are awaited before creation
      // resolves, so this is belt-and-braces rather than a race.
      await new Promise(resolve => setTimeout(resolve, 300))
      console.log('[l5-probe] an in-process check would measure the queue, not the log;')
      console.log('[l5-probe] re-run with mode=read to test what actually persisted')
    } catch (error) {
      console.log(`[l5-probe] FAILED: ${error.message}`)
      console.log(String(error.stack ?? '').split('\n').slice(1, 4).join('\n'))
    } finally {
      try { await handle?.dispose() } catch { /* already gone */ }
      console.log('[l5-probe] done')
    }
  }, config.delayMs)

  ctx.effect(() => () => clearTimeout(timer))
  console.log('[l5-probe] ACTIVE — will create or inspect a session')
}
