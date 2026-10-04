import Schema from '@deepseek-ai/schemastery'
import { mkdirSync, writeFileSync } from 'node:fs'
import { join } from 'node:path'
import { createUserMessage } from '@deepseek-ai/dsh-llm'

export const name = 'l5-live-catalog-probe'
export const inject = ['agents', 'sessionQuery']

export const Config = Schema.object({
  /** Off by default: this runs two real turns. */
  enabled: Schema.boolean().default(false),
  /** The watched skill root the overlay points the provider at. */
  skillsDir: Schema.string().default(''),
  /** The skill directory this probe CREATES, to prove the catalog follows the filesystem. */
  newSkillName: Schema.string().default('live-added-skill'),
  /** Provider route and model for both turns (ADR-0028). */
  provider: Schema.string().default('deepseek-official'),
  model: Schema.string().default('deepseek-flash'),
  /** Time for the watcher to notice the new directory (stability threshold is 200ms). */
  settleMs: Schema.number().default(3000),
  delayMs: Schema.number().default(1500),
})

/**
 * Tests Lesson 5's step 7: adding a skill to a WATCHED root changes the catalog **without a
 * restart**.
 *
 * Two sessions in ONE process. The first runs a turn before the change; then the probe writes a
 * new skill directory; then a SECOND session runs a turn. If the catalog is built from the
 * provider's live state, the second turn announces both skills while the first announced only the
 * original. A second session rather than a second turn is deliberate: the catalog is injected as
 * durable context, and re-announcing it mid-session is a different question from whether the
 * provider's view of the filesystem is live.
 *
 * The probe writes into `skillsDir`, which the verification script points at a temporary
 * directory — never at `<kit>/kit-plugins/l5/skills`, so a killed run cannot leave the repository
 * renamed.
 */
export function apply(ctx, config) {
  if (!config?.enabled) return

  const timer = setTimeout(async () => {
    const handles = []
    try {
      const runTurn = async (sessionId) => {
        const handle = await ctx.agents.create({
          sessionId,
          meta: { cwd: process.cwd() },
          agentOptions: { provider: config.provider, model: config.model },
        })
        handles.push(handle)
        handle.agent.followup(createUserMessage({
          content: [{ type: 'text', text: 'say hi' }],
          source: { kind: 'user' },
        }))
        await handle.agent.whenIdle()
        const log = await ctx.sessionQuery.readSession(handle.agent.session.id)
        return JSON.stringify(log?.events ?? [])
      }

      const before = await runTurn(`session-l5-live-before-${Date.now()}`)
      console.log(`[l5-live] before: catalogue mentions the original skill: ${before.includes('repo-onboarding')}`)
      console.log(`[l5-live] before: catalogue mentions the new skill: ${before.includes(config.newSkillName)}`)

      // Write a SECOND skill into the watched root. Directory name, frontmatter `name`, and a body
      // phrase that appears nowhere else, so the assertion cannot match by accident.
      const dir = join(config.skillsDir, config.newSkillName)
      mkdirSync(dir, { recursive: true })
      writeFileSync(join(dir, 'SKILL.md'), [
        '---',
        `name: ${config.newSkillName}`,
        'description: Added while the harness was running, to prove the catalog follows the filesystem.',
        '---',
        '',
        '# Live-added skill',
        '',
        'This body was written into a watched skill root after the harness started.',
        '',
      ].join('\n'))
      console.log(`[l5-live] wrote ${join(dir, 'SKILL.md')}`)
      await new Promise(resolve => setTimeout(resolve, config.settleMs))

      const after = await runTurn(`session-l5-live-after-${Date.now()}`)
      console.log(`[l5-live] after: catalogue mentions the original skill: ${after.includes('repo-onboarding')}`)
      console.log(`[l5-live] after: catalogue mentions the new skill: ${after.includes(config.newSkillName)}`)
      console.log(`[l5-live] after: the new skill's BODY is not shipped either: ${!after.includes('written into a watched skill root')}`)
    } catch (error) {
      console.log(`[l5-live] FAILED: ${error.message}`)
      console.log(String(error.stack ?? '').split('\n').slice(1, 4).join('\n'))
    } finally {
      for (const handle of handles) {
        try { await handle.dispose() } catch { /* already gone */ }
      }
      console.log('[l5-live] done')
    }
  }, config.delayMs)

  ctx.effect(() => () => clearTimeout(timer))
  console.log('[l5-live] ACTIVE — will add a skill to a watched root and look again without restarting')
}
