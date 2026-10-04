# Workspace Instructions — DSH Exploration Kit

This repository is a publishable curriculum for learning DeepSeek Harness (`dsh`).
Before answering architecture or plugin questions about DSH, read the capability
map and the relevant lesson rather than reasoning from memory.

## Read the decision records first

**[decisions/](decisions/README.md) holds the engineering decisions behind this
repository, and each one exists because someone already got it wrong.** Before you
change a plugin, a config row, an install instruction, or a lesson mechanism, read
the relevant ADR. They are short, and they are the difference between building on
this project and repeating its mistakes.

Highest-value starting points:

- [ADR-0003 — Lesson plugins ship as a dsh bundle](decisions/0003-plugins-ship-as-a-bundle.md):
  a plugin that imports dsh packages **cannot** be loaded from a loose file by a
  `--patch` overlay. This invalidated the kit's original design.
- [ADR-0004 — Install with `link:`, never `file:`](decisions/0004-link-not-file-install.md):
  `file:` copies, so the reader's edits silently do nothing.
- [ADR-0001 — Verify by running before teaching](decisions/0001-verify-by-running.md):
  the rule that caught the two above.
- [ADR-0002 — Never cite upstream paths unchecked](decisions/0002-verify-upstream-links.md):
  a workspace knowledge bundle's paths are not the upstream repository's paths.

**Verify that an edit applied — including that the old text is gone.** A search-and-replace
that does not match is a no-op, and reporting it as success is how a ledger row stayed wrong
for two rounds: L7's row still claimed a turn was "searchable by its own assistant text"
after that claim had been disproved, because the correction's anchor never matched and the
failed assertion was misread. Assert both directions where it matters — in a script,
`assert old in text` before replacing *and* `assert new in text and old not in text`
afterwards; when editing by hand, re-read the line.

**Add an ADR when you learn something a future contributor could re-learn the hard
way** — a mechanism that does not work, a tool that behaves differently than
documented, a design constraint that is not obvious. One decision, with the evidence
that forced it. `pnpm run check:decisions` enforces the format and the index.

## Source of truth

- **[PLAN.md](PLAN.md)** is the working plan — detailed, checkbox-driven, covering
  build, test, review, publication, and promotion. **Pick work from it and tick
  items as they complete.** [ROADMAP.md](ROADMAP.md) is the at-a-glance status view
  and must be kept in sync.
- **[content/](content/)** is the curriculum — an Open Knowledge Format (OKF) bundle.
  Every `.md` file there is a concept with YAML frontmatter. Do not put
  non-concept files inside `content/`; OKF reserved filenames are `index.md` and
  `log.md` only.
- **[content/index.md](content/index.md)** is the bundle entry point and points at
  the learning path, the capability map, and the lessons.
- **[content/feature-map.md](content/feature-map.md)** is the canonical capability
  inventory. If you add or correct a capability row, update the lesson that
  exercises it.
- **[content/learning-path.md](content/learning-path.md)** owns the lesson ordering
  and the rationale. Reordering lessons means updating it.
- **[VERIFIED.md](VERIFIED.md)** records which lesson steps have actually been
  executed against which DSH version. **Never mark a step verified unless it was
  run.** Presenting an unrun step as verified is the most damaging error this repo
  can make.

## Conventions

- **Path convention:** `<kit>` means this repository's root. The lesson exercise
  plugins live in the bundle at `<kit>/kit-plugins/`; `<kit>/plugins/` is the
  learner's own scratch space.
- **Plugins ship as a bundle, never as loose files reached by a `--patch`
  overlay.** A row in an overlay resolves relative to the patch file, and a loose
  source file cannot import `@deepseek-ai/*` (pnpm symlinks only declared
  dependencies), so the entry fails to activate. Rows are named by package and
  installed with `dsh plugin ... add link:<kit>/kit-plugins`. Evidence is in
  `VERIFIED.md` under "Design pivot".
- **Upstream references** to DSH's own docs use absolute
  `https://github.com/deepseek-ai/deepseek-harness/blob/main/...` URLs so this repo
  works standalone. Links *within* the kit are relative markdown links.
- **Every lesson has the same shape:** goal → concepts → steps → verification →
  exit check → next. Keep it.
- **Say when a step is unverified.** A lesson that admits uncertainty is more
  useful than one that overstates.

## Running verification from an agent

If your file policy confines writes to the session workspace (the common case for an
agent driving this repository), the lesson verification scripts cannot write to the real
harness home under `~/.dsh` — they would need an approval on every boot. Do not relax the
sandbox. Point the harness home somewhere sandbox-writable instead:

```sh
export DSH_HOME=/tmp/dsh-verify     # /tmp is writable under workspace-write (ADR-0023)
bash scripts/setup-verify-profiles.sh
DSH_CHECKOUT=/path/to/deepseek-harness pnpm run check:kit
```

This is the **agent-side** convention and nothing more. A human learner working through
the lessons in their own terminal has no sandbox, uses the default `~/.dsh`, and does not
need this — do not add it to the lessons themselves.

Two hygiene rules that come with it:

- **Never create probe/test sessions or throwaway profiles in a real harness home.**
  If you run against the real home (as earlier rounds of this project did), remove what you
  created afterwards — a session containing an invented event type (ADR-0024) poisons
  full-text search for that whole home, and a leftover profile is confusing.
- The `/tmp` home is disposable by design: profiles and sessions there are recreatable with
  one command and lose nothing.

## Validation

```sh
pnpm run setup           # both dependency roots; see README
pnpm run check:links      # every relative link inside content/ must resolve
pnpm run check:decisions  # ADRs are well-formed and indexed
pnpm run validate         # OKF conformance (needs okflint on PATH)
pnpm run build            # the VitePress site must build
```

`okf-base.yaml` declares the OKF types and required fields for this bundle, with
`content/` as its root — run `pnpm run validate` from the repository root.
Internal links must resolve; upstream links are external and permitted.

**Markdown gotcha:** VitePress compiles the content with Vue, so a bare
`<placeholder>` in prose is parsed as an unclosed HTML tag and fails the build
with `Element is missing end tag`. Always write placeholders as inline code —
`` `<kit>` `` — which also renders them literally. Code fences are exempt.


## Licensing

Content is MIT. DeepSeek Harness material is DeepSeek AI's MIT-licensed work;
this repository is an independent, unofficial resource. Keep the disclaimer in
`README.md` and `content/index.md` accurate, and add anything newly derived from
DSH docs to `THIRD-PARTY.md`.
