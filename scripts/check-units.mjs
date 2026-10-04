#!/usr/bin/env node
/**
 * Run the kit's pure unit tests, and explain a missing install instead of failing
 * with a bare ERR_MODULE_NOT_FOUND.
 *
 * The bundle has its own dependency root (kit-plugins/), deliberately: its packages are
 * what a profile resolves at runtime, and folding it into the root workspace would
 * change that resolution. The cost is that a fresh clone needs TWO installs, and the
 * failure mode without the second one is an import error that looks like a code bug.
 *
 * Usage: node scripts/check-units.mjs
 */

import { spawnSync } from 'node:child_process'
import { existsSync } from 'node:fs'
import { resolve } from 'node:path'

const repo = resolve(import.meta.dirname, '..')
const plugins = resolve(repo, 'kit-plugins')

if (!existsSync(resolve(plugins, 'node_modules'))) {
  console.error(
    'kit-plugins/node_modules is missing, so the unit tests cannot resolve their imports.\n' +
    'This is a second dependency root, not a code defect. Provision it with:\n\n' +
    '  pnpm run setup            # both installs, fresh clone\n' +
    '  pnpm run install:plugins  # just the bundle\n',
  )
  process.exit(1)
}

const tests = ['l6/fold.test.mjs', 'l8/audit-workflow.test.mjs']
const run = spawnSync('node', ['--test', ...tests], { cwd: plugins, encoding: 'utf8' })
process.stdout.write(run.stdout ?? '')
process.stderr.write(run.stderr ?? '')
process.exit(run.status ?? 1)
