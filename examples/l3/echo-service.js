import { Service } from '@deepseek-ai/cordis'
import Schema from '@deepseek-ai/schemastery'

/**
 * A Service subclass that is itself the plugin: exporting it as default is how Cordis
 * constructs it with `(ctx, config)` — no `apply` wrapper. The harness's own services do the
 * same (`sandbox-policy` ends with `export default SandboxPolicyService`).
 */
export class LessonEchoService extends Service {
  constructor(ctx, config) {
    super(ctx, 'lessonEcho')
    this.greeting = config.greeting
  }
}

export const name = 'l3-echo-service'

export const Config = Schema.object({
  greeting: Schema.string().default('(default)'),
})

export default LessonEchoService
