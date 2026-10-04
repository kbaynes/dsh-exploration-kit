import Schema from '@deepseek-ai/schemastery'
import { createUserMessage } from '@deepseek-ai/dsh-llm'

export const name = 'l7-turn-probe'
export const inject = ['agents', 'sessionProjections', 'sessionQuery', 'commands']

export const Config = Schema.object({
  /** Off by default: this creates a session and runs a real turn. */
  enabled: Schema.boolean().default(false),
  delayMs: Schema.number().default(1500),
})

/**
 * Exercises Lesson 7's observability claims against a REAL turn, with no provider key.
 *
 * The turn runs against the repository's scriptable mock endpoint (ADR-0027), so the loop,
 * the log, and the accounting are real while the model's output is scripted. That is enough
 * for every claim here, which are about what the harness records rather than about what a
 * model decided:
 *
 *   - token accounting exists and is non-zero (`tokenUsage` is a projection, so it is read
 *     the same way Lesson 6 reads its own unit)
 *   - session statistics count the turn and its steps
 *   - the trajectory is searchable by the assistant's own text
 *   - `/compact` settles as a command, and its outcome is reported
 */
export function apply(ctx, config) {
  if (!config?.enabled) return

  const timer = setTimeout(async () => {
    let handle
    try {
      handle = await ctx.agents.create({
        sessionId: `session-l7-turn-${Date.now()}`,
        meta: { cwd: process.cwd() },
      })
      const agent = handle.agent
      const session = agent.session

      // A real turn: the mock provider answers with its scripted text.
      agent.followup(createUserMessage({
        content: [{ type: 'text', text: 'say hi' }],
        source: { kind: 'user' },
      }))
      await agent.whenIdle()

      // The projection exists and carries the documented shape. Its numbers are zero here for a
      // reason worth stating: the mock reports no usage for scripted text, so accounting has
      // nothing to record. The SHAPE is what this asserts; a real provider fills the numbers.
      const usage = ctx.sessionProjections.stateOf(session, 'tokenUsage')
      console.log(`[l7-turn] tokenUsage: ${JSON.stringify(usage)}`)
      // `sessionStats` is mounted by the WEB bundle, not the base one, so it is absent here -
      // which is why Lesson 7's statistics step tells the reader to use a web-backed profile.
      const stats = ctx.sessionProjections.stateOf(session, 'sessionStats')
      console.log(`[l7-turn] sessionStats (web-only): ${stats === undefined ? 'not mounted in this profile' : JSON.stringify(stats).slice(0, 160)}`)

      // The trajectory is searchable by text the ASSISTANT produced, which is the substance
      // behind Lesson 7's session_search.
      try {
        // A search page is `{ items, nextCursor? }` — not `results`/`sessions`, which my first
        // version guessed and then reported as "object hit(s)".
        const page = await ctx.sessionQuery.searchSessions({ query: 'mock response' })
        const items = page?.items ?? []
        console.log(`[l7-turn] searchSessions('mock response'): ${items.length} hit(s)`)
      } catch (error) {
        console.log(`[l7-turn] searchSessions failed: ${error.message}`)
      }

      // /compact is a command, so it is dispatched without a model turn of its own.
      try {
        const controller = new AbortController()
        const compacted = await ctx.commands.execute(agent, '/compact', [], controller.signal)
        console.log(`[l7-turn] /compact outcome: ${JSON.stringify(compacted?.result ?? compacted)?.slice(0, 200)}`)
      } catch (error) {
        console.log(`[l7-turn] /compact threw: ${error.message}`)
      }
    } catch (error) {
      console.log(`[l7-turn] FAILED: ${error.message}`)
      console.log(String(error.stack ?? '').split('\n').slice(1, 4).join('\n'))
    } finally {
      try { await handle?.dispose() } catch { /* already gone */ }
      console.log('[l7-turn] done')
    }
  }, config.delayMs)

  ctx.effect(() => () => clearTimeout(timer))
  console.log('[l7-turn] ACTIVE — will run a real turn and inspect what was recorded')
}
