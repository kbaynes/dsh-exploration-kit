/**
 * Type-only declarations for the `l6/step` session event.
 *
 * Declaration merging is erased at runtime, so this file contributes nothing when
 * the plugin runs — but it is what makes `session.append('l6/step', ...)` and
 * `event.data.count` typecheck for consumers. Kept beside the producer, because a
 * session event's vocabulary belongs to whoever produces it.
 *
 * In a TypeScript project this is a `.ts` module imported for its types:
 *
 *     import './types.ts'
 *
 *     declare module '@deepseek-ai/dsh-session/types' {
 *       interface SessionEventMap {
 *         'l6/step': { label: string; count: number }
 *       }
 *     }
 *
 * A SessionEventMap entry must NOT carry an `@mode` tag: a log event has no
 * dispatch mode, and the persistence-catalog generator rejects one.
 */
export const name = 'l6-types'
