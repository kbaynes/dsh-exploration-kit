#!/usr/bin/env node
/**
 * Validate every upstream DSH link against a local checkout.
 *
 * The curriculum links to DeepSeek Harness documentation by absolute GitHub URL
 * so the kit works standalone. That makes the links unverifiable by the normal
 * link checker (which deliberately does not fetch external URLs), and it is easy
 * to invent a plausible path — `docs/harness/plugins.md` reads perfectly but does
 * not exist upstream.
 *
 * This check resolves each link's path against a local DSH checkout, so a wrong
 * path fails loudly on a maintainer's machine. It is NOT run in CI, because CI
 * has no checkout.
 *
 * Usage:
 *   node scripts/check-upstream-links.mjs /path/to/deepseek-harness
 *   DSH_CHECKOUT=/path/to/deepseek-harness node scripts/check-upstream-links.mjs
 *
 * Exit codes: 0 = all upstream links resolve, 1 = dead links, 2 = no checkout.
 */

import { readFileSync, readdirSync, existsSync } from 'node:fs'
import { join, relative, resolve } from 'node:path'

const root = resolve(import.meta.dirname, '..')
const contentDir = join(root, 'content')

const checkout = process.argv[2] ?? process.env.DSH_CHECKOUT ?? ''
if (!checkout || !existsSync(checkout)) {
  console.error(
    'No DSH checkout found.\n' +
    'Pass one as an argument or set DSH_CHECKOUT:\n' +
    '  node scripts/check-upstream-links.mjs /path/to/deepseek-harness',
  )
  process.exit(2)
}

/** The upstream repository prefix every checked link must start with. */
const prefix = 'https://github.com/deepseek-ai/deepseek-harness/blob/main/'

function markdownFiles(dir) {
  const out = []
  for (const entry of readdirSync(dir, { withFileTypes: true })) {
    const full = join(dir, entry.name)
    if (entry.isDirectory()) out.push(...markdownFiles(full))
    else if (entry.name.endsWith('.md')) out.push(full)
  }
  return out
}

function stripFences(text) {
  const out = []
  let inFence = false
  for (const line of text.split('\n')) {
    if (/^\s*(```|~~~)/.test(line)) { inFence = !inFence; continue }
    if (!inFence) out.push(line)
  }
  return out.join('\n')
}

const links = new Map() // upstream path -> [{ file, line }]
for (const file of markdownFiles(contentDir)) {
  const raw = readFileSync(file, 'utf8')
  // Generated site pages are copies of root docs; check the root originals only.
  if (raw.includes('GENERATED FILE')) continue
  const body = stripFences(raw)
  body.split('\n').forEach((line, index) => {
    let from = 0
    for (;;) {
      const at = line.indexOf(prefix, from)
      if (at === -1) break
      const rest = line.slice(at + prefix.length)
      const path = rest.split(/[)\s#]/)[0]
      if (path) {
        if (!links.has(path)) links.set(path, [])
        links.get(path).push(`${relative(root, file)}:${index + 1}`)
      }
      from = at + prefix.length
    }
  })
}

const dead = []
for (const [path, sites] of links) {
  if (!existsSync(join(checkout, path))) dead.push({ path, sites })
}

console.log(`checked ${links.size} distinct upstream link(s) against ${checkout}`)
if (dead.length === 0) {
  console.log('all upstream links resolve in the checkout')
  process.exit(0)
}

console.error(`\n${dead.length} upstream link(s) point at paths that do not exist:\n`)
for (const { path, sites } of dead.sort((a, b) => a.path.localeCompare(b.path))) {
  console.error(`  ${path}`)
  for (const site of sites) console.error(`      ${site}`)
}
console.error('\nFix the URL to a path that exists, or reword to avoid the link.')
process.exit(1)
