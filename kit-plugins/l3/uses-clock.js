export const name = 'l3-uses-clock'
export const inject = ['lessonClock']

export function apply(ctx) {
  console.log(ctx.lessonClock.stamp('l3-uses-clock'))
}
