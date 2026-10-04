import { appendFileSync } from 'node:fs'
import Schema from '@deepseek-ai/schemastery'

/**
 * The web profile does not surface a plugin's `console.log` to the terminal — its boot
 * prints the URL and nothing else — so a probe that must report a result on this profile
 * writes to a file as well. `L9_PROBE_OUT` names it.
 */
const emit = message => {
  console.log(message)
  const file = process.env.L9_PROBE_OUT
  if (file) appendFileSync(file, message + '\n')
}

export const name = 'l9-probe'
export const inject = ['agents', 'schedule']

export const Config = Schema.object({
  /** Off by default: this creates a real scheduled task. */
  enabled: Schema.boolean().default(false),
  /** 'write' creates a task; 'read' checks it survived a restart, then removes it. */
  mode: Schema.union(['write', 'read']).default('write'),
  /** The fixed session id both modes use, so a restart can find the task. */
  sessionId: Schema.string().default('session-l9-schedule'),
  /** Far enough out that the task never fires during the check. */
  everySeconds: Schema.number().default(86400),
  delayMs: Schema.number().default(1500),
})

/**
 * Tests Lesson 9's scheduling claim — that schedules are Host-owned and SURVIVE RESTARTS —
 * without a model.
 *
 * `ctx.schedule` is the service behind the `schedule_*` tools. Those tools register in a
 * live root Agent's scope and take a model-visible schema; the service is what a code caller
 * uses, and creating a task is not a model call. Delivery is: a due task resumes the
 * session and the agent would then work on it, which does need a provider — so this probe
 * proves the STORAGE half and says so.
 */
export function apply(ctx, config) {
  if (!config?.enabled) return

  const timer = setTimeout(async () => {
    let handle
    try {
      if (config.mode === 'read') {
        const tasks = await ctx.schedule.list({ sessionId: config.sessionId })
        emit(`[l9-probe] after restart, tasks for the session: ${tasks.length}`)
        for (const task of tasks) {
          emit(`[l9-probe]   title="${task.title}" id=${task.id}`)
        }
        // Remove them so a repeated run starts clean, and to check the delete path.
        for (const task of tasks) {
          await ctx.schedule.delete({ sessionId: config.sessionId, id: task.id })
        }
        const after = await ctx.schedule.list({ sessionId: config.sessionId })
        emit(`[l9-probe] after deleting: ${after.length} task(s)`)
        return
      }

      handle = await ctx.agents.create({
        sessionId: config.sessionId,
        meta: { cwd: process.cwd() },
      })
      emit(`[l9-probe] created ${handle.agent.session.id}`)

      const record = await ctx.schedule.create(config.sessionId, {
        title: 'l9 schedule probe',
        prompt: 'This task exists to prove schedule persistence; it should never fire.',
        every_seconds: config.everySeconds,
      })
      emit(`[l9-probe] created task id=${record.id} title="${record.title}"`)

      const tasks = await ctx.schedule.list({ sessionId: config.sessionId })
      emit(`[l9-probe] listed ${tasks.length} task(s): ${tasks.map(t => t.title).join(', ')}`)
      emit('[l9-probe] now STOP this process and re-run with mode=read')
    } catch (error) {
      emit(`[l9-probe] FAILED: ${error.message}`)
      emit(String(error.stack ?? '').split('\n').slice(1, 4).join('\n'))
    } finally {
      try { await handle?.dispose() } catch { /* already gone */ }
      emit('[l9-probe] done')
    }
  }, config.delayMs)

  ctx.effect(() => () => clearTimeout(timer))
  emit('[l9-probe] ACTIVE — will create or inspect a scheduled task')
}
