export const name = 'l5-turn-observer'

export function apply(ctx) {
  ctx.on('agent/pre-step', async (payload, next) => {
    // Log FIELDS, never JSON.stringify(payload). The payload carries `agent`, which is a
    // Cordis scoped proxy: stringifying it reaches for `toJSON` on that proxy, and Cordis
    // answers "cannot get property \"toJSON\" without inject" — an error that aborts the
    // whole turn from inside this listener. See ADR-0028.
    console.log(`[l5-observer] pre-step turn=${payload.turn} step=${payload.step} messages=${payload.messages?.length ?? '?'}`)
    return next()
  })

  ctx.on('agent/created', ({ agent }) => {
    console.log(`[l5-observer] agent created: ${agent.session.id ?? '(session)'}`)
  })

  console.log('[l5-observer] ACTIVE — watching agent/pre-step')
}
