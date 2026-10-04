#!/usr/bin/env node
/**
 * Keep the ADR corpus usable by a future agent.
 *
 * An ADR nobody can find is not a record. This checks that every record is
 * well-formed, sequentially numbered, titled consistently with its number, and
 * listed in the index — so the corpus cannot grow a hole that a reader falls into.
 *
 * Usage: node scripts/check-decisions.mjs
 * Exit codes: 0 = clean, 1 = a record is malformed or unindexed.
 */

import { readFileSync, readdirSync } from 'node:fs'
import { join, resolve } from 'node:path'

const root = resolve(import.meta.dirname, '..')
const dir = join(root, 'decisions')

/** Sections every ADR must contain. */
const requiredSections = ['## Status', '## Context', '## Decision', '## Consequences', '## Evidence']

const files = readdirSync(dir).filter(f => /^\d{4}-.*\.md$/.test(f)).sort()
const problems = []

if (files.length === 0) problems.push('no ADR files found in decisions/')

const index = readFileSync(join(dir, 'README.md'), 'utf8')

files.forEach((file, position) => {
  const expectedNumber = String(position + 1).padStart(4, '0')
  const text = readFileSync(join(dir, file), 'utf8')
  const where = `decisions/${file}`

  // 1. Numbering is contiguous, so a missing record is obvious.
  if (!file.startsWith(`${expectedNumber}-`)) {
    problems.push(`${where}: expected number ${expectedNumber} for position ${position + 1}`)
  }

  // 2. Frontmatter declares the required fields.
  const fm = text.match(/^---\n([\s\S]*?)\n---/)
  if (!fm) {
    problems.push(`${where}: no YAML frontmatter`)
  } else {
    for (const field of ['type: ADR', 'title:', 'description:', 'status:']) {
      if (!fm[1].includes(field)) problems.push(`${where}: frontmatter missing ${field}`)
    }
    const titleMatch = fm[1].match(/title:\s*"?(ADR-\d{4})/)
    if (!titleMatch) {
      problems.push(`${where}: frontmatter title does not start with an ADR number`)
    } else if (titleMatch[1] !== `ADR-${expectedNumber}`) {
      problems.push(`${where}: title says ${titleMatch[1]}, expected ADR-${expectedNumber}`)
    }
  }

  // 3. Every required section is present.
  for (const section of requiredSections) {
    if (!text.includes(section)) problems.push(`${where}: missing section "${section}"`)
  }

  // 4. The index links it.
  if (!index.includes(`(${file})`)) problems.push(`${where}: not listed in decisions/README.md`)
})

// 5. The index does not link a record that does not exist.
for (const link of index.matchAll(/\]\((\d{4}-[^)]+\.md)\)/g)) {
  if (!files.includes(link[1])) {
    problems.push(`decisions/README.md: links ${link[1]}, which does not exist`)
  }
}

if (problems.length === 0) {
  console.log(`${files.length} ADR(s) valid and indexed`)
  process.exit(0)
}

console.error(`${problems.length} problem(s) in the decision corpus:\n`)
for (const p of problems) console.error(`  ${p}`)
console.error('\nRun: node scripts/check-decisions.mjs after fixing each record.')
process.exit(1)
