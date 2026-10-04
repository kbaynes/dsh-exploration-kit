import Schema from '@deepseek-ai/schemastery'

export const name = 'l9-webhook-probe'
export const inject = ['webhookRuntime', 'sessionQuery']

export const Config = Schema.object({
  /** Off by default: this registers a rule that CREATES SESSIONS. */
  enabled: Schema.boolean().default(false),
  /**
   * The Web Workspace each delivered session is created in. The verification points this at a
   * temporary directory nobody else uses, so sessions can be COUNTED by `cwd` - an exact key
   * rather than a title heuristic.
   */
  workspacePath: Schema.string().default(''),
  /** Agent composition mounted for each delivered Session. */
  agentPreset: Schema.string().default('cordis'),
  /** Sandbox and approval preset applied before prompt admission (L4's blast-radius lever). */
  permissionPreset: Schema.string().default('workspace-write'),
  /** How often to report the delivered-session count. */
  reportEveryMs: Schema.number().default(2000),
  delayMs: Schema.number().default(1500),
})

/**
 * Tests Lesson 9's WEBHOOK claim: a signed delivery runs a trusted rule, and the rule creates one
 * Session per delivery.
 *
 * The rule is registered here rather than configured, because `ctx.webhookRuntime` is a registry
 * of **trusted programmatic rules** — the lesson's point. Returning a `WebhookSessionRequest`
 * makes the runtime perform its one built-in action: creating an ordinary root Session inside a
 * Web Workspace.
 *
 * What it proves, and what it deliberately does not:
 *
 *   - the rule RUNS for each accepted delivery, printed per delivery id;
 *   - each manifested Session is counted by its `cwd`, so "one Session per delivery" is a number
 *     rather than an impression;
 *   - a REPEATED delivery runs the rule again — the documented behaviour, since `deliveryId` is
 *     recorded but never used for built-in deduplication. The verification posts the same delivery
 *     twice and asserts the count goes to two.
 *
 * It does NOT assert that the delivered Session's turn completes: that is the schedule lesson's
 * claim, verified separately, and it needs the same provider.
 */
export function apply(ctx, config) {
  if (!config?.enabled) return

  const deliveries = []

  ctx.effect(() => ctx.webhookRuntime.register({
    id: 'l9-webhook-delivery',
    kind: 'github',
    run(delivery) {
      deliveries.push(delivery.deliveryId)
      console.log(`[l9-webhook] rule ran for delivery=${delivery.deliveryId} source=${delivery.source} total=${deliveries.length}`)
      return {
        workspacePath: config.workspacePath,
        title: `l9 webhook delivery ${delivery.deliveryId}`,
        prompt: 'The webhook fired; report that you ran.',
        agentPreset: config.agentPreset,
        permissionPreset: config.permissionPreset,
      }
    },
  }))

  // Baselines so the count is about THIS run. Both halves matter:
  //   - delivered Sessions are identified by the id the RUNTIME generates (`webhook-<uuid>`), not
  //     by `cwd`: a workspace path is normalised by the host (`/tmp/x` is recorded as
  //     `/private/tmp/x` on macOS), so comparing paths silently counted zero while the sessions
  //     existed;
  //   - the harness home is SHARED with earlier runs, so an absolute count would include their
  //     sessions. The delta from this probe's first observation is the number the claim is about.
  let baseline = null
  const timer = setInterval(async () => {
    try {
      const records = await ctx.sessionQuery.listSessions()
      const delivered = records.filter(record => String(record.header?.id ?? '').startsWith('webhook-'))
      const ids = delivered.map(record => String(record.header.id))
      if (baseline === null) baseline = new Set(ids)
      const created = ids.filter(id => !baseline.has(id))
      console.log(`[l9-webhook] delivered sessions created since the probe started: ${created.length}`)
    } catch (error) {
      console.log(`[l9-webhook] session count failed: ${error.message}`)
    }
  }, config.reportEveryMs)
  ctx.effect(() => () => clearInterval(timer))

  const start = setTimeout(() => {
    console.log(`[l9-webhook] ACTIVE — rule registered for kind=github; workspace=${config.workspacePath}`)
  }, config.delayMs)
  ctx.effect(() => () => clearTimeout(start))
}
