/**
 * A DELIBERATE HAZARD, kept so Lesson 6 can demonstrate it. Do not copy this pattern.
 *
 * This plugin invents a session event type. That appears to work: the merge typechecks,
 * `session.append` accepts it, and a projection folds it in the same process. After a
 * RESTART the session cannot be opened at all:
 *
 *   failed to read stored session "…": session "…" contains event type "l6/step" (seq 4)
 *   unknown to this harness and not marked ignorable; refusing to interpret the log
 *
 * `validateStoredEvents` only tolerates a stored event outside the harness vocabulary when
 * its envelope carries `ignorable: true`; the persistence catalog states that external
 * plugin types are outside its inventory; `KNOWN_SESSION_EVENT_TYPES` is a static generated
 * set with no runtime registration; and `session.append()` cannot set `ignorable`.
 *
 * It is also contagious: full-text search observes whole sessions, so one session carrying
 * this type breaks `searchSessions` for the corpus.
 *
 * Therefore: DISABLED by default, and enabled only by the hazard overlay
 * (`solutions/l6.hazard.patch.yml`). Type-checking is not availability.
 */
export const name = 'l6-hazard'
export const inject = ['agents']

/** Per-session running count, kept in memory and mirrored into the log. */
const counts = new WeakMap()

export function apply(ctx) {
  // The payload is an OBJECT ({ agent, source, signal }), not the agent itself.
  // Treating it as the agent gives `payload.session === undefined`, which fails with
  // "Invalid value used as weak map key" the first time a real session is created.
  ctx.on('agent/created', ({ agent }) => {
    counts.set(agent.session, 0)
    console.log('[l6-hazard] tracking a new session (its log will be unreadable after restart)')
  })

  ctx.on('session/event', (session, event) => {
    if (event.type !== 'tool/result') return
    const next = (counts.get(session) ?? 0) + 1
    counts.set(session, next)
    // THE HAZARD: a plugin-declared event type, written into a durable log.
    session.append('l6/step', { label: 'tool-result', count: next })
  })

  console.log('[l6-hazard] ACTIVE — appending a plugin-declared event type')
}
