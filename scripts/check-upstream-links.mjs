#!/usr/bin/env node
/**
 * Validate every GitHub link against the branch that repository actually uses.
 *
 * The curriculum links to DeepSeek Harness documentation by absolute GitHub URL so the kit works
 * standalone. That makes the links unverifiable by the normal link checker, which deliberately does
 * not fetch external URLs, and it is easy to invent a plausible path — `docs/harness/plugins.md`
 * reads perfectly but does not exist upstream. It is just as easy to invent a plausible *branch*,
 * and that is not a typo a reader can work around: every link 404s.
 *
 * Both halves are checked here:
 *
 *   - the BRANCH each link names is compared with the branch that repository actually uses, read
 *     from git rather than hardcoded (ADR-0033);
 *   - the PATH of every `blob/` or `tree/` link is resolved inside that repository's checkout.
 *
 * Usage:
 *   node scripts/check-upstream-links.mjs /path/to/deepseek-harness
 *   DSH_CHECKOUT=/path/to/deepseek-harness node scripts/check-upstream-links.mjs
 *
 * Exit codes: 0 = every link resolves on the right branch, 1 = dead or mismatched links,
 * 2 = no checkout.
 */

import { execFileSync } from 'node:child_process'
import { existsSync, readFileSync, readdirSync } from 'node:fs'
import { join, relative, resolve } from 'node:path'

const root = resolve(import.meta.dirname, '..')
const checkout = process.argv[2] ?? process.env.DSH_CHECKOUT ?? ''
if (!checkout || !existsSync(checkout)) {
  console.error(
    'No DSH checkout found.\n' +
    'Pass one as an argument or set DSH_CHECKOUT:\n' +
    '  node scripts/check-upstream-links.mjs /path/to/deepseek-harness',
  )
  process.exit(2)
}

/**
 * The pinned harness state — the single source of truth for which DSH commit and branch this kit
 * was verified against (ADR-0017). Its `dsh.branch` had no gate at all until this check: it was
 * recorded as "master" while 42 links in the kit said "main", and nothing noticed.
 */
const target = JSON.parse(readFileSync(join(root, 'kit.target.json'), 'utf8'))
const pinnedBranch = target?.dsh?.branch ?? ''

/** The repositories whose links this kit owns, and where their files live locally. */
const repositories = [
  { owner: 'deepseek-ai', name: 'deepseek-harness', cwd: checkout, paths: checkout, pinned: pinnedBranch },
  { owner: 'kbaynes', name: 'dsh-exploration-kit', cwd: root, paths: root, pinned: '' },
]

/** Directories never scanned: generated, vendored, or not published. */
const skipDirs = new Set(['.git', 'node_modules', 'dist', 'cache', '.vitepress'])

function git(args, cwd) {
  try {
    // stderr is dropped: a repository with no `origin/HEAD` is a normal fallback case, not an
    // error worth printing over the check's own output.
    return execFileSync('git', args, { cwd, encoding: 'utf8', stdio: ['ignore', 'pipe', 'ignore'] }).trim()
  } catch {
    return ''
  }
}

/** The branch a repository actually uses, read from git rather than assumed. */
function defaultBranch(cwd) {
  const remoteHead = git(['symbolic-ref', '--short', 'refs/remotes/origin/HEAD'], cwd)
  if (remoteHead) return remoteHead.replace(/^origin\//, '')
  const head = git(['rev-parse', '--abbrev-ref', 'HEAD'], cwd)
  return head === 'HEAD' ? '' : head
}

for (const repository of repositories) {
  repository.checkoutBranch = defaultBranch(repository.cwd)
  // A pinned branch is the expectation; the checkout only has to agree with it.
  repository.branch = repository.pinned || repository.checkoutBranch
}

function markdownFiles(dir) {
  const out = []
  for (const entry of readdirSync(dir, { withFileTypes: true })) {
    if (entry.name.startsWith('.') && entry.name !== '.github') continue
    const full = join(dir, entry.name)
    if (entry.isDirectory()) {
      if (skipDirs.has(entry.name)) continue
      out.push(...markdownFiles(full))
    } else if (entry.name.endsWith('.md')) {
      out.push(full)
    }
  }
  return out
}

/** `https://github.com/<owner>/<repo>/(blob|tree)/<branch>/<path>` */
const LINK = /https:\/\/github\.com\/([A-Za-z0-9_.-]+)\/([A-Za-z0-9_.-]+)\/(blob|tree)\/([^/)\s#]+)\/([^)\s#]*)/g

const links = new Map()
const unknown = new Map()
const patterns = []

for (const file of markdownFiles(root)) {
  const text = readFileSync(file, 'utf8')
  // Generated site pages are copies of root docs; check the root originals only.
  if (text.includes('GENERATED FILE')) continue
  // Fenced code is scanned too: a lesson that shows a reader a real URL must show a working one.
  text.split('\n').forEach((line, index) => {
    for (const match of line.matchAll(LINK)) {
      const [, owner, name, kind, branch] = match
      const repository = repositories.find(r => r.owner === owner && r.name === name)
      const site = `${relative(root, file)}:${index + 1}`
      // Sentence punctuation and closing quotes are not part of a URL, and prose legitimately ends
      // one with a period or wraps one in quotes.
      const path = match[5].replace(/[.,;:!?'"`]+$/, '')
      // `.../blob/master/...` is how the conventions describe the URL FORM, and a URL quoted as a
      // constant can end right after the branch. Neither names a real path.
      if (path === '' || path.includes('...')) {
        patterns.push(`${relative(root, file)}:${index + 1}`)
        continue
      }
      if (repository === undefined) {
        unknown.set(`${owner}/${name}`, (unknown.get(`${owner}/${name}`) ?? 0) + 1)
        continue
      }
      const key = `${owner}/${name}/${kind}/${branch}/${path}`
      if (!links.has(key)) links.set(key, { repository, kind, branch, path, sites: [] })
      links.get(key).sites.push(site)
    }
  })
}

const problems = { branch: [], path: [] }
for (const link of links.values()) {
  const { repository, branch, path } = link
  if (repository.branch !== '' && branch !== repository.branch) problems.branch.push(link)
  else if (!existsSync(join(repository.paths, path))) problems.path.push(link)
}

const branchless = repositories.filter(r => r.branch === '').map(r => `${r.owner}/${r.name}`)

// The pin and the checkout must agree, or one of them is stale and every link is suspect.
const stalePins = repositories.filter(r =>
  r.pinned !== '' && r.checkoutBranch !== '' && r.pinned !== r.checkoutBranch)

console.log(`checked ${links.size} distinct GitHub link(s)`)
for (const repository of repositories) {
  const pin = repository.pinned === '' ? '' : ` (pinned; checkout has "${repository.checkoutBranch || 'unknown'}")`
  console.log(`  ${repository.owner}/${repository.name} uses branch "${repository.branch || '(unknown)'}"${pin}`)
}
if (unknown.size > 0) {
  console.log(`  ignored: ${[...unknown.keys()].join(', ')} (not this kit's repositories)`)
}
if (patterns.length > 0) {
  console.log(`  ignored ${patterns.length} documented URL form(s) that name no real path`)
}

if (stalePins.length > 0) {
  console.error('\nThe pinned branch and the checkout disagree — one of them is stale:\n')
  for (const repository of stalePins) {
    console.error(`  ${repository.owner}/${repository.name}: kit.target.json says "${repository.pinned}", the checkout is on "${repository.checkoutBranch}"`)
  }
  console.error('\nUpdate kit.target.json and re-verify in the same pass (ADR-0014).')
  process.exit(1)
}

if (problems.branch.length === 0 && problems.path.length === 0) {
  console.log('every link resolves, and every link names the branch its repository uses')
  process.exit(0)
}

if (branchless.length > 0) {
  console.error(`\nWARN  could not read a branch for ${branchless.join(', ')}; branch not verified.`)
}

if (problems.branch.length > 0) {
  console.error(`\n${problems.branch.length} link(s) name the WRONG BRANCH — every one 404s:\n`)
  for (const { repository, branch, kind, path, sites } of problems.branch.sort((a, b) => a.path.localeCompare(b.path))) {
    console.error(`  ${repository.owner}/${repository.name}/${kind}/${branch}/${path}`)
    console.error(`      should be "${repository.branch}", not "${branch}"`)
    for (const site of sites) console.error(`      ${site}`)
  }
}

if (problems.path.length > 0) {
  console.error(`\n${problems.path.length} link(s) point at paths that do not exist:\n`)
  for (const { repository, kind, branch, path, sites } of problems.path.sort((a, b) => a.path.localeCompare(b.path))) {
    console.error(`  ${repository.name}/${kind}/${branch}/${path}`)
    for (const site of sites) console.error(`      ${site}`)
  }
  console.error('\nFix the URL to a path that exists, or reword to avoid the link.')
}

process.exit(1)
