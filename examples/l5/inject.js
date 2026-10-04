import { createUserMessage } from '@deepseek-ai/dsh-llm'

export const name = 'l5-inject'
export const inject = ['agents']

export function apply(ctx) {
  ctx.on('agent/created', (agent) => {
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
      console.log(`[l5-inject] skipped: ${error.message}`)
    }
  })

  console.log('[l5-inject] ACTIVE — appends durable context on agent/created')
}
