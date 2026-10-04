# Update Log

## 2026-09-30
- **Creation**: Repository scaffold established, with the curriculum promoted from
  the author's workspace knowledge bundle to a standalone, publishable project.
- **Creation**: `content/` — the curriculum as an Open Knowledge Format bundle:
  `index.md` (entry point and quickstart), `feature-map.md` (capability inventory),
  `learning-path.md` (ordering rationale and checkpoints), and
  `lessons/01..09` plus `lessons/index.md`.
- **Update**: Rewrote all cross-bundle links for standalone use. Upstream DSH
  references now use absolute `github.com/deepseek-ai/deepseek-harness/blob/main/...`
  URLs; intra-kit links are relative. Adopted `<kit>` as the placeholder for this
  repository's root in all paths.
- **Creation**: `VERIFIED.md` — an honest per-lesson verification ledger, recording
  that only Lesson 1 has been executed end-to-end (against DSH `0.2.0-rc.2`,
  commit `639ed01539`) and listing every documented-but-unrun claim, including the
  placeholder Python snippet in Lesson 9.
- **Creation**: `okf-base.yaml` (bundle manifest declaring the three concept types),
  `README.md`, `AGENTS.md`, `CONTRIBUTING.md`, `LICENSE` (MIT), `THIRD-PARTY.md`
  (attribution and derivation boundaries), and `.gitignore`.
- **Creation**: `website/` — VitePress site rendering `content/` directly, so the
  curriculum has a single source of truth.
- **Note**: `examples/` and `solutions/` are deliberate empty placeholders; the
  reference solutions double as the lesson test suite and are the first item in the
  verification backlog.
