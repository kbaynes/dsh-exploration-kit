import Schema from '@deepseek-ai/schemastery'
import { createUserMessage } from '@deepseek-ai/dsh-llm'

export const name = 'l5-catalogue-probe'
export const inject = ['agents', 'sessionQuery', 'skills', 'tools']

export const Config = Schema.object({
  /** Off by default: this runs a real turn. */
  enabled: Schema.boolean().default(false),
  /** The skill the catalogue should mention. */
  expectSkill: Schema.string().default('repo-onboarding'),
  /**
   * The provider route and model for the probe's turn. `agents.create()` requires both
   * explicitly: a saved model selection in settings supplies them for UI-created agents, but a
   * programmatic create that omits them fails at the first step with "has no provider/model"
   * (see ADR-0028). Point these at the mock provider with DEEPSEEK_BASE_URL/DEEPSEEK_API_KEY.
   */
  provider: Schema.string().default('deepseek-official'),
  model: Schema.string().default('deepseek-flash'),
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
        agentOptions: { provider: config.provider, model: config.model },
      })
      const agent = handle.agent

      // Wait for a COMPLETE catalog BEFORE driving the turn.
      //
      // The catalogue is skipped outright while discovery is incomplete
      // (`if (!snapshot.complete) return decision` in tool-skill), and discovery is incomplete
      // while a watched root is still settling. The listener asks with `scope: agent`, which is a
      // SEPARATE observation from the unscoped ask: waiting on only the unscoped one still raced
      // the watcher, and the same probe passed and failed on consecutive runs depending only on
      // that timing. Waiting on both, before the first request, removes the race from the
      // verification without changing the product.
      const observeRegistry = async () => ({
        plain: await ctx.skills.snapshot({ cwd: process.cwd() }),
        scoped: await ctx.skills.snapshot({ cwd: process.cwd(), scope: agent }),
      })
      let { plain, scoped } = await observeRegistry()
      const settleDeadline = Date.now() + 20000
      while ((!plain.complete || !scoped.complete) && Date.now() < settleDeadline) {
        await new Promise(resolve => setTimeout(resolve, 500))
        ;({ plain, scoped } = await observeRegistry())
      }
      console.log(`[l5-cat] registry: ${plain.skills.length} skill(s), complete=${plain.complete}, agent-scoped complete=${scoped.complete}: ${plain.skills.map(skill => skill.name).join(',') || '(none)'}`)
      console.log(`[l5-cat] the skill tool is visible to the agent: ${ctx.tools.get('skill', agent) !== undefined}`)

      // A real turn: the mock provider answers with its scripted text.
      agent.followup(createUserMessage({
        content: [{ type: 'text', text: 'say hi' }],
        source: { kind: 'user' },
      }))
      await agent.whenIdle()

      const log = await ctx.sessionQuery.readSession(agent.session.id)
      const events = log?.events ?? []
      const types = events.map(event => event.type)
      const whole = JSON.stringify(events)

      // Read the catalogue from the message that CARRIES it (`source.kind === 'skill-catalog'`)
      // rather than searching the whole log. A plain substring search is satisfied by any text
      // that happens to name the skill - including the model's own tool-call arguments, which is
      // exactly how the companion probe reported a catalogue that was not there.
      const catalogues = events.filter(event =>
        event.type === 'user/message' && event.data?.source?.kind === 'skill-catalog')
      const catalogueText = JSON.stringify(catalogues)

      console.log(`[l5-cat] event types: ${types.join(',')}`)
      console.log(`[l5-cat] skill-catalog messages: ${catalogues.length}`)
      console.log(`[l5-cat] catalogue mentions '${config.expectSkill}': ${catalogueText.includes(config.expectSkill)}`)

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
