#!/usr/bin/env node
/**
 * Copy the canonical lesson plugin files into examples/.
 *
 * `examples/` holds the exact files each lesson presents, so a reader can copy
 * rather than transcribe. The canonical copies live in `kit-plugins/` — that is
 * what actually boots — so this script mirrors them and `--check` fails when the
 * mirror drifts.
 *
 * Usage:
 *   node scripts/sync-examples.mjs          # write the mirror
 *   node scripts/sync-examples.mjs --check  # fail if it has drifted
 */

import { readFileSync, writeFileSync, mkdirSync, readdirSync, existsSync } from 'node:fs'
import { join, resolve, relative, dirname } from 'node:path'

const root = resolve(import.meta.dirname, '..')
const source = join(root, 'kit-plugins')
const target = join(root, 'examples')
const check = process.argv.includes('--check')

/** Lesson plugin files, by path relative to kit-plugins/. */
function pluginFiles(dir) {
  const out = []
  for (const entry of readdirSync(dir, { withFileTypes: true })) {
    if (entry.name === 'node_modules') continue
    const full = join(dir, entry.name)
    if (entry.isDirectory()) out.push(...pluginFiles(full))
    else if (/\.(js|ts)$/.test(entry.name) || entry.name === 'cordis.patch.yml') out.push(full)
  }
  return out
}

let written = 0
const drifted = []

for (const file of pluginFiles(source)) {
  const rel = relative(source, file)
  const dest = join(target, rel)
  const body = readFileSync(file)
  if (check) {
    if (!existsSync(dest) || !readFileSync(dest).equals(body)) drifted.push(rel)
    continue
  }
  mkdirSync(dirname(dest), { recursive: true })
  writeFileSync(dest, body)
  written += 1
}

if (check) {
  if (drifted.length > 0) {
    console.error(`${drifted.length} example file(s) drifted from kit-plugins/:`)
    for (const d of drifted) console.error(`  examples/${d}`)
    console.error('\nRun: node scripts/sync-examples.mjs')
    process.exit(1)
  }
  console.log('examples/ matches kit-plugins/')
} else {
  console.log(`synced ${written} file(s) into examples/`)
}
