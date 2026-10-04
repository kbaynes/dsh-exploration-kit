export const name = 'l5-turn-observer'

export function apply(ctx) {
  ctx.on('agent/pre-step', async (payload, next) => {
    console.log('[l5-observer] pre-step', JSON.stringify(payload).slice(0, 160))
    return next()
  })

  ctx.on('agent/created', ({ agent }) => {
    console.log(`[l5-observer] agent created: ${agent.session.id ?? '(session)'}`)
  })

  console.log('[l5-observer] ACTIVE — watching agent/pre-step')
}
