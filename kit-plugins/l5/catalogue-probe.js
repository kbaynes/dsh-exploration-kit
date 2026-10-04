import Schema from '@deepseek-ai/schemastery'
import { createUserMessage } from '@deepseek-ai/dsh-llm'

export const name = 'l5-catalogue-probe'
export const inject = ['agents', 'sessionQuery']

export const Config = Schema.object({
  /** Off by default: this runs a real turn. */
  enabled: Schema.boolean().default(false),
  /** The skill the catalogue should mention. */
  expectSkill: Schema.string().default('repo-onboarding'),
  delayMs: Schema.number().default(1500),
})

/**
 * Tests Lesson 5's last claim: that a model-invocable skill is announced to the model as a
 * durable CATALOGUE before the first request, while the body loads only on demand.
 *
 * The catalogue is a durable user message, so it lands in the session log — which makes it
 * checkable without reading the model's mind. A real turn against the repository's scriptable
 * mock provider (ADR-0027) produces the log; the assertion is about what the harness recorded.
 */
export function apply(ctx, config) {
  if (!config?.enabled) return

  const timer = setTimeout(async () => {
    let handle
    try {
      handle = await ctx.agents.create({
        sessionId: `session-l5-catalogue-${Date.now()}`,
        meta: { cwd: process.cwd() },
      })
      const agent = handle.agent
      agent.followup(createUserMessage({
        content: [{ type: 'text', text: 'say hi' }],
        source: { kind: 'user' },
      }))
      await agent.whenIdle()

      const log = await ctx.sessionQuery.readSession(agent.session.id)
      const events = log?.events ?? []
      const types = events.map(event => event.type)
      const whole = JSON.stringify(events)

      console.log(`[l5-cat] event types: ${types.join(',')}`)
      console.log(`[l5-cat] catalogue mentions '${config.expectSkill}': ${whole.includes(config.expectSkill)}`)

      // Distinguish the CATALOGUE from the BODY: the catalogue is a short pinned summary, the body
      // is the full instructions. Searching for a phrase that only the body carries answers which
      // one arrived.
      const bodyOnlyPhrase = 'The DSH Exploration Kit is a nine-lesson curriculum'
      console.log(`[l5-cat] body loaded into the log: ${whole.includes(bodyOnlyPhrase)}`)
    } catch (error) {
      console.log(`[l5-cat] FAILED: ${error.message}`)
      console.log(String(error.stack ?? '').split('\n').slice(1, 4).join('\n'))
    } finally {
      try { await handle?.dispose() } catch { /* already gone */ }
      console.log('[l5-cat] done')
    }
  }, config.delayMs)

  ctx.effect(() => () => clearTimeout(timer))
  console.log('[l5-cat] ACTIVE — will run a turn and inspect the catalogue')
}
