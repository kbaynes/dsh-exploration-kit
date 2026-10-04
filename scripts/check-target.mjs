#!/usr/bin/env node
/**
 * Hold every record of the harness state to kit.target.json.
 *
 * The harness version and commit are necessarily written in more than one place — the
 * ledger's heading, the README's compatibility note, the tag format, the bundle's pinned
 * dependencies, the verify scripts' defaults. Before this check existed they were eight
 * independent facts free to drift, and a drift between any two of them is a false claim
 * about what was verified.
 *
 *   Environment-free  every record agrees with kit.target.json
 *   Needs a checkout  the checkout IS that commit and is clean
 *
 * Usage:
 *   node scripts/check-target.mjs [path-to-deepseek-harness]
 *   DSH_CHECKOUT=/path/to/deepseek-harness node scripts/check-target.mjs
 */

import { readFileSync } from 'node:fs'
import { resolve } from 'node:path'
import { execFileSync } from 'node:child_process'

const repo = resolve(import.meta.dirname, '..')
const target = JSON.parse(readFileSync(resolve(repo, 'kit.target.json'), 'utf8'))
const { version, tag, commit, commitShort } = target.dsh
const checkout = process.argv[2] ?? process.env.DSH_CHECKOUT ?? ''

const problems = []
const check = (label, ok, detail = '') => {
  if (!ok) problems.push(`${label}${detail ? ` — ${detail}` : ''}`)
}

/** A file must mention the given string. */
const mentions = (rel, needle, label) => {
  const text = readFileSync(resolve(repo, rel), 'utf8')
  check(label, text.includes(needle), `${rel} does not contain "${needle}"`)
}

// --- canonical records -------------------------------------------------------
mentions('VERIFIED.md', `| DeepSeek Harness version | \`${version}\` |`, 'ledger version row')
mentions('VERIFIED.md', `| Upstream tag | \`${tag}\` |`, 'ledger tag row')
mentions('VERIFIED.md', `| Source commit (full) | \`${commit}\` |`, 'ledger full-commit row')
mentions('VERIFIED.md', `${version}`, 'ledger mentions the version')

mentions('README.md', version, 'README version')
mentions('README.md', commit, 'README full commit')
mentions('ROADMAP.md', version, 'ROADMAP version')
mentions('ROADMAP.md', commit, 'ROADMAP full commit')

// The tag format example must use the real values, not a stale pair.
mentions('PLAN.md', `+dsh.${version}.g${commitShort}`, 'PLAN tag example')

// The opt-in packages are installed into a PROFILE, not into the bundle: the bundle
// declares only what its own plugins import. Asserting the distinction keeps a future
// reader from "fixing" the manifest by adding dependencies the kit does not use.
const bundle = JSON.parse(readFileSync(resolve(repo, 'kit-plugins/package.json'), 'utf8'))
const wronglyDeclared = Object.keys(target.pinnedPackages)
  .filter(name => bundle.devDependencies?.[name] !== undefined || bundle.peerDependencies?.[name] !== undefined)
check(
  'opt-in packages are not bundle dependencies',
  wronglyDeclared.length === 0,
  `declared in kit-plugins/package.json: ${wronglyDeclared.join(', ')}`,
)

for (const n of [7, 9]) {
  mentions(`solutions/verify-l${n}.sh`, `DSH_VERSION:-${version}`, `verify-l${n} default version`)
}

// --- live checkout -----------------------------------------------------------
if (checkout) {
  const git = (...args) => execFileSync('git', ['-C', checkout, ...args], { encoding: 'utf8' }).trim()
  try {
    const head = git('rev-parse', 'HEAD')
    check('checkout is at the recorded commit', head === commit, `HEAD is ${head}`)
    try {
      const dirty = git('status', '--porcelain')
      check('checkout tree is clean', dirty === '', `uncommitted: ${dirty.split('\n').slice(0, 3).join(', ')}`)
    } catch { /* status is best-effort */ }
    try {
      const described = git('describe', '--tags', '--always')
      check('checkout tag matches', described === tag, `describe says ${described}`)
    } catch { /* no tags is acceptable */ }
    try {
      const actual = JSON.parse(readFileSync(resolve(checkout, 'package.json'), 'utf8')).version
      check('checkout package version matches', actual === version, `package.json says ${actual}`)
    } catch { /* ignore */ }
  } catch (error) {
    check('checkout is a git repository', false, error.message.split('\n')[0])
  }
} else {
  console.log('(no checkout supplied: version records checked, live state skipped)')
}

if (problems.length === 0) {
  console.log(`harness state records agree with kit.target.json (dsh ${version}, ${commitShort})`)
  process.exit(0)
}

console.error(`${problems.length} harness-state record(s) disagree:\n`)
for (const p of problems) console.error(`  ${p}`)
console.error('\nUpdate kit.target.json and re-verify in the same pass — see PLAN.md Phase 4.5.')
process.exit(1)
