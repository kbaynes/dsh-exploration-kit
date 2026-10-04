#!/usr/bin/env node
/**
 * Reflow hard-wrapped markdown prose into one line per paragraph or list item.
 *
 * Prose in this repository is NOT column-wrapped. A single newline inside a paragraph is a
 * *soft* break: strict renderers (CommonMark, GFM, VitePress) flow it into one paragraph, but
 * anything that shows raw text or honours soft breaks displays a hard-wrapped file as arbitrary
 * mid-sentence breaks. The same source renders differently in different viewers, which is the
 * reason this is a rule rather than a preference (ADR-0031).
 *
 * Conservative by construction. It never touches YAML frontmatter, fenced code, indented code,
 * tables, headings, or HTML lines. It joins a paragraph's wrapped lines, a list item's
 * continuation lines (CommonMark lazy continuation: inside a run with no blank line, every
 * non-marker line belongs to the current item), and consecutive blockquote lines.
 *
 * Usage:
 *   node scripts/reflow-markdown.mjs [files...]          rewrite
 *   node scripts/reflow-markdown.mjs --check [files...]  report only, exit 1 if any file differs
 *
 * With no files it walks the repository, skipping generated and vendored trees.
 */

import { readFileSync, readdirSync, writeFileSync } from 'node:fs'
import { join, relative, resolve } from 'node:path'

const root = resolve(import.meta.dirname, '..')

/** Directories never scanned: generated, vendored, or not published. */
const skipDirs = new Set(['.git', 'node_modules', 'dist', 'cache', '.vitepress'])

const FENCE = /^(\s*)(```+|~~~+)/
const HEADING = /^\s{0,3}#{1,6}\s/
const TABLE = /^\s*\|/
const LIST = /^(\s*)([-*+]|\d+[.)])\s+/
const QUOTE = /^\s*>/
const INDENTED = /^(?: {4,}|\t)/
const BLANK = /^\s*$/

/** Reflow one markdown document. Pure: `reflow(reflow(x)) === reflow(x)`. */
export function reflow(text) {
  const lines = text.split('\n')
  const out = []
  let mode = null // null | 'list' | 'quote' | 'plain'
  let buf = null // the single synthesized line for the current block

  const flush = () => {
    if (buf !== null) out.push(buf)
    mode = null
    buf = null
  }

  let i = 0
  const n = lines.length
  // Frontmatter is emitted verbatim.
  if (n > 0 && lines[0].trim() === '---') {
    let j = 1
    while (j < n && lines[j].trim() !== '---') j += 1
    if (j < n) {
      out.push(...lines.slice(0, j + 1))
      i = j + 1
    }
  }

  while (i < n) {
    const line = lines[i]

    const fence = FENCE.exec(line)
    if (fence !== null) {
      flush()
      const marker = fence[2]
      const close = new RegExp(`^\\s*${marker[0] === '`' ? '`' : '~'}{${marker.length},}\\s*$`)
      let j = i + 1
      while (j < n && !close.test(lines[j])) j += 1
      j = Math.min(j + 1, n)
      out.push(...lines.slice(i, j))
      i = j
      continue
    }

    if (BLANK.test(line)) {
      flush()
      out.push(line)
      i += 1
      continue
    }

    if (HEADING.test(line) || TABLE.test(line) || INDENTED.test(line) || line.trimStart().startsWith('<')) {
      flush()
      out.push(line)
      i += 1
      continue
    }

    if (QUOTE.test(line)) {
      const body = line.replace(/^\s*>\s?/, '').trim()
      if (mode === 'quote') buf = buf + (body === '' ? '' : ` ${body}`)
      else {
        flush()
        mode = 'quote'
        buf = `> ${body}`
      }
      i += 1
      continue
    }

    if (LIST.test(line)) {
      flush()
      mode = 'list'
      buf = line.replace(/\s+$/, '')
      i += 1
      continue
    }

    // Anything else inside a list or quote run is a lazy continuation of it.
    if (mode === 'list' || mode === 'quote') {
      buf = `${buf} ${line.trim()}`
      i += 1
      continue
    }

    if (mode === 'plain') {
      buf = `${buf} ${line.trim()}`
      i += 1
      continue
    }

    mode = 'plain'
    buf = line.trim()
    i += 1
  }

  flush()
  return out.join('\n')
}

function walk(dir) {
  const out = []
  for (const entry of readdirSync(dir, { withFileTypes: true })) {
    if (entry.name.startsWith('.') && entry.name !== '.github') continue
    const full = join(dir, entry.name)
    if (entry.isDirectory()) {
      if (skipDirs.has(entry.name)) continue
      out.push(...walk(full))
    } else if (entry.name.endsWith('.md')) {
      out.push(full)
    }
  }
  return out
}

const args = process.argv.slice(2)
const check = args.includes('--check')
const named = args.filter(arg => !arg.startsWith('--'))
const files = named.length > 0 ? named.map(f => resolve(f)) : walk(root)

let changed = 0
let linesBefore = 0
let linesAfter = 0
for (const file of files) {
  const source = readFileSync(file, 'utf8')
  const formatted = reflow(source)
  linesBefore += source.split('\n').length
  linesAfter += formatted.split('\n').length
  if (source === formatted) continue
  changed += 1
  const where = relative(root, file)
  if (check) {
    const src = source.split('\n')
    const dst = formatted.split('\n')
    const at = src.findIndex((line, index) => line !== dst[index])
    console.error(`${where}:${at + 1}  prose is column-wrapped`)
    console.error(`      ${src[at].trim().slice(0, 100)}`)
    console.error(`      ${(src[at + 1] ?? '').trim().slice(0, 100)}`)
  } else {
    writeFileSync(file, formatted)
    console.log(`reflowed ${where}`)
  }
}

if (check && changed > 0) {
  console.error(`\n${changed} file(s) carry wrapped prose. Prose is one line per paragraph or`)
  console.error('list item so it renders identically in every viewer (ADR-0031). Fix with:')
  console.error('  pnpm run reflow')
  process.exit(1)
}

console.log(check
  ? `no wrapped prose in ${files.length} file(s)`
  : `reflowed ${changed} of ${files.length} file(s); lines ${linesBefore} -> ${linesAfter}`)
