#!/usr/bin/env node
/**
 * Drive one real turn through the TypeScript SDK, against a mock provider.
 *
 * The SDK is imported by absolute path out of the checkout under test: pnpm does not hoist it to the
 * checkout root, so a bare specifier fails with MODULE_NOT_FOUND from anywhere else.
 *
 * Usage: node solutions/sdk-roundtrip.mjs <path-to-deepseek-harness>
 * Env:   DSH_HOME, DEEPSEEK_BASE_URL, DEEPSEEK_API_KEY (from the mock provider)
 *
 * Prints `key=value` lines so a shell check can assert on them.
 */
const checkout = process.argv[2]
if (!checkout) {
  console.error('usage: node solutions/sdk-roundtrip.mjs <path-to-deepseek-harness>')
  process.exit(2)
}

const { DeepSeekHarness } = await import(`${checkout}/packages/sdk/client/lib/index.js`)

const harness = new DeepSeekHarness({
  profile: 'sdk-minimal',
  provider: 'deepseek-official',
  model: 'deepseek-flash',
})

try {
  const result = await harness.run('say hi')
  console.log(`finalResponse=${JSON.stringify(result.finalResponse)}`)
  console.log(`sessionId=${result.sessionId}`)
  console.log(`notifications=${result.notifications?.length ?? 0}`)
} catch (error) {
  console.log(`error=${error?.constructor?.name}: ${error?.message}`)
  process.exitCode = 1
} finally {
  await harness.close?.()
}
