#!/usr/bin/env node
/**
 * Run every kit check in one command, with a single summary.
 *
 * The individual checks are intentionally separate — they need different
 * environments — but a contributor should not have to remember nine commands.
 *
 *   Environment-free    always run
 *   Needs a checkout    skipped unless DSH_CHECKOUT / an argument is supplied
 *
 * The per-lesson checks boot `dsh`, which writes its composed profile under
 * `$DSH_HOME` and reads the installed kit bundle there. Run this from a normal
 * shell: under a sandbox that blocks `~/.dsh` writes, those checks fail on a guard
 * message telling you to install the bundle, which is misleading — the bundle is
 * installed, the sandbox is in the way.
 *
 * Usage:
 *   node scripts/check-kit.mjs [path-to-deepseek-harness]
 *   DSH_CHECKOUT=/path/to/deepseek-harness node scripts/check-kit.mjs
 */

import { spawnSync } from 'node:child_process'
import { resolve } from 'node:path'

const root = resolve(import.meta.dirname, '..')
const checkout = process.argv[2] ?? process.env.DSH_CHECKOUT ?? ''

/** Each check: what to run, and what it needs to be meaningful. */
const checks = [
  { name: 'internal links', cmd: ['pnpm', 'run', '-s', 'check:links'] },
  { name: 'decision records', cmd: ['pnpm', 'run', '-s', 'check:decisions'] },
  { name: 'examples mirror', cmd: ['pnpm', 'run', '-s', 'check:examples'] },
  { name: 'unit tests (pure folds)', cmd: ['pnpm', 'run', '-s', 'check:units'] },
  { name: 'OKF conformance', cmd: ['pnpm', 'run', '-s', 'validate'], optional: true },
  { name: 'site build', cmd: ['pnpm', 'run', '-s', 'build'] },
  {
    name: 'upstream DSH links',
    cmd: ['node', 'scripts/check-upstream-links.mjs', checkout],
    needs: 'a DSH checkout (pass one as an argument or set DSH_CHECKOUT)',
    skip: checkout === '',
  },
  ...[2, 3, 4, 5, 7, 8].map(n => ({
    name: `solution: lesson ${n}`,
    cmd: ['bash', `solutions/verify-l${n}.sh`, checkout],
    needs: 'a DSH checkout',
    skip: checkout === '',
  })),
]

const results = []
for (const check of checks) {
  if (check.skip) {
    results.push({ ...check, outcome: 'skip' })
    process.stdout.write(`SKIP  ${check.name} — needs ${check.needs}\n`)
    continue
  }
  const run = spawnSync(check.cmd[0], check.cmd.slice(1), { cwd: root, encoding: 'utf8' })
  const ok = run.status === 0
  const tolerated = check.optional && !ok
  results.push({ ...check, outcome: ok ? 'pass' : tolerated ? 'warn' : 'fail' })
  process.stdout.write(`${ok ? 'PASS' : tolerated ? 'WARN' : 'FAIL'}  ${check.name}\n`)
  if (!ok) {
    const detail = ((process.env.KIT_CHECK_VERBOSE === '1')
      ? (run.stdout + run.stderr).trim()
      : (run.stdout + run.stderr).trim().split('\n').slice(-6).join('\n'))
    if (detail) process.stdout.write(detail.replace(/^/gm, '        ') + '\n')
  }
}

const count = outcome => results.filter(r => r.outcome === outcome).length
console.log(
  `\n${count('pass')} passed, ${count('warn')} warned, ${count('fail')} failed, ${count('skip')} skipped`,
)
if (count('skip') > 0) {
  console.log('Pass a DSH checkout path to include the upstream and per-lesson checks.')
}
process.exit(count('fail') > 0 ? 1 : 0)
