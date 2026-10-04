import { z } from 'zod'

/**
 * The projection's pure core — deriving the session's permission mode from its LOG.
 *
 * This is the durable pattern, and the event type is the reason. A plugin-declared event
 * type (see `hazard-custom-event.js`) is writable and foldable, and it makes the session
 * UNREADABLE after a restart: the storage contract refuses to interpret a log containing a
 * type outside the harness vocabulary. Folding a KNOWN type keeps the log readable, and a
 * readable log is what makes derived state durable.
 *
 * The harness does exactly this itself: `@deepseek-ai/dsh-sandbox-policy` keeps a
 * `sandboxMode` projection unit folding this same log-only event, so the model is told the
 * session's policy from the log rather than from out-of-band state.
 *
 * Two contracts, both easy to get wrong:
 *
 *  1. `apply` must return the SAME state reference for events that do not concern this
 *     unit. The registry gates downstream work on `Object.is`, so a fresh equal object
 *     makes every unrelated event cost a full recompute.
 *  2. `sandbox/mode` carries the complete post-change state — the mode *is* the value —
 *     so this fold replaces rather than accumulates.
 */
export const stateSchema = z.object({ mode: z.string() })

/** The event type this unit folds. First-party, therefore known to the harness. */
export const FOLDED_EVENT = 'sandbox/mode'

export const projection = {
  key: 'l6Mode',
  stateSchema,
  stateVersion: 1,
  init: () => ({ mode: 'unknown' }),
  apply: (state, event) =>
    event.type === FOLDED_EVENT ? { mode: event.data.mode } : state,
  wire: {
    viewSchema: stateSchema,
    view: state => ({ mode: state.mode }),
  },
}

/** Fold a sequence of events, exactly as the registry would. */
export function foldEvents(events) {
  return events.reduce((state, event) => projection.apply(state, event), projection.init())
}
