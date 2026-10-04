#!/usr/bin/env node
/**
 * Fail if any pre-publication placeholder token is still present.
 *
 * Publishing a repository that contains `REPLACE_OWNER` in its metadata, site
 * config, or issue-template contact links produces broken links and a site that
 * points at a stranger's account. This check makes that failure loud.
 *
 * Usage: node scripts/check-placeholders.mjs
 * Exit codes: 0 = clean, 1 = placeholders found.
 */

import { readFileSync, readdirSync, statSync } from 'node:fs'
import { join, relative, resolve } from 'node:path'

const root = resolve(import.meta.dirname, '..')

/** Directories never scanned: generated, vendored, or not published. */
const skipDirs = new Set(['.git', 'node_modules', 'dist', 'cache', '.vitepress'])

/** Files exempt from scanning: this checker necessarily names the tokens. */
const skipFiles = new Set([
  // These necessarily contain the tokens they look for.
  join('scripts', 'check-placeholders.mjs'),
  join('scripts', 'check-publication.mjs'),
])

/** A line carrying this marker is intentional documentation of a placeholder. */
const allowMarker = 'placeholder-check:allow'

/** Tokens that must not survive to publication. */
const tokens = ['REPLACE_OWNER', 'example.invalid', 'your-name', 'YOUR_OWNER']

/** Extensions worth scanning. */
const extensions = ['.md', '.json', '.yml', '.yaml', '.mts', '.ts', '.mjs']

function walk(dir) {
  const out = []
  for (const entry of readdirSync(dir, { withFileTypes: true })) {
    if (entry.name.startsWith('.') && entry.name !== '.github') continue
    const full = join(dir, entry.name)
    if (entry.isDirectory()) {
      if (skipDirs.has(entry.name)) continue
      out.push(...walk(full))
    } else if (extensions.some(ext => entry.name.endsWith(ext))) {
      out.push(full)
    }
  }
  return out
}

const findings = []
for (const file of walk(root)) {
  if (skipFiles.has(relative(root, file))) continue
  const text = readFileSync(file, 'utf8')
  // Generated site pages duplicate root files; scanning them double-reports.
  if (text.includes('GENERATED FILE')) continue
  text.split('\n').forEach((line, index) => {
    if (line.includes(allowMarker)) return
    for (const token of tokens) {
      if (line.includes(token)) {
        findings.push({
          file: relative(root, file),
          line: index + 1,
          token,
          text: line.trim().slice(0, 120),
        })
      }
    }
  })
}

if (findings.length === 0) {
  console.log('no pre-publication placeholders found')
  process.exit(0)
}

console.error(`${findings.length} placeholder occurrence(s) must be replaced before publishing:\n`)
for (const f of findings) {
  console.error(`  ${f.file}:${f.line}  [${f.token}]`)
  console.error(`      ${f.text}`)
}
console.error(
  '\nReplace with the real GitHub owner, then run this check again. ' +
  'Note the VitePress `base` path and the deploy URL must match the real repository name.',
)
process.exit(1)
