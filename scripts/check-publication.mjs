#!/usr/bin/env node
/**
 * The pre-publication gate: refuse to publish while anything is unfinished.
 *
 * Every item here was a real defect found during preparation, or is a step that is
 * irreversible once the repository is public. The point is that publishing is a
 * deliberate act with a checklist, not a `git push` that happens to work.
 *
 * Usage: node scripts/check-publication.mjs
 * Exit codes: 0 = ready, 1 = outstanding items.
 */

import { readFileSync, existsSync } from 'node:fs'
import { resolve } from 'node:path'
import { execFileSync, spawnSync } from 'node:child_process'

const repo = resolve(import.meta.dirname, '..')
const outstanding = []
const done = []

const pass = label => done.push(label)
const fail = (label, how) => outstanding.push({ label, how })

// 1. No pre-publication placeholder may remain anywhere published.
// A non-zero exit is the expected failure mode here, so spawnSync rather than
// execFileSync — and read the verdict from the output either way.
const placeholderRun = spawnSync('node', [resolve(repo, 'scripts/check-placeholders.mjs')], {
  cwd: repo, encoding: 'utf8',
})
const placeholderOutput = `${placeholderRun.stdout ?? ''}${placeholderRun.stderr ?? ''}`
if (placeholderRun.status === 0) pass('no placeholders remain')
else fail('placeholders remain', 'run: pnpm run check:placeholders')

// 2. The repository identity must be filled in, not left as the token.
const pkg = JSON.parse(readFileSync(resolve(repo, 'package.json'), 'utf8'))
if (pkg.kit?.repositoryOwner && pkg.kit.repositoryOwner !== 'REPLACE_OWNER') pass('repository owner set')
else fail('package.json kit.repositoryOwner is still the placeholder', 'see PUBLISHING.md step 2')

// 3. History must not carry the placeholder identity. This is the item that cannot be
//    undone after a push, so it is a hard gate rather than a warning.
let authors = ''
try {
  authors = execFileSync('git', ['-C', repo, 'log', '--format=%an <%ae>'], { encoding: 'utf8' })
} catch {
  authors = ''
}
if (authors.includes('kit@example.invalid')) {
  fail(
    'git history was authored by the placeholder identity kit@example.invalid',
    'rewrite authorship before pushing — see PUBLISHING.md step 3',
  )
} else if (authors.trim()) {
  pass('git history uses a real author identity')
} else {
  fail('no git history found', 'this repository has not been committed yet')
}

// 4. The publishing runbook must exist, since it holds the steps nothing else can.
if (existsSync(resolve(repo, 'PUBLISHING.md'))) pass('PUBLISHING.md present')
else fail('PUBLISHING.md is missing', 'it documents the steps that are not carried by files')

// 5. Topics must be recorded; they are lost on a transfer otherwise.
if (existsSync(resolve(repo, '.github/topics.txt'))) pass('repository topics recorded')
else fail('.github/topics.txt is missing', 'topics decide discoverability and are lost on transfer')

// 6. The site must build: a published site that fails to build is the loudest failure.
const build = spawnSync('pnpm', ['run', '-s', 'build'], { cwd: repo, encoding: 'utf8' })
if (build.status === 0) pass('site builds')
else fail('the site build failed', 'run: pnpm run build')

console.log(`${done.length} item(s) ready:`)
for (const d of done) console.log(`  READY  ${d}`)

if (outstanding.length === 0) {
  console.log('\nReady to publish. Next: PUBLISHING.md steps 5-8.')
  process.exit(0)
}

console.error(`\n${outstanding.length} item(s) outstanding — NOT ready to publish:\n`)
for (const o of outstanding) console.error(`  BLOCKED  ${o.label}\n           ${o.how}`)
process.exit(1)
