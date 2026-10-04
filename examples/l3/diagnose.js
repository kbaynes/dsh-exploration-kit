export const name = 'l3-diagnose'

/**
 * Optional name filter. Set `config: { match: 'l3-' }` on this plugin's row to
 * report only the fibers you are working on. Without it, the sweep reports every
 * PENDING/FAILED fiber in the whole composition — which is honest but noisy,
 * because a real profile has services legitimately waiting on optional providers.
 */
import Schema from '@deepseek-ai/schemastery'

export const Config = Schema.object({
  match: Schema.string().default(''),
})

// FiberState is a `const enum`: TypeScript erases it, and it is NOT a runtime
// export of the published @deepseek-ai/cordis package. Importing it — as the
// upstream Cordis tutorial does — throws at load. The numeric values are stable,
// so compare against the documented ordering instead.
const STATE_NAMES = ['PENDING', 'LOADING', 'ACTIVE', 'FAILED', 'DISPOSED', 'UNLOADING']

export function apply(ctx, config) {
  const filter = config?.match ?? ''
  const timer = setTimeout(() => {
    let reported = 0
    for (const runtime of ctx.registry.values()) {
      for (const fiber of runtime.fibers) {
        const name = fiber.name ?? '(unnamed)'
        if (filter && !name.includes(filter)) continue
        if (fiber.state === 0) {
          console.log(`[l3-diagnose] PENDING: ${name} — a required service is missing`)
          reported += 1
        } else if (fiber.state === 3) {
          console.log(`[l3-diagnose] FAILED: ${name}`)
          reported += 1
        }
      }
    }
    const scope = filter ? `matching "${filter}"` : 'across the whole composition'
    console.log(`[l3-diagnose] ${reported} stranded fiber(s) ${scope}`)
  }, 800)
  ctx.effect(() => () => clearTimeout(timer))
}
