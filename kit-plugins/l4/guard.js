export const name = 'l4-guard'
export const inject = ['tools']

export function apply(ctx) {
  ctx.tools.guard(exec => {
    if (exec.name === 'bash' && /rm\s+-rf\s+\//.test(JSON.stringify(exec.arguments ?? {}))) {
      return 'refusing a recursive delete of the filesystem root'
    }
    return undefined
  })

  console.log('[l4-guard] ACTIVE — monotonic guard registered')
}
