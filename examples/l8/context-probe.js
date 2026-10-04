import Schema from '@deepseek-ai/schemastery'
import { createUserMessage } from '@deepseek-ai/dsh-llm'

export const name = 'l8-context-probe'
export const inject = ['agents', 'sessionQuery']

export const Config = Schema.object({
  /** Off by default: this runs a REAL delegation with a real provider. */
  enabled: Schema.boolean().default(false),
  provider: Schema.string().default('deepseek-official'),
  model: Schema.string().default('deepseek-flash'),
  /** How long to wait for the child's session to appear and flush before giving up. */
  waitMs: Schema.number().default(60000),
  delayMs: Schema.number().default(1500),
})

/**
 * Tests Lesson 8's claim that a **spawned child does not share the parent's conversation context**.
 *
 * The mock provider cannot show this: scripted output does not depend on what the child was given,
 * so a passphrase would be absent from the child's answer either way. That is exactly why this claim
 * was recorded as provider-bound, and why this probe needs a real model.
 *
 * The design is mechanical rather than judgemental, which is what makes it checkable:
 *
 *   1. the parent is told a unique PASSPHRASE and asked to delegate;
 *   2. the child is asked for the passphrase, and told to answer `NOT-TOLD` if it has none;
 *   3. the assertion is about the CHILD'S SESSION LOG, not its prose — the passphrase must be
 *      absent from the child's conversation, and present in the parent's.
 *
 * A prompt-following failure is therefore visible as a test failure, but the *claim* being tested is
 * a fact about context, not about the model's answer.
 */
export function apply(ctx, config) {
  if (!config?.enabled) return

  const timer = setTimeout(async () => {
    let handle
    try {
      const passphrase = `PASSPHRASE-${Date.now()}`
      handle = await ctx.agents.create({
        sessionId: `session-l8-context-${Date.now()}`,
        meta: { cwd: process.cwd() },
        agentOptions: { provider: config.provider, model: config.model },
      })
      const parent = handle.agent
      console.log(`[l8-context] passphrase planted in the parent: ${passphrase}`)

      parent.followup(createUserMessage({
        content: [{
          type: 'text',
          text: [
            `The secret passphrase for this session is ${passphrase}.`,
            'Delegate to a subagent, in the foreground (run_in_background false), with exactly this task:',
            `"What is the secret passphrase? If you were not told one, answer exactly NOT-TOLD."`,
            'Then report the child\'s answer verbatim in one line.',
          ].join(' '),
        }],
        source: { kind: 'user' },
      }))
      await parent.whenIdle()

      const parentLog = JSON.stringify((await ctx.sessionQuery.readSession(parent.session.id))?.events ?? [])
      console.log(`[l8-context] the parent's own log contains the passphrase: ${parentLog.includes(passphrase)}`)

      // The child's session appears and flushes asynchronously; poll rather than sleep (ADR-0032).
      const deadline = Date.now() + config.waitMs
      let childLog = ''
      let childId = ''
      while (Date.now() < deadline) {
        const records = await ctx.sessionQuery.listSessions()
        const child = records.find(record => record.header?.parentSession === parent.session.id)
        if (child !== undefined) {
          childId = String(child.header.id)
          childLog = JSON.stringify((await ctx.sessionQuery.readSession(child.header.id))?.events ?? [])
          if (childLog.includes('"turn/end"')) break
        }
        await new Promise(resolve => setTimeout(resolve, 1000))
      }

      console.log(`[l8-context] child session: ${childId || '(none found)'}`)
      console.log(`[l8-context] the child's log contains the passphrase: ${childLog.includes(passphrase)}`)
      console.log(`[l8-context] the child's log is non-empty: ${childLog.length > 100}`)
      console.log(`[l8-context] the child's turn closed: ${childLog.includes('"turn/end"')}`)
      // The child's own answer, for the reader: NOT-TOLD is what a context-free child says.
      console.log(`[l8-context] the child replied NOT-TOLD: ${childLog.includes('NOT-TOLD')}`)
    } catch (error) {
      console.log(`[l8-context] FAILED: ${error.message}`)
      console.log(String(error.stack ?? '').split('\n').slice(1, 4).join('\n'))
    } finally {
      try { await handle?.dispose() } catch { /* already gone */ }
      console.log('[l8-context] done')
    }
  }, config.delayMs)

  ctx.effect(() => () => clearTimeout(timer))
  console.log('[l8-context] ACTIVE — will plant a passphrase and delegate')
}
