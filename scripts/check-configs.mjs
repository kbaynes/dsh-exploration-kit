#!/usr/bin/env node
/**
 * Validate every machine-read configuration artifact this repository ships.
 *
 * A malformed workflow never runs, and Actions reports nothing — the failure is silence.
 * A malformed kit.target.json breaks the version gate. A malformed okf-base.yaml makes
 * validation quietly weaker. None of these are caught by reading the file.
 *
 * So this checks two things:
 *   1. syntax — JSON and YAML parse
 *   2. structure — the fields each consumer actually reads are present
 *
 * Usage: node scripts/check-configs.mjs
 */

import { readFileSync, readdirSync } from 'node:fs'
import { join, resolve } from 'node:path'
import { parse as parseYaml } from 'yaml'

const repo = resolve(import.meta.dirname, '..')
const problems = []
const checked = []

const readJson = rel => {
  try {
    const value = JSON.parse(readFileSync(resolve(repo, rel), 'utf8'))
    checked.push(`${rel} (json)`)
    return value
  } catch (error) {
    problems.push(`${rel}: not valid JSON — ${error.message}`)
    return null
  }
}

const readYaml = rel => {
  try {
    const value = parseYaml(readFileSync(resolve(repo, rel), 'utf8'))
    checked.push(`${rel} (yaml)`)
    return value
  } catch (error) {
    problems.push(`${rel}: not valid YAML — ${error.message}`)
    return null
  }
}

// --- JSON -------------------------------------------------------------------
const pkg = readJson('package.json')
if (pkg) {
  for (const field of ['name', 'version', 'license', 'packageManager']) {
    if (!pkg[field]) problems.push(`package.json: missing "${field}"`)
  }
  if (!pkg.kit?.repositoryOwner) problems.push('package.json: missing kit.repositoryOwner')
  // The gate and the checks read these by name; renaming one silently disarms them.
  for (const script of ['check:kit', 'check:target', 'check:publication', 'setup']) {
    if (!pkg.scripts?.[script]) problems.push(`package.json: missing script "${script}"`)
  }
}

const target = readJson('kit.target.json')
if (target) {
  for (const field of ['version', 'tag', 'commit', 'commitShort', 'branch', 'capturedOn']) {
    if (!target.dsh?.[field]) problems.push(`kit.target.json: missing dsh.${field}`)
  }
  if (target.dsh?.commit && target.dsh?.commitShort
      && !target.dsh.commit.startsWith(target.dsh.commitShort)) {
    problems.push('kit.target.json: dsh.commitShort is not a prefix of dsh.commit')
  }
  if (!target.profiles?.base || !target.profiles?.web) {
    problems.push('kit.target.json: missing profiles.base / profiles.web')
  }
}

const bundle = readJson('kit-plugins/package.json')
if (bundle) {
  if (!bundle.dsh?.bundle?.patch) {
    problems.push('kit-plugins/package.json: missing dsh.bundle.patch — the bundle would mount nothing')
  }
}

// --- YAML -------------------------------------------------------------------
const okf = readYaml('okf-base.yaml')
if (okf) {
  if (!okf.base?.roots?.length) problems.push('okf-base.yaml: no base.roots — nothing would be validated')
  if (!okf.profile?.types) problems.push('okf-base.yaml: no profile.types')
}

const workflowDir = resolve(repo, '.github/workflows')
for (const file of readdirSync(workflowDir).filter(f => /\.ya?ml$/.test(f))) {
  const rel = `.github/workflows/${file}`
  const workflow = readYaml(rel)
  if (!workflow) continue

  // A workflow with no trigger never runs; one with no jobs does nothing when it does.
  // `on` parses as the boolean true under some YAML 1.1 rules, so accept both spellings.
  const triggers = workflow.on ?? workflow[true]
  if (!triggers) problems.push(`${rel}: no "on:" trigger — the workflow would never run`)
  const jobs = workflow.jobs ?? {}
  if (Object.keys(jobs).length === 0) problems.push(`${rel}: no jobs`)

  for (const [name, job] of Object.entries(jobs)) {
    if (!job['runs-on']) problems.push(`${rel}: job "${name}" has no runs-on`)
    if (!Array.isArray(job.steps) || job.steps.length === 0) {
      problems.push(`${rel}: job "${name}" has no steps`)
      continue
    }
    job.steps.forEach((step, index) => {
      if (!step.uses && !step.run) {
        problems.push(`${rel}: job "${name}" step ${index + 1} has neither "uses" nor "run"`)
      }
    })
  }
}

// The full-verification workflow must verify against the PIN, not a moving branch:
// verifying against main would make its result a statement about a different commit
// than the one the kit claims. See ADR-0020.
const verifyWorkflow = readYaml('.github/workflows/verify-against-dsh.yml')
if (verifyWorkflow) {
  const text = readFileSync(resolve(repo, '.github/workflows/verify-against-dsh.yml'), 'utf8')
  if (!text.includes('steps.pin.outputs.commit')) {
    problems.push('verify-against-dsh.yml: does not check out the harness at the pinned commit')
  }
  if (!text.includes('check:target')) {
    problems.push('verify-against-dsh.yml: does not assert the checkout matches the records')
  }
}

if (problems.length === 0) {
  console.log(`${checked.length} configuration artifact(s) valid: ${checked.length} parsed, structure checked`)
  process.exit(0)
}

console.error(`${problems.length} configuration problem(s):\n`)
for (const p of problems) console.error(`  ${p}`)
process.exit(1)
