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

// Resolve against the repository root explicitly: `import.meta.dirname` is absolute
// while a relative argv is not, and mixing the two silently pointed package.json
// resolution at the wrong directory.
const repo = resolve(import.meta.dirname, '..')
const root = resolve(repo, process.argv[2] ?? 'content')

/**
 * Root-level markdown is published too, and its links were previously unchecked
 * entirely — which is how a self-referencing URL to a nonexistent file survived.
 * VERIFIED.md's LOCAL links are deliberately skipped: the site sync rewrites them, so
 * a relative form is valid here and broken only in the generated copy.
 */
const rootDocs = ['README.md', 'PLAN.md', 'ROADMAP.md', 'CONTRIBUTING.md', 'CODE_OF_CONDUCT.md', 'THIRD-PARTY.md']
const syncRewritten = ['VERIFIED.md']

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

// A self-referencing absolute URL (THIS repository's own blob/main path) resolves to a
// local file, so it IS checkable — unlike a genuinely external link. Upstream DSH links
// have the same shape but point at another repository, so the pattern is scoped to this
// repository's identity from package.json. Getting this wrong makes every upstream
// vendor link look broken.
const { kit } = JSON.parse(readFileSync(resolve(repo, 'package.json'), 'utf8'))
const selfUrl = new RegExp(
  `^https://github\\.com/${kit.repositoryOwner}/${kit.repositoryName}/blob/main/(.+)$`,
)

let checked = 0
const broken = []
const external = []

const scanFiles = [
  ...markdownFiles(root),
  ...rootDocs.map(f => resolve(repo, f)).filter(existsSync),
]

for (const file of scanFiles) {
  const raw = readFileSync(file, 'utf8')
  // Generated site pages are copies of root docs; check the root originals only.
  if (raw.includes('GENERATED FILE')) continue
  const body = stripFences(raw)
  for (const match of body.matchAll(linkPattern)) {
    const target = match[1]
    if (target.startsWith('#')) continue
    if (/^https?:\/\//.test(target)) {
      const self = target.match(selfUrl)
      if (self) {
        checked += 1
        const local = resolve(repo, decodeURIComponent(self[1]))
        if (!existsSync(local)) broken.push(`${relative(repo, file)} -> ${target} (resolves to ${relative(repo, local)})`)
        continue
      }
      external.push(target)
      continue
    }
    if (/^[a-z][a-z0-9+.-]*:/i.test(target)) continue // mailto: and friends
    if (syncRewritten.includes(relative(repo, file))) continue
    checked += 1
    const pathPart = target.split('#')[0]
    if (!pathPart) continue
    const candidates = [
      resolve(dirname(file), pathPart),
      resolve(dirname(file), `${pathPart}.md`),
      resolve(dirname(file), pathPart, 'index.md'),
    ]
    if (!candidates.some(c => existsSync(c))) {
      broken.push(`${relative(repo, file)} -> ${target}`)
    }
  }
}

const uniqueExternal = [...new Set(external)].sort()

console.log(`checked ${checked} internal link(s) across ${scanFiles.length} file(s)`)
console.log(`${uniqueExternal.length} distinct external link(s) not fetched (upstream-owned)`)

if (broken.length > 0) {
  console.error(`\n${broken.length} broken internal link(s):`)
  for (const b of broken) console.error(`  ${b}`)
  process.exit(1)
}

console.log('no broken internal links')
