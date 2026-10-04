# Workspace Instructions — DSH Exploration Kit

This repository is a publishable curriculum for learning DeepSeek Harness (`dsh`).
Before answering architecture or plugin questions about DSH, read the capability
map and the relevant lesson rather than reasoning from memory.

## Source of truth

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

- **Path convention:** `<kit>` means this repository's root. Exercise plugins live
  under `<kit>/plugins/`.
- **Upstream references** to DSH's own docs use absolute
  `https://github.com/deepseek-ai/deepseek-harness/blob/main/...` URLs so this repo
  works standalone. Links *within* the kit are relative markdown links.
- **Every lesson has the same shape:** goal → concepts → steps → verification →
  exit check → next. Keep it.
- **Say when a step is unverified.** A lesson that admits uncertainty is more
  useful than one that overstates.

## Validation

```sh
pnpm install           # required once; see README on hoisting
pnpm run check:links   # every relative link inside content/ must resolve
pnpm run validate      # OKF conformance (needs okflint on PATH)
pnpm run build         # the VitePress site must build
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
