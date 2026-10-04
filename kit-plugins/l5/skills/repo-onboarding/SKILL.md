---
name: repo-onboarding
description: Use when asked to explain how the DSH exploration kit is organized, where its knowledge lives, or how to get started reading it.
---

# Kit onboarding

The DSH Exploration Kit is a nine-lesson curriculum for learning DeepSeek Harness by
building real plugins. Its layout:

- `content/` — the curriculum, an Open Knowledge Format bundle. Start at
  `content/index.md`.
- `content/feature-map.md` — the capability inventory: every DSH feature grouped by
  subsystem, with the package or seam that provides it.
- `content/learning-path.md` — why the lessons are ordered as they are.
- `content/lessons/01..09` — one extension seam per lesson.
- `kit-plugins/` — the bundle every lesson installs; rows are named by package.
- `solutions/` — the answer key plus a verification script per lesson.
- `examples/` — a generated mirror of the lesson plugin files.
- `VERIFIED.md` — exactly which lesson steps have been **executed**, and against
  which DSH version. Never assume a lesson works because it is written down.

When asked about a lesson, read that lesson. When asked what the harness can do,
read `content/feature-map.md`. Do not reason about DSH from memory: the version
matters, and the ledger records which version a claim was checked against.
