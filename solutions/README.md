# Solutions

The working answer key: the complete, corrected form of each lesson's exercise,
for diffing when you get stuck.

Unlike [`../examples/`](../examples/README.md) — which mirrors exactly what a lesson
prints on the page — these files are the finished article. If a lesson shows a
fragment ("now add this to `apply`"), the solution here carries the whole file.

## Status

**Empty for now.** Populating this directory is the first item in
[VERIFIED.md](../VERIFIED.md)'s verification backlog, because building the
reference solutions is also how each lesson gets tested.

Until then, work from the lesson text into [`../plugins/`](../plugins/README.md).
Struggling here is productive: the harness fails loudly and the error messages
name the problem, which is the skill the curriculum is trying to build.

## Planned layout

```
solutions/
  l1/hello.ts
  l1.patch.yml
  l2/wordcount.ts
  l2.patch.yml
  l3/clock.ts
  l3/uses-clock.ts
  l3/diagnose.ts
  l3.patch.yml
  ...
```

Each `README.md` added alongside a lesson's solution should record what was run
and against which DSH version — the same rule as the rest of the repository: never
claim verification you did not perform.
