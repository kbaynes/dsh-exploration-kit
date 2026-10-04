import { resolve, sep } from 'node:path'
import Schema from '@deepseek-ai/schemastery'

/**
 * Only writes under this root are allowed. It must be an absolute path: the dsh
 * process runs from the checkout, so `process.cwd()` is NOT the kit. The row
 * supplies it, and falls back to an env var for throwaway experiments.
 */
export const Config = Schema.object({
  allowedRoot: Schema.string().default(resolve(process.env.KIT_SANDBOX ?? process.cwd(), 'l4-sandbox')),
})

function isMutatingFsTool(name) {
  return name === 'write' || name === 'edit' || name === 'str_replace_editor'
}

function targetPath(exec) {
  const args = exec.arguments ?? {}
  const value = args.path ?? args.file_path ?? args.filePath
  return typeof value === 'string' ? value : undefined
}

export const name = 'l4-write-scope'
export const inject = ['tools']

export function apply(ctx, config) {
  const ALLOWED = resolve(config.allowedRoot)

  ctx.on('tools/pre-execute', async (exec, next) => {
    if (!isMutatingFsTool(exec.name)) return next()

    const target = targetPath(exec)
    if (target === undefined) {
      return { kind: 'ask', reason: `${exec.name} without a resolvable path` }
    }

    const absolute = resolve(target)
    if (absolute !== ALLOWED && !absolute.startsWith(ALLOWED + sep)) {
      return { kind: 'deny', reason: `writes are confined to ${ALLOWED}` }
    }
    return next()
  })

  console.log(`[l4-write-scope] ACTIVE — writes confined to ${ALLOWED}`)
}
