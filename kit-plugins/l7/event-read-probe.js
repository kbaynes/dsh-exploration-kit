import Schema from '@deepseek-ai/schemastery'
import { createUserMessage } from '@deepseek-ai/dsh-llm'

export const name = 'l7-event-read-probe'
export const inject = ['agents', 'sessionQuery']

export const Config = Schema.object({
  /** Off by default: this creates a session and runs a real turn. */
  enabled: Schema.boolean().default(false),
  /** Provider route and model for the probe's turn (ADR-0028). */
  provider: Schema.string().default('deepseek-official'),
  model: Schema.string().default('deepseek-flash'),
  delayMs: Schema.number().default(1500),
})

/**
 * Tests Lesson 7's `session_event_read` claim: the tool returns one event as **JSON**, with
 * neighbouring raw events summarised around it.
 *
 * The claim is about tool OUTPUT, so it needs the tool to run. The mock provider supplies the
 * call (`tool_call_success`) while the harness executes the tool for real (ADR-0027), and because
 * `session_id` is optional, the call targets the caller's own session — so no id has to be known
 * before the harness boots.
 *
 * The probe prints the tool's result **in full**: an earlier check truncated results to 700
 * characters, which hid the neighbour lists this claim is about.
 */
export function apply(ctx, config) {
  if (!config?.enabled) return

  const timer = setTimeout(async () => {
    let handle
    try {
      handle = await ctx.agents.create({
        sessionId: `session-l7-event-read-${Date.now()}`,
        meta: { cwd: process.cwd() },
        agentOptions: { provider: config.provider, model: config.model },
      })
      const session = handle.agent.session

      // The mock answers this request with a `session_event_read` call for seq 1 — the second
      // event every session has (`permission/preset` is seq 0) — asking for two neighbours each
      // way.
      handle.agent.followup(createUserMessage({
        content: [{ type: 'text', text: 'Read event 1 with its neighbours.' }],
        source: { kind: 'user' },
      }))
      await handle.agent.whenIdle()

      const log = await ctx.sessionQuery.readSession(session.id)
      const events = log?.events ?? []
      const results = events.filter(event => event.type === 'tool/result')
      console.log(`[l7-event] tool/result events: ${results.length}`)
      for (const [index, event] of results.entries()) {
        const data = event.data ?? {}
        const text = (data.message?.content ?? [])
          .map(block => block?.text ?? '')
          .join('')
        // FULL output on one line per event, so a check can assert on the neighbour lists.
        console.log(`[l7-event] result ${index} isError=${data.message?.isError === true}: ${text.replace(/\n/g, ' | ')}`)
      }
      const types = events.map(event => event.type)
      console.log(`[l7-event] assistant messages: ${types.filter(type => type === 'assistant/message').length}`)
      const lastEnd = [...events].reverse().find(event => event.type === 'turn/end')
      console.log(`[l7-event] the turn ended: ${JSON.stringify(lastEnd?.data?.reason)?.slice(0, 160) ?? '(no turn/end)'}`)
    } catch (error) {
      console.log(`[l7-event] FAILED: ${error.message}`)
      console.log(String(error.stack ?? '').split('\n').slice(1, 4).join('\n'))
    } finally {
      try { await handle?.dispose() } catch { /* already gone */ }
      console.log('[l7-event] done')
    }
  }, config.delayMs)

  ctx.effect(() => () => clearTimeout(timer))
  console.log('[l7-event] ACTIVE — will read one event with its neighbours through the real tool')
}
