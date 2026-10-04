---
type: ADR
title: "ADR-0031 — Prose is one line per paragraph, so every viewer renders it the same"
description: Prose is one line per paragraph, so every viewer renders it the same.
status: Accepted
timestamp: 2026-10-03
---

# ADR-0031 — Prose is one line per paragraph, so every viewer renders it the same

## Status

Accepted

## Context

Every markdown file in this repository was authored with prose hard-wrapped at roughly 90 columns. A reader reported that the files "appear to have weird hardcoded carriage returns that look wrong when rendered visually". The report was worth taking literally, so it was checked rather than assumed:

- **There are no carriage returns.** Every file is UTF-8 with LF endings. `grep -rlU $'\r' --include=*.md` finds nothing, and `file` reports "UTF-8 text" without the "with CRLF line terminators" suffix.
- **There are no hard breaks.** A hard break in markdown needs a line ending in two spaces or a backslash; there are none.
- **This repository's own site renders the wraps as spaces.** The built HTML was checked against a specific wrapped paragraph, and the newline came out as a single space. The dozens of `<br>` tags per page come from the code-block line-number gutter (`markdown: { lineNumbers: true }`), not from prose.

So the defect is not in the bytes and not in this repository's renderer. It is in the *soft break*: a single newline inside a paragraph is a soft break, and while CommonMark, GFM and VitePress flow it into one paragraph, a great many things a reader actually uses do not — editors' text previews, note applications, chat and issue pastes, and any markdown renderer configured with `breaks: true`. The same source therefore looks like a correctly-flowed paragraph in one place and like arbitrary mid-sentence breaks in another.

That is a property of the format, not a preference about source width, which is what makes it a decision rather than a style note.

## Decision

**Prose is one line per paragraph or list item.** A paragraph ends at a blank line, never at a column.

`scripts/reflow-markdown.mjs` is both the formatter and the check:

- `pnpm run reflow` rewrites files.
- `pnpm run check:wrapping` reports any file that is not already in canonical form, and is part of `pnpm run check:kit`.

The check is the formatter's fixed point — `reflow(reflow(x)) === reflow(x)` — so there is exactly one canonical form and no judgement is needed to decide whether a file passes.

What the reflow never touches: YAML frontmatter, fenced code, indented code, tables, headings, and HTML lines. What it joins: a paragraph's wrapped lines, a list item's continuation lines, and consecutive blockquote lines. List continuations follow CommonMark's lazy continuation rule — inside a run with no blank line, every line that is not a new marker belongs to the current item — rather than requiring indentation, because that is how the content already behaved when rendered.

## Consequences

- A lesson renders identically in VitePress, on GitHub, in an editor preview, and pasted into a chat. That is the whole point, and it is what the reader asked for.
- Source lines are now long. This is a real cost for authors and for line-oriented diff review: a paragraph edited anywhere shows up as one changed line. Word-diff or the rendered page is the tool for reviewing prose changes, and the commit that applied this is a single mechanical change for exactly that reason.
- The rule is enforced rather than requested, so a future edit cannot quietly reintroduce viewer-dependent rendering. This session's own earlier edits would have failed it.
- The reflow is not a reformat-with-consequences: it changes only whitespace *between* lines. Verified on the full corpus before applying: 286 fenced code blocks, 427 table rows, 46 frontmatter blocks and 362 link targets were byte-identical afterwards, and `check:links`, `check:decisions`, `check:lessons`, `check:examples`, `check:synced-links`, OKF validation and the site build all pass.

## Evidence

The reported symptom, and what the bytes actually contain:

```
$ grep -rlU $'\r' --include=*.md . | wc -l
       0
$ head -c 120 README.md | od -c | head -2
0000000    #       D   S   H       E   x   p   l   o   r   a   t   i   o
0000020    n       K   i   t  \n  \n   A       h   a   n   d   s   -   o
```

The reflow over the whole corpus:

```
files=63 lines 9532 -> 7426
code blocks : 286 -> 286 identical: True
table rows  : 427 -> 427 identical: True
frontmatter : 46 -> 46 identical: True
links       : 362 -> 362 identical: True
```

And the gate that keeps it:

```
$ pnpm run check:wrapping
no wrapped prose in 63 file(s)
```
