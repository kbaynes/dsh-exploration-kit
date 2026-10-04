#!/usr/bin/env node
/**
 * Catch a relative link that the site build will reject, before the build does.
 *
 * `VERIFIED.md`, `CONTRIBUTING.md` and `THIRD-PARTY.md` are copied into the VitePress
 * source root (`content/`) at build time. Their copy sits *inside* the site root, so a
 * relative link to a repository-root file resolves to `content/<file>` — which does not
 * exist, and VitePress fails the build with "Found dead link".
 *
 * The rule is in ADR-0012: a synced document references the repository by absolute URL;
 * only unsynced documents may link relatively. That rule had already been broken three
 * times and was broken a fourth while writing it, which is why it is now a check.
 *
 * Usage: node scripts/check-synced-links.mjs
 */

import { readFileSync, existsSync } from 'node:fs'
import { join, resolve } from 'node:path'

const repo = resolve(import.meta.dirname, '..')
const contentDir = join(repo, 'content')

/** Root documents copied into the site source root by scripts/sync-site-docs.mjs. */
const synced = ['VERIFIED.md', 'CONTRIBUTING.md', 'THIRD-PARTY.md']

const problems = []
for (const rel of synced) {
  const file = join(repo, rel)
  if (!existsSync(file)) continue
  const lines = readFileSync(file, 'utf8').split('\n')

  for (const [index, line] of lines.entries()) {
    for (const match of line.matchAll(/\]\(([^)\s]+)\)/g)) {
      const target = match[1]
      if (/^[a-z][a-z0-9+.-]*:/i.test(target) || target.startsWith('#')) continue

      const path = target.split('#')[0]
      if (!path) continue

      // Inside the bundle it is fine; that is where the copy lives.
      const inContent = resolve(contentDir, path)
      if (existsSync(inContent)) continue

      // A target that exists only at the repository root will break the build.
      const atRoot = resolve(repo, path)
      if (existsSync(atRoot)) {
        problems.push(
          `${rel}:${index + 1} — relative link "${target}" resolves outside the site root; ` +
          'use the absolute repository URL (ADR-0012)',
        )
      }
    }
  }
}

if (problems.length === 0) {
  console.log(`${synced.length} synced document(s) have no site-breaking relative links`)
  process.exit(0)
}

console.error(`${problems.length} site-breaking link(s) in synced documents:\n`)
for (const p of problems) console.error(`  ${p}`)
process.exit(1)
