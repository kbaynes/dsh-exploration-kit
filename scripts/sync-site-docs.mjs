#!/usr/bin/env node
/**
 * Copy repository-root documents into the VitePress source root before a build.
 *
 * The site's source root is `content/`, but VERIFIED.md, CONTRIBUTING.md, and
 * THIRD-PARTY.md belong at the repository root where contributors expect them.
 * VitePress refuses links that escape its source root ("Found dead link
 * ../VERIFIED"), so the pages are copied in for the build rather than linked
 * across the boundary.
 *
 * The root copy stays canonical. The `content/` copies are generated and
 * git-ignored — never edit them; edit the root file.
 *
 * Usage: node scripts/sync-site-docs.mjs
 */

import { copyFileSync, readFileSync, writeFileSync } from 'node:fs'
import { join, resolve } from 'node:path'

const root = resolve(import.meta.dirname, '..')
const contentDir = join(root, 'content')

/** Root file -> generated page in content/, with the frontmatter it needs.
 *  `content/` is an OKF bundle, so every generated page needs a `type`. */
const pages = [
  {
    source: 'VERIFIED.md',
    target: 'VERIFIED.md',
    type: 'Verification Ledger',
    title: 'Verification status',
    description: 'Exactly which lesson steps have been executed, against which DeepSeek Harness version.',
  },
  {
    source: 'CONTRIBUTING.md',
    target: 'CONTRIBUTING.md',
    type: 'Contribution Guide',
    title: 'Contributing',
    description: 'How to verify a lesson, fix clarity, and keep the verification rule intact.',
  },
  {
    source: 'THIRD-PARTY.md',
    target: 'THIRD-PARTY.md',
    type: 'Attribution',
    title: 'Third-party notices',
    description: 'Attribution and derivation boundaries for DeepSeek Harness material and website dependencies.',
  },
]

const banner =
  '<!-- GENERATED FILE — do not edit. Edited by scripts/sync-site-docs.mjs\n' +
  '     from the repository root copy. Edit that file instead. -->\n\n'

for (const { source, target, type, title, description } of pages) {
  const from = join(root, source)
  const to = join(contentDir, target)

  // Strip the leading H1: VitePress renders the title from frontmatter/filename,
  // and a duplicated H1 in the body looks like a mistake on the page.
  const body = readFileSync(from, 'utf8')
  const withoutTitle = body.replace(/^#\s+.*\n/, '')
  const frontmatter =
    '---\n' +
    `type: ${type}\n` +
    `title: ${title}\n` +
    `description: ${description}\n` +
    '---\n\n'
  writeFileSync(to, frontmatter + banner + withoutTitle)
  console.log(`synced ${source} -> content/${target}`)
}
