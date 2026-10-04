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
import { existsSync, readFileSync, rmSync, writeFileSync } from 'node:fs'
import { homedir, tmpdir } from 'node:os'
import { join, resolve } from 'node:path'

const root = resolve(import.meta.dirname, '..')
const checkout = process.argv[2] ?? process.env.DSH_CHECKOUT ?? ''

/**
 * Refuse to run while another suite already owns the harness home.
 *
 * The per-lesson checks boot `dsh` against ONE `$DSH_HOME` and create sessions in it. Two runs at
 * once — or one run plus a manual `dsh` against the same home — corrupt each other's checks, and
 * the result reads as a flaky lesson rather than as a collision. This was diagnosed twice as a
 * flake before the cause was found (ADR-0030), so it now fails loudly instead.
 *
 * Only taken when a checkout is supplied, because the environment-free checks boot nothing.
 */
const lockDir = process.env.DSH_HOME ?? join(homedir(), '.dsh')
const lockPath = checkout === '' ? undefined : join(lockDir, '.check-kit.lock')

function releaseLock() {
  if (lockPath !== undefined) rmSync(lockPath, { force: true })
}

let lockTaken = false

function takeLock() {
  if (lockPath === undefined || lockTaken) return
  lockTaken = true
  if (existsSync(lockPath)) {
    const holder = readFileSync(lockPath, 'utf8').trim()
    const pid = Number.parseInt(holder, 10)
    // A stale file from a killed run must not block the next one forever.
    //
    // This is a bare pid check, which has one limitation worth naming: pids are reused, so a dead
    // run's number can belong to an unrelated live process and block this one. The alternative —
    // asking the OS for the holder's command line — is not portable in the other direction:
    // `ps` is blocked outright under some sandboxes, where the check would silently decide the
    // lock is stale. A false "held" is visible and the message names the file to remove; a
    // silently ignored lock is not.
    const alive = Number.isInteger(pid) && pid > 0 && (() => {
      try { process.kill(pid, 0); return true } catch { return false }
    })()
    if (alive) {
      console.error(`Another check:kit run (pid ${pid}) is using ${lockDir}.`)
      console.error('Two suites against one harness home corrupt each other\'s sessions, so this')
      console.error('run stops rather than reporting the collision as a lesson failure (ADR-0030).')
      console.error(`If pid ${pid} is not a check:kit run, remove ${lockPath} and retry.`)
      process.exit(2)
    }
    console.error(`WARN  replacing a stale check:kit lock from pid ${holder || 'unknown'} (that process is gone)`)
  }
  writeFileSync(lockPath, `${process.pid}\n`)
  process.on('exit', releaseLock)
  for (const signal of ['SIGINT', 'SIGTERM']) {
    process.on(signal, () => { releaseLock(); process.exit(130) })
  }
}

/** Each check: what to run, and what it needs to be meaningful. */
const checks = [
  {
    name: 'harness-state records',
    cmd: ['node', 'scripts/check-target.mjs', checkout],
  },
  { name: 'configuration artifacts', cmd: ['pnpm', 'run', '-s', 'check:configs'] },
  { name: 'lesson structure', cmd: ['pnpm', 'run', '-s', 'check:lessons'] },
  { name: 'internal links', cmd: ['pnpm', 'run', '-s', 'check:links'] },
  { name: 'markdown prose is not column-wrapped', cmd: ['pnpm', 'run', '-s', 'check:wrapping'] },
  { name: 'synced-document links', cmd: ['pnpm', 'run', '-s', 'check:synced-links'] },
  { name: 'decision records', cmd: ['pnpm', 'run', '-s', 'check:decisions'] },
  { name: 'examples mirror', cmd: ['pnpm', 'run', '-s', 'check:examples'] },
  { name: 'unit tests (pure folds)', cmd: ['pnpm', 'run', '-s', 'check:units'] },
  { name: 'OKF conformance', cmd: ['pnpm', 'run', '-s', 'validate'], optional: true },
  { name: 'site build', cmd: ['pnpm', 'run', '-s', 'build'] },
  {
    name: 'GitHub links resolve on the right branch',
    cmd: ['node', 'scripts/check-upstream-links.mjs', checkout],
    needs: 'a DSH checkout (pass one as an argument or set DSH_CHECKOUT)',
    skip: checkout === '',
  },
  ...[2, 3, 4, 5, 6, 7, 8, 9].map(n => ({
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
  takeLock()
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
releaseLock()
process.exit(count('fail') > 0 ? 1 : 0)
