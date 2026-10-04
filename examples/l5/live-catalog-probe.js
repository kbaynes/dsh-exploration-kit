import Schema from '@deepseek-ai/schemastery'
import { mkdirSync, writeFileSync } from 'node:fs'
import { join } from 'node:path'
import { createUserMessage } from '@deepseek-ai/dsh-llm'

export const name = 'l5-live-catalog-probe'
export const inject = ['agents', 'sessionQuery', 'skills']

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
      // The catalogue is skipped while discovery is incomplete. The listener asks with
      // `scope: agent`, a separate observation from the unscoped ask, so both are waited on -
      // and AFTER the agent exists, because the agent-scoped view cannot be observed before it
      // does. Driving the turn earlier races the watcher; that race, not a product bug, is what
      // made this probe and the catalogue probe fail intermittently.
      const waitForComplete = async agent => {
        const observe = async () => ({
          plain: await ctx.skills.snapshot({ cwd: process.cwd() }),
          scoped: await ctx.skills.snapshot({ cwd: process.cwd(), scope: agent }),
        })
        let { plain, scoped } = await observe()
        const deadline = Date.now() + 20000
        while ((!plain.complete || !scoped.complete) && Date.now() < deadline) {
          await new Promise(resolve => setTimeout(resolve, 500))
          ;({ plain, scoped } = await observe())
        }
        return { plain, scoped }
      }

      const runTurn = async (sessionId) => {
        const handle = await ctx.agents.create({
          sessionId,
          meta: { cwd: process.cwd() },
          agentOptions: { provider: config.provider, model: config.model },
        })
        handles.push(handle)
        const snapshot = await waitForComplete(handle.agent)
        handle.agent.followup(createUserMessage({
          content: [{ type: 'text', text: 'say hi' }],
          source: { kind: 'user' },
        }))
        await handle.agent.whenIdle()
        const log = await ctx.sessionQuery.readSession(handle.agent.session.id)
        const events = log?.events ?? []
        // The catalogue is read from the message that carries it, not by searching the log: a
        // substring search is satisfied by anything that names the skill (ADR-0028's sibling
        // failure mode). The event count is reported too, because a negative assertion ("the body
        // is NOT there") passes vacuously against an empty log.
        const catalogues = events.filter(event =>
          event.type === 'user/message' && event.data?.source?.kind === 'skill-catalog')
        return {
          catalogue: JSON.stringify(catalogues),
          body: JSON.stringify(events),
          events: events.length,
          complete: snapshot.plain.complete && snapshot.scoped.complete,
        }
      }

      const before = await runTurn(`session-l5-live-before-${Date.now()}`)
      console.log(`[l5-live] before: events read from the log: ${before.events}`)
      console.log(`[l5-live] before: catalogue mentions the original skill: ${before.catalogue.includes('repo-onboarding')}`)
      console.log(`[l5-live] before: catalogue mentions the new skill: ${before.catalogue.includes(config.newSkillName)}`)

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
      console.log(`[l5-live] after: events read from the log: ${after.events}`)
      console.log(`[l5-live] after: catalogue mentions the original skill: ${after.catalogue.includes('repo-onboarding')}`)
      console.log(`[l5-live] after: catalogue mentions the new skill: ${after.catalogue.includes(config.newSkillName)}`)
      // Guard the negative assertion: with no events at all it would pass while proving nothing.
      console.log(`[l5-live] after: the new skill's BODY is not shipped either: ${after.events > 0 && !after.body.includes('written into a watched skill root')}`)
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
