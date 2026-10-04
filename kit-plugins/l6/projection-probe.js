import Schema from '@deepseek-ai/schemastery'

export const name = 'l6-probe'
export const inject = ['agents', 'sessionProjections']

export const Config = Schema.object({
  /** Off by default: this creates a real session and appends real events. */
  enabled: Schema.boolean().default(false),
  delayMs: Schema.number().default(1500),
})

/**
 * Verifies Lesson 6's core claim — that a log-only event can be appended and that a
 * registered projection folds it — WITHOUT a model.
 *
 * `ctx.agents.create()` makes a session and runs no turn, so no provider is involved.
 * That is what makes the append path and the projection registry reachable offline.
 *
 * Three things are checked, and the third is the one that matters most:
 *   1. `session.append('l6/step', …)` is accepted for a log-only event.
 *   2. `stateOf(session, 'l6Steps')` reflects the folded value.
 *   3. The event carries the COMPLETE post-change state, so the fold is a replacement
 *      rather than an accumulation — visible by appending `{count: 5}` and seeing the
 *      total become 5, not 1 + 5.
 */
export function apply(ctx, config) {
  if (!config?.enabled) return

  const timer = setTimeout(async () => {
    let handle
    try {
      console.log('[l6-probe] creating a session (no turn, so no provider is involved)')
      // A unique id per run: sessions PERSIST, so a fixed id makes the second run fail
      // with "session ... already exists" — which is itself evidence the first run
      // created a durable session.
      const sessionId = `session-l6-probe-${Date.now()}`
      handle = await ctx.agents.create({
        sessionId,
        meta: { cwd: process.cwd() },
      })
      console.log(`[l6-probe] handle: ${handle ? Object.keys(handle).join(',') : String(handle)}`)
      console.log(`[l6-probe] agent present: ${Boolean(handle?.agent)}`)
      const session = handle?.agent?.session
      console.log(`[l6-probe] session present: ${Boolean(session)} (type ${typeof session})`)

      if (!session) {
        console.log('[l6-probe] no session on the handle; cannot read a projection')
        return
      }

      const read = () => JSON.stringify(ctx.sessionProjections.stateOf(session, 'l6Steps'))

      console.log(`[l6-probe] projection before any event: ${read()}`)
      if (read() === undefined) {
        console.log('[l6-probe] the l6Steps key is NOT registered — is the projection plugin loaded?')
        return
      }

      session.append('l6/step', { label: 'probe-1', count: 1 })
      console.log(`[l6-probe] after append count=1: ${read()}`)

      session.append('l6/step', { label: 'probe-2', count: 9 })
      console.log(`[l6-probe] after append count=9: ${read()}`)

      // Note: the fold is itself evidence the events COMMITTED — a projection only folds
      // committed events — so there is no need to reach for the raw log here.
    } catch (error) {
      console.log(`[l6-probe] FAILED: ${error.message}`)
      // The frame matters: "Invalid value used as weak map key" means an undefined was
      // used where a Session was expected, and only the stack says where from.
      const frames = String(error.stack ?? '').split('\n').slice(1, 6).join('\n')
      console.log(`[l6-probe] stack:\n${frames}`)
    } finally {
      try { await handle?.dispose() } catch { /* already gone */ }
      console.log('[l6-probe] done')
    }
  }, config.delayMs)

  ctx.effect(() => () => clearTimeout(timer))
  console.log('[l6-probe] ACTIVE — will create a session and append events')
}
