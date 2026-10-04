#!/usr/bin/env node
/**
 * Drive one real turn through the TypeScript SDK, against a mock provider.
 *
 * The SDK is imported by absolute path out of the checkout under test: pnpm does not hoist it to the
 * checkout root, so a bare specifier fails with MODULE_NOT_FOUND from anywhere else.
 *
 * Usage: node solutions/sdk-roundtrip.mjs <path-to-deepseek-harness>
 * Env:   DSH_HOME, DEEPSEEK_BASE_URL, DEEPSEEK_API_KEY (from the mock provider)
 *        SDK_PROMPT  the prompt to send (default "say hi")
 *        SDK_PATCH   an absolute path to a patch file to load (optional)
 *
 * Prints `key=value` lines so a shell check can assert on them.
 */
const checkout = process.argv[2]
if (!checkout) {
  console.error('usage: node solutions/sdk-roundtrip.mjs <path-to-deepseek-harness>')
  process.exit(2)
}

const { DeepSeekHarness } = await import(`${checkout}/packages/sdk/client/lib/index.js`)

const prompt = process.env.SDK_PROMPT ?? 'say hi'
// `patches` is the SDK's own option: the SDK spawns `dsh` and forwards each path as `--patch`,
// which is how an SDK caller composes a profile without editing it. An absolute path is required
// because the SDK resolves relative paths against the CALLER's cwd, not this file's.
const patches = process.env.SDK_PATCH ? [process.env.SDK_PATCH] : []

const harness = new DeepSeekHarness({
  profile: 'sdk-minimal',
  provider: 'deepseek-official',
  model: 'deepseek-flash',
  ...(patches.length > 0 ? { patches } : {}),
})

try {
  const result = await harness.run(prompt)
  console.log(`finalResponse=${JSON.stringify(result.finalResponse)}`)
  console.log(`sessionId=${result.sessionId}`)
  console.log(`notifications=${result.notifications?.length ?? 0}`)
  console.log(`patches=${patches.length}`)
} catch (error) {
  console.log(`error=${error?.constructor?.name}: ${error?.message}`)
  process.exitCode = 1
} finally {
  await harness.close?.()
}
