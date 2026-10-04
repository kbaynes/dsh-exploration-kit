import Schema from '@deepseek-ai/schemastery'

export const name = 'l6-probe'
export const inject = ['agents', 'sessionProjections', 'permissionPresets']

export const Config = Schema.object({
  /** Off by default: this creates a session and changes its permission preset. */
  enabled: Schema.boolean().default(false),
  /** 'write' creates a session and switches its preset; 'resume' reopens it later. */
  mode: Schema.union(['write', 'resume']).default('write'),
  /** The fixed session id both modes use, so a restart can find it. */
  sessionId: Schema.string().default('session-l6-durability'),
  delayMs: Schema.number().default(1500),
})

/**
 * Verifies Lesson 6's durability claim ACROSS A RESTART, using a session event type the
 * harness already knows. No model is involved: changing a permission preset is a service
 * call, not a model call.
 *
 * `mode: write`  creates a named session — which already appends a `sandbox/mode` event at
 *                creation — then switches the preset and reads the projection.
 * `mode: resume` runs in a LATER process, reopens that session with `ctx.agents.resume`,
 *                and reads the same projection key. The value it reports is reconstructed
 *                from the persisted log, which is the claim under test.
 */
export function apply(ctx, config) {
  if (!config?.enabled) return

  const timer = setTimeout(async () => {
    let handle
    try {
      const read = session => JSON.stringify(ctx.sessionProjections.stateOf(session, 'l6Mode'))

      if (config.mode === 'resume') {
        console.log(`[l6-probe] resuming ${config.sessionId} in a fresh process`)
        handle = await ctx.agents.resume({ resumeSessionId: config.sessionId })
        const session = handle.agent.session
        // Reconstructed from disk: the projection folds the persisted log on load.
        console.log(`[l6-probe] RESUMED mode: ${read(session)}`)
        return
      }

      handle = await ctx.agents.create({
        sessionId: config.sessionId,
        meta: { cwd: process.cwd() },
      })
      const session = handle.agent.session
      console.log(`[l6-probe] created ${session.id}`)
      console.log(`[l6-probe] mode at creation: ${read(session)}`)

      // Switch a permission preset: a real service call, the same one the `/permission`
      // control makes. It appends a known log-only `sandbox/mode` event.
      const presets = ctx.permissionPresets
      if (!presets) {
        console.log('[l6-probe] permissionPresets not mounted; cannot switch the preset')
        return
      }
      presets.set(session, 'danger-full-access')
      console.log(`[l6-probe] mode after switching the preset: ${read(session)}`)
      console.log('[l6-probe] now STOP this process and re-run with mode=resume')
    } catch (error) {
      console.log(`[l6-probe] FAILED: ${error.message}`)
      console.log(String(error.stack ?? '').split('\n').slice(1, 4).join('\n'))
    } finally {
      try { await handle?.dispose() } catch { /* already gone */ }
      console.log('[l6-probe] done')
    }
  }, config.delayMs)

  ctx.effect(() => () => clearTimeout(timer))
  console.log('[l6-probe] ACTIVE — will create or resume a session')
}
