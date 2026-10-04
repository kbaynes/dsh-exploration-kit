import { projection } from './fold.js'

export const name = 'l6-projection'
export const inject = ['sessionProjections']

export function apply(ctx) {
  ctx.sessionProjections.register(projection)
  console.log('[l6-projection] ACTIVE — registered the l6Steps unit')
}
