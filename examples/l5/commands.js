export const name = 'l5-commands'
export const inject = ['commands']

export function apply(ctx) {
  ctx.commands.register({
    name: 'l5-facts',
    description: 'Print how the DSH exploration kit is laid out',
    handler: () => ({
      kind: 'success',
      text: [
        'content/      the curriculum (OKF bundle) — start at content/index.md',
        'content/lessons/   01..09, one seam each',
        'kit-plugins/  the bundle every lesson installs',
        'solutions/    answer key + per-lesson verify scripts',
        'examples/     generated mirror of the lesson files',
      ].join('\n'),
    }),
  })

  console.log('[l5-commands] ACTIVE — /l5-facts registered')
}
