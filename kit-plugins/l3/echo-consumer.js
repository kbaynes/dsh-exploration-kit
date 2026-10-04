export const name = 'l3-echo-consumer'
export const inject = ['lessonEcho']

export function apply(ctx) {
  // With `isolate` on the enclosing group, this resolves to THAT group's provider.
  console.log(`[l3-echo] ${ctx.lessonEcho.greeting}`)
}
