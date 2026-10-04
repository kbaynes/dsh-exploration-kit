import { createUserMessage } from '@deepseek-ai/dsh-llm'

export const name = 'l5-inject'
export const inject = ['agents']

export function apply(ctx) {
  // The payload is an OBJECT ({ agent, source, signal }), not the agent itself.
  // Treating it as the agent gives `payload.session === undefined`, which fails with
  // "Invalid value used as weak map key" the first time a real session is created.
  ctx.on('agent/created', ({ agent }) => {
    try {
      agent.inject(createUserMessage({
        content: [
          {
            type: 'text',
            text: 'Exploration mode: when you explain a change, name the file it lands in.',
          },
        ],
        source: { kind: 'l5-inject' },
      }))
      console.log('[l5-inject] context appended to the next admitted request')
    } catch (error) {
      // The agent may already be disposed; never let a notification kill a plugin.
      // Keep this LOUD: a silent catch would hide a wrong payload shape, which is how
      // this plugin previously did nothing at all without anyone noticing.
      console.log(`[l5-inject] FAILED to inject: ${error.message}`)
    }
  })

  console.log('[l5-inject] ACTIVE — appends durable context on agent/created')
}
