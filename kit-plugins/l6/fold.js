import { z } from 'zod'

/**
 * The projection's pure core, extracted so it can be tested without a session.
 *
 * Two contracts are easy to get wrong and hard to notice:
 *
 *  1. `apply` must return the SAME state reference for events that do not concern
 *     this unit. The registry gates downstream work on `Object.is`, so returning a
 *     fresh equal object makes every unrelated event cost a full recompute.
 *  2. `l6/step` carries the complete post-change state (`count`), not a delta. Replay
 *     has no reliable "previous" to accumulate against.
 */
export const stateSchema = z.object({ total: z.number() })

export const projection = {
  key: 'l6Steps',
  stateSchema,
  stateVersion: 1,
  init: () => ({ total: 0 }),
  apply: (state, event) =>
    event.type === 'l6/step' ? { total: event.data.count } : state,
  wire: {
    viewSchema: stateSchema,
    view: state => ({ total: state.total }),
  },
}

/** Fold a sequence of events, exactly as the registry would. */
export function foldEvents(events) {
  return events.reduce((state, event) => projection.apply(state, event), projection.init())
}
