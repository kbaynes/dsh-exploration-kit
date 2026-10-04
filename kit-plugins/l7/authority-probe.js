import Schema from '@deepseek-ai/schemastery'
import { mkdirSync } from 'node:fs'
import { tmpdir } from 'node:os'
import { join } from 'node:path'
import { createUserMessage } from '@deepseek-ai/dsh-llm'

export const name = 'l7-authority-probe'
export const inject = ['agents', 'sessionQuery']

export const Config = Schema.object({
  /** Off by default: this creates sessions and runs a real turn. */
  enabled: Schema.boolean().default(false),
  /**
   * The id of a session that lives in a DIFFERENT workspace. The mock provider is scripted to
   * call `session_trace` with exactly this id, so it must match the `--tool-arguments` the
   * verification script passes to the mock. That is the only way to script a cross-workspace
   * call: the arguments are fixed when the mock starts, before this session exists.
   */
  foreignSessionId: Schema.string().default('session-l7-foreign-workspace'),
  /** Workspace for the foreign session; must differ from the caller's. */
  foreignCwd: Schema.string().default(join(tmpdir(), 'dsh-l7-foreign-workspace')),
  /** Provider route and model for the probe's own turn (ADR-0028). */
  provider: Schema.string().default('deepseek-official'),
  model: Schema.string().default('deepseek-flash'),
  delayMs: Schema.number().default(1500),
})

/**
 * Tests Lesson 7's workspace-authority claim with a REAL model-driven tool call: a session may
 * only read sessions in its own workspace, and a target that is out of workspace must be
 * indistinguishable from one that does not exist.
 *
 * Both halves need a model-driven call, because the authority check lives inside the tool
 * executor (`workspace-access.ts`), not in the query service. The mock provider supplies the
 * call: `tool_call_success` makes the harness execute `session_trace` for real, and the refusal
 * lands in the session log as the tool's result (ADR-0027).
 *
 * The probe creates a second session under a DIFFERENT cwd, so the foreign target genuinely
 * exists and the refusal cannot be confused with "not found".
 */
export function apply(ctx, config) {
  if (!config?.enabled) return

  const timer = setTimeout(async () => {
    let foreign
    let handle
    try {
      mkdirSync(config.foreignCwd, { recursive: true })
      // The id is FIXED, because the mock's tool arguments are fixed before this process boots.
      // So a second run finds the first run's session on disk and must resume it rather than
      // fail: "already exists" is the expected state on every run after the first, and a probe
      // that only works once is not a check.
      try {
        foreign = await ctx.agents.create({
          sessionId: config.foreignSessionId,
          meta: { cwd: config.foreignCwd },
          agentOptions: { provider: config.provider, model: config.model },
        })
        foreign.agent.inject(createUserMessage({
          content: [{ type: 'text', text: 'foreign workspace session' }],
          source: { kind: 'user' },
        }))
        console.log(`[l7-auth] foreign session created: ${foreign.agent.session.id}`)
      } catch (error) {
        if (!/already exists/i.test(String(error?.message ?? ''))) throw error
        foreign = await ctx.agents.resume({
          resumeSessionId: config.foreignSessionId,
          agentOptions: { provider: config.provider, model: config.model },
        })
        console.log(`[l7-auth] foreign session resumed (persisted by an earlier run): ${foreign.agent.session.id}`)
      }
      console.log(`[l7-auth] foreign workspace: ${config.foreignCwd}`)

      handle = await ctx.agents.create({
        sessionId: `session-l7-auth-${Date.now()}`,
        meta: { cwd: process.cwd() },
        agentOptions: { provider: config.provider, model: config.model },
      })
      const session = handle.agent.session
      console.log(`[l7-auth] caller workspace: ${session.header?.cwd ?? process.cwd()}`)

      // The mock answers this request with a tool call, so the turn runs the tool for real and
      // then asks again for a closing message.
      handle.agent.followup(createUserMessage({
        content: [{ type: 'text', text: 'Trace the session I named.' }],
        source: { kind: 'user' },
      }))
      await handle.agent.whenIdle()

      const log = await ctx.sessionQuery.readSession(session.id)
      const events = log?.events ?? []
      const results = events.filter(event => event.type === 'tool/result')
      console.log(`[l7-auth] tool/result events: ${results.length}`)
      for (const [index, event] of results.entries()) {
        // Tool results are durable data, so stringifying them is safe (ADR-0028 is about LIVE
        // payloads). Keep it to the fields that carry the refusal.
        const data = event.data ?? {}
        console.log(`[l7-auth] result ${index}: ${JSON.stringify(data).slice(0, 700)}`)
      }
      const types = events.map(event => event.type)
      console.log(`[l7-auth] assistant messages: ${types.filter(type => type === 'assistant/message').length}`)
      const lastEnd = [...events].reverse().find(event => event.type === 'turn/end')
      console.log(`[l7-auth] the turn ended: ${JSON.stringify(lastEnd?.data?.reason)?.slice(0, 160) ?? '(no turn/end)'}`)
    } catch (error) {
      console.log(`[l7-auth] FAILED: ${error.message}`)
      console.log(String(error.stack ?? '').split('\n').slice(1, 4).join('\n'))
    } finally {
      try { await handle?.dispose() } catch { /* already gone */ }
      try { await foreign?.dispose() } catch { /* already gone */ }
      console.log('[l7-auth] done')
    }
  }, config.delayMs)

  ctx.effect(() => () => clearTimeout(timer))
  console.log('[l7-auth] ACTIVE — will make a cross-workspace call through the real tool pipeline')
}
