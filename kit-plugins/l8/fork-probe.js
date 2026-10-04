import Schema from '@deepseek-ai/schemastery'

export const name = 'l8-probe'
export const inject = ['agents', 'sessionProjections', 'sessionQuery']

export const Config = Schema.object({
  /** Off by default: this creates sessions. */
  enabled: Schema.boolean().default(false),
  delayMs: Schema.number().default(1500),
})

/**
 * Tests Lesson 8's fork-heredity claim without a model.
 *
 * The claim: a forked child is seeded with events from its parent, its header records the
 * lineage, and the exact inherited prefix is available as `inheritedEventCount` — which a
 * projection's `init(header, inheritedEventCount)` receives rather than inferring.
 *
 * The API is worth stating precisely because the lesson got it wrong once: `CreateAgentOptions`
 * takes `seed?: readonly SessionEvent[]` and `meta: { parentSession, isSeeded }`. There is NO
 * top-level `inheritedEventCount` — the cut is derived from the seed and read back from the
 * child's session.
 */
export function apply(ctx, config) {
  if (!config?.enabled) return

  const timer = setTimeout(async () => {
    let parent
    let child
    try {
      parent = await ctx.agents.create({
        sessionId: `session-l8-parent-${Date.now()}`,
        meta: { cwd: process.cwd() },
      })
      const parentSession = parent.agent.session
      console.log(`[l8-probe] parent ${parentSession.id}`)

      // Give the parent some content of its own.
      parentSession.append('sandbox/mode', { mode: 'read-only' })

      // The seed must be CONTIGUOUS FROM SEQ 0 — a prefix of a session's log, which is what
      // "completed-turn seed" means. Passing a lone later event fails with
      //   seed event at index 0 has seq 4 (expected 0); seed must be contiguous from 0
      // so the prefix is read from the log rather than assembled by hand.
      const log = await ctx.sessionQuery.readSession(parentSession.id)
      const prefix = log?.events ?? []
      console.log(`[l8-probe] parent log prefix: ${prefix.length} event(s), seqs ${prefix.map(e => e.seq).join(',')}`)

      child = await ctx.agents.create({
        sessionId: `session-l8-child-${Date.now()}`,
        seed: prefix,
        // Required whenever meta.isSeeded is set; without it creation fails with
        //   seeded session requires an inherited event count
        // The value is the exact inherited prefix length, which the child's header then
        // carries so a projection's init can read the cut instead of inferring it.
        inheritedEventCount: prefix.length,
        meta: { cwd: process.cwd(), parentSession: parentSession.id, isSeeded: true },
      })
      const childSession = child.agent.session
      console.log(`[l8-probe] child ${childSession.id}`)
      console.log(`[l8-probe] child inheritedEventCount: ${childSession.inheritedEventCount}`)
      console.log(`[l8-probe] child header isSeeded: ${childSession.header?.isSeeded}`)
      console.log(`[l8-probe] child parentSession: ${childSession.header?.parentSession}`)
      // The L6 projection folds `sandbox/mode`, so an inherited seed should already show:
      // that is heredity observed through derived state rather than through the header alone.
      console.log(`[l8-probe] child projection: ${JSON.stringify(ctx.sessionProjections.stateOf(childSession, 'l6Mode'))}`)
    } catch (error) {
      console.log(`[l8-probe] FAILED: ${error.message}`)
      console.log(String(error.stack ?? '').split('\n').slice(1, 4).join('\n'))
    } finally {
      try { await child?.dispose() } catch { /* already gone */ }
      try { await parent?.dispose() } catch { /* already gone */ }
      console.log('[l8-probe] done')
    }
  }, config.delayMs)

  ctx.effect(() => () => clearTimeout(timer))
  console.log('[l8-probe] ACTIVE — will create a parent and a seeded child')
}
