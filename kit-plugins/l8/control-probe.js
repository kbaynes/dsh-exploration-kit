import Schema from '@deepseek-ai/schemastery'
import { createUserMessage } from '@deepseek-ai/dsh-llm'

export const name = 'l8-control-probe'
export const inject = ['agents', 'sessionQuery']

export const Config = Schema.object({
  /** Off by default: this runs a real delegation with a real provider. */
  enabled: Schema.boolean().default(false),
  provider: Schema.string().default('deepseek-official'),
  model: Schema.string().default('deepseek-flash'),
  waitMs: Schema.number().default(90000),
  delayMs: Schema.number().default(1500),
})

/**
 * Tests Lesson 8's claim that `send_message` reaches a live child and `interrupt_agent` stops it.
 *
 * This is the one claim in the lesson that needs the MODEL to choose, not just a provider to answer:
 * the child's session id exists only after the spawn, so a scripted mock call could never name it.
 * That is why it was recorded as provider-bound, and the assertions are built around what is
 * mechanically checkable once a real model drives the sequence:
 *
 *   - the parent's log shows `send_message` and `interrupt_agent` were actually CALLED;
 *   - the child's log contains the message's marker, so the message reached the child;
 *   - the child's turn closed as an ABORT rather than completing, when it was still running.
 *
 * The third is timing-dependent by nature: a child that finished before the interrupt arrived was
 * not stopped by it. The probe reports which happened instead of assuming, so the check can assert
 * the first two always and the third only when the child was still live.
 */
export function apply(ctx, config) {
  if (!config?.enabled) return

  const timer = setTimeout(async () => {
    let handle
    try {
      const marker = `LIVE-MARKER-${Date.now()}`
      handle = await ctx.agents.create({
        sessionId: `session-l8-control-${Date.now()}`,
        meta: { cwd: process.cwd() },
        agentOptions: { provider: config.provider, model: config.model },
      })
      const parent = handle.agent

      parent.followup(createUserMessage({
        content: [{
          type: 'text',
          text: [
            'Do exactly this, in order, using the tools:',
            '(1) spawn a subagent with run_in_background true, whose task is to count from 1 to 40, one number per line;',
            '(2) call list_agents to obtain that child\'s session id;',
            `(3) call send_message to that id with the text ${marker};`,
            '(4) call interrupt_agent on that id;',
            'Then reply with the single word: done.',
          ].join(' '),
        }],
        source: { kind: 'user' },
      }))
      await parent.whenIdle()

      // Count CALLS, structurally. A substring search over the log is satisfied by the tool
      // CATALOGUE in `request/header`, which lists every tool name - so the first version of this
      // probe reported all three tools as "called" during a turn that made no tool call at all.
      const parentEvents = (await ctx.sessionQuery.readSession(parent.session.id))?.events ?? []
      const calls = parentEvents.filter(event => event.type === 'tool/call').map(event => event.data?.name)
      console.log(`[l8-control] the parent's tool calls: ${calls.join(',') || '(none)'}`)
      console.log(`[l8-control] the parent called send_message: ${calls.includes('send_message')}`)
      console.log(`[l8-control] the parent called interrupt_agent: ${calls.includes('interrupt_agent')}`)
      console.log(`[l8-control] the parent called list_agents: ${calls.includes('list_agents')}`)
      console.log(`[l8-control] the parent called subagent: ${calls.includes('subagent')}`)

      const deadline = Date.now() + config.waitMs
      let childLog = ''
      let childId = ''
      while (Date.now() < deadline) {
        const records = await ctx.sessionQuery.listSessions()
        const child = records.find(record => record.header?.parentSession === parent.session.id)
        if (child !== undefined) {
          childId = String(child.header.id)
          childLog = JSON.stringify((await ctx.sessionQuery.readSession(child.header.id))?.events ?? [])
          // Stop once the child's turn has closed; that is the only state where its reason is final.
          if (childLog.includes('turn/end')) break
        }
        await new Promise(resolve => setTimeout(resolve, 1000))
      }

      console.log(`[l8-control] child session: ${childId || '(none found)'}`)
      // A boolean as well as the id: a check for the string "child session: " also matches
      // "(none found)", so the first version of this phase passed that assertion vacuously.
      console.log(`[l8-control] the delegation created a child session: ${childId !== ''}`)
      console.log(`[l8-control] the message reached the child: ${childLog.includes(marker)}`)
      console.log(`[l8-control] the child's log is non-empty: ${childLog.length > 100}`)
      console.log(`[l8-control] the child's turn closed: ${childLog.includes('turn/end')}`)
      console.log(`[l8-control] the child was interrupted rather than completing: ${childLog.includes('"kind":"aborted"')}`)
    } catch (error) {
      console.log(`[l8-control] FAILED: ${error.message}`)
      console.log(String(error.stack ?? '').split('\n').slice(1, 4).join('\n'))
    } finally {
      try { await handle?.dispose() } catch { /* already gone */ }
      console.log('[l8-control] done')
    }
  }, config.delayMs)

  ctx.effect(() => () => clearTimeout(timer))
  console.log('[l8-control] ACTIVE — will spawn, message and interrupt a child')
}
