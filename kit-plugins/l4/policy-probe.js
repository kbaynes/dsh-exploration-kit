import Schema from '@deepseek-ai/schemastery'

export const name = 'l4-probe'
export const inject = ['tools']

export const Config = Schema.object({
  /** Off by default: this dispatches real calls, so it is an opt-in diagnostic. */
  enabled: Schema.boolean().default(false),
  /**
   * A path the policy is expected to ALLOW. This must be the same tree the gate defends
   * (`l4-write-scope`'s `allowedRoot`), which the bundle row derives from KIT_ROOT — so
   * the probe derives it the same way rather than hard-coding one.
   */
  sandbox: Schema.string().default(
    (process.env.KIT_ROOT ?? process.cwd()) + '/l4-sandbox',
  ),
  delayMs: Schema.number().default(1200),
})

/**
 * Exercises the policy pipeline WITHOUT a model.
 *
 * `ctx.tools.execute()` takes the same path a model-direct call takes — pre-execute
 * policy, guards, dispatch — so a gate can be verified end to end offline. That matters
 * because Lesson 4's central claim (a write outside the root is denied, one inside is
 * allowed) otherwise needs a provider, and was recorded as unverified for exactly that
 * reason.
 *
 * This is why the row is `disabled: true` in the bundle: it dispatches real tool calls,
 * so it is an opt-in diagnostic rather than something every boot runs.
 */
export function apply(ctx, config) {
  if (!config?.enabled) return

  const timer = setTimeout(async () => {
    const controller = new AbortController()

    // Which layer denied matters. This probe is about the LESSON's gate, and a denial
    // from any other policy would look identical if we only reported isError. The gate's
    // own reason string is the discriminator.
    const GATE_REASON = 'writes are confined to'

    const probe = async (label, name, args) => {
      try {
        const result = await ctx.tools.execute({
          callId: `l4-probe-${label}`,
          name,
          arguments: args,
          // The input contract requires a signal; the registry re-fuses it before the
          // body runs. Omitting it fails with a bare
          // "Cannot read properties of undefined (reading 'aborted')".
          signal: controller.signal,
        })
        const text = JSON.stringify(result)
        const isError = /"isError":true/.test(text)
        const byGate = text.includes(GATE_REASON)
        const verdict = !isError ? 'ALLOWED' : byGate ? 'GATE-DENIED' : 'OTHER-DENIED'
        console.log(`[l4-probe] ${label}: ${verdict} ${text.slice(0, 200)}`)
      } catch (error) {
        console.log(`[l4-probe] ${label}: THREW ${error.message}`)
      }
    }

    const outside = `${config.sandbox}-outside/probe.txt`
    const inside = `${config.sandbox}/probe.txt`

    // dsh's real filesystem tools take `file_path`, not `path`. Passing the wrong key is
    // rejected by ARGUMENT VALIDATION before any policy runs — a different failure from a
    // policy denial, and one that is easy to misread as the gate working.
    console.log('[l4-probe] dispatching synthetic calls through the real pipeline')
    await probe('write-outside', 'write', { file_path: outside, content: 'probe' })
    await probe('write-inside', 'write', { file_path: inside, content: 'probe' })
    // Non-mutating: the gate guards only write/edit/str_replace_editor, so this should be
    // allowed even though it is outside nothing. It proves the gate is not a blanket deny.
    await probe('read-inside', 'read', { file_path: inside })
    console.log('[l4-probe] done')
  }, config.delayMs)

  ctx.effect(() => () => clearTimeout(timer))
  console.log('[l4-probe] ACTIVE — will dispatch synthetic calls')
}
