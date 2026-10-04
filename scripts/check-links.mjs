#!/usr/bin/env node
/**
 * Check that every relative link inside the curriculum resolves on disk.
 *
 * Upstream links (http/https) are external and intentionally not fetched here:
 * the kit depends on DeepSeek Harness documentation that it does not control.
 * Broken *internal* links are always a defect, so they fail the check.
 *
 * Usage: node scripts/check-links.mjs [contentDir]
 */

import { readFileSync, readdirSync, existsSync, statSync } from 'node:fs'
import { dirname, join, resolve, relative } from 'node:path'

const root = resolve(process.argv[2] ?? 'content')

/** Walk a directory for markdown files. */
function markdownFiles(dir) {
  const out = []
  for (const entry of readdirSync(dir, { withFileTypes: true })) {
    const full = join(dir, entry.name)
    if (entry.isDirectory()) out.push(...markdownFiles(full))
    else if (entry.name.endsWith('.md')) out.push(full)
  }
  return out
}

/** Strip fenced code blocks so example links inside them are not checked. */
function stripFences(text) {
  const lines = text.split('\n')
  const out = []
  let inFence = false
  for (const line of lines) {
    if (/^\s*(```|~~~)/.test(line)) {
      inFence = !inFence
      continue
    }
    if (!inFence) out.push(line)
  }
  return out.join('\n')
}

const linkPattern = /\[[^\]]*\]\(([^)\s]+)\)/g

let checked = 0
const broken = []
const external = []

for (const file of markdownFiles(root)) {
  const body = stripFences(readFileSync(file, 'utf8'))
  for (const match of body.matchAll(linkPattern)) {
    const target = match[1]
    if (target.startsWith('#')) continue
    if (/^https?:\/\//.test(target)) {
      external.push(target)
      continue
    }
    if (/^[a-z][a-z0-9+.-]*:/i.test(target)) continue // mailto: and friends
    checked += 1
    const pathPart = target.split('#')[0]
    if (!pathPart) continue
    const candidates = [
      resolve(dirname(file), pathPart),
      resolve(dirname(file), `${pathPart}.md`),
      resolve(dirname(file), pathPart, 'index.md'),
    ]
    if (!candidates.some(c => existsSync(c))) {
      broken.push(`${relative(root, file)} -> ${target}`)
    }
  }
}

const uniqueExternal = [...new Set(external)].sort()

console.log(`checked ${checked} internal link(s) across ${markdownFiles(root).length} file(s)`)
console.log(`${uniqueExternal.length} distinct external link(s) not fetched (upstream-owned)`)

if (broken.length > 0) {
  console.error(`\n${broken.length} broken internal link(s):`)
  for (const b of broken) console.error(`  ${b}`)
  process.exit(1)
}

console.log('no broken internal links')
