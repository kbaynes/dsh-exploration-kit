import { Service } from '@deepseek-ai/cordis'

export class LessonClockService extends Service {
  constructor(ctx) {
    super(ctx, 'lessonClock')
  }

  stamp(label) {
    return `[${label}] ${new Date().toISOString()}`
  }
}

export const name = 'l3-clock'

export function apply(ctx) {
  ctx.plugin(LessonClockService)
  console.log('[l3-clock] service provided as ctx.lessonClock')
}
