import { readFile } from 'node:fs/promises'
import { defineTool } from '@deepseek-ai/dsh-tools'
import Schema from '@deepseek-ai/schemastery'

export const name = 'l2-wordcount'
export const inject = ['tools']

export const Config = Schema.object({
  defaultUnit: Schema.union(['words', 'lines', 'chars']).default('words'),
})

export function apply(ctx, config) {
  ctx.tools.register(defineTool({
    name: 'word_count',
    description: 'Count lines, words, and characters in a file.',
    parameters: {
      path: { type: 'string', required: true, description: 'Absolute path' },
      unit: { type: 'string', enum: ['words', 'lines', 'chars'] },
    },
    output: {
      schema: {
        type: 'object',
        additionalProperties: false,
        properties: {
          unit: { type: 'string', required: true },
          count: { type: 'number', required: true },
        },
      },
      render: (_args, value) => [{ type: 'text', text: `${value.count} ${value.unit}` }],
    },
    async execute(args, exec) {
      const text = await readFile(args.path, { encoding: 'utf8', signal: exec.signal })
      const unit = args.unit ?? config.defaultUnit
      const count = unit === 'lines' ? text.split('\n').length - 1
        : unit === 'chars' ? text.length
        : text.split(/\s+/).filter(Boolean).length
      return { unit, count }
    },
  }))
  console.log(`[l2-wordcount] ACTIVE — defaultUnit=${config.defaultUnit}`)
}
