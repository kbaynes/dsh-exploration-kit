#!/usr/bin/env node
/**
 * Enforce the lesson structure the curriculum promises.
 *
 * Every lesson has the same shape (goal → concepts → steps → verification → exit check
 * → next), and that sameness is what makes the kit navigable. A lesson missing a
 * section is not a style problem: "Verification" and "Exit check" are where a reader
 * learns whether they are done, and their absence is invisible without a check.
 *
 * The terminal section is allowed a second name: the last lesson has nowhere to send a
 * reader, so it closes with "Where to go next" instead.
 *
 * Usage: node scripts/check-lessons.mjs
 */

import { readFileSync, readdirSync } from 'node:fs'
import { join, resolve } from 'node:path'

const repo = resolve(import.meta.dirname, '..')
const lessonsDir = join(repo, 'content', 'lessons')

/** Sections every lesson must have, in this order. */
const required = [
  { key: 'goal', match: /^\*\*Goal\.\*\*/m, label: 'Goal' },
  { key: 'concepts', match: /^## Concepts taught$/m, label: 'Concepts taught' },
  { key: 'prereq', match: /^## Prerequisites$/m, label: 'Prerequisites' },
  { key: 'verify', match: /^## Verification$/m, label: 'Verification' },
  { key: 'exit', match: /^## Exit check/m, label: 'Exit check' },
  { key: 'next', match: /^## (Next|Where to go next)$/m, label: 'Next' },
]

const files = readdirSync(lessonsDir).filter(f => /^\d{2}-.*\.md$/.test(f)).sort()
const problems = []

if (files.length !== 9) problems.push(`expected 9 lessons, found ${files.length}`)

files.forEach((file, index) => {
  const text = readFileSync(join(lessonsDir, file), 'utf8')
  const where = `lessons/${file}`

  // Required sections exist, and appear in order.
  let lastPosition = -1
  for (const section of required) {
    const found = text.match(section.match)
    if (!found) {
      problems.push(`${where}: missing section "${section.label}"`)
      continue
    }
    if (found.index < lastPosition) {
      problems.push(`${where}: "${section.label}" appears out of order`)
    }
    lastPosition = found.index
  }

  // Frontmatter carries the OKF fields the bundle requires.
  const fm = text.match(/^---\n([\s\S]*?)\n---/)
  if (!fm) problems.push(`${where}: no YAML frontmatter`)
  else for (const field of ['type: Exploration Lesson', 'title:', 'description:']) {
    if (!fm[1].includes(field)) problems.push(`${where}: frontmatter missing ${field}`)
  }

  // The title matches the file number, so a reordering cannot leave one stale.
  const expected = `L${index + 1} `
  if (fm && !fm[1].includes(`title: "${expected}`) && !fm[1].includes(`title: '${expected}`)) {
    problems.push(`${where}: title does not start with "${expected}"`)
  }

  // Lessons 1..8 link onward; the last one must not.
  const linksForward = /\]\(\.\/\d{2}-/.test(text)
  if (index < files.length - 1 && !linksForward) problems.push(`${where}: does not link to the next lesson`)
  if (index === files.length - 1 && linksForward) problems.push(`${where}: the final lesson should not link onward`)

  // Every lesson states what it cannot verify, or says nothing is unverifiable.
  if (!/VERIFIED\.md/.test(text)) {
    problems.push(`${where}: does not reference the verification ledger`)
  }
})

if (problems.length === 0) {
  console.log(`${files.length} lesson(s) match the required structure`)
  process.exit(0)
}

console.error(`${problems.length} lesson-structure problem(s):\n`)
for (const p of problems) console.error(`  ${p}`)
process.exit(1)
