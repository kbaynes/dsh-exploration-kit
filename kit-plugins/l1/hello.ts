import type { Context } from '@deepseek-ai/cordis'

export const name = 'l1-hello'

export function apply(ctx: Context) {
  console.log('[l1-hello] apply() ran — plugin is ACTIVE')
  ctx.effect(() => {
    console.log('[l1-hello] effect registered')
    return () => console.log('[l1-hello] disposer ran — plugin is DISPOSED')
  })
}
