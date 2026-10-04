export const name = 'l6-counter'
export const inject = ['agents']

/** Per-session running count, kept in memory and mirrored into the log. */
const counts = new WeakMap()

export function apply(ctx) {
  // The payload is an OBJECT ({ agent, source, signal }), not the agent itself.
  // Treating it as the agent gives `payload.session === undefined`, which fails with
  // "Invalid value used as weak map key" the first time a real session is created.
  ctx.on('agent/created', ({ agent }) => {
    counts.set(agent.session, 0)
    console.log('[l6-counter] tracking a new session')
  })

  // `session/event` sees every committed event. A log-only event never reaches the
  // model, but every registered observer sees it.
  ctx.on('session/event', (session, event) => {
    if (event.type !== 'tool/result') return
    const next = (counts.get(session) ?? 0) + 1
    counts.set(session, next)
    // The event carries the COMPLETE post-change state, never a bare delta:
    // replay has no reliable "previous" to accumulate against.
    session.append('l6/step', { label: 'tool-result', count: next })
  })

  console.log('[l6-counter] ACTIVE — appends l6/step on each tool result')
}
