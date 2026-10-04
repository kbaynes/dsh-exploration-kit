## What this changes

<!-- One or two sentences. If it fixes an issue, write "Fixes #123". -->

## Type of change

- [ ] Lesson content fix (correction to steps, code, or claims)
- [ ] Lesson clarity improvement
- [ ] New lesson
- [ ] Verification (ran a lesson and updated `VERIFIED.md`)
- [ ] Tooling, site, or repository change

## Verification

<!-- This section is the reason the repository exists. Please be specific. -->

- [ ] I ran the affected lesson steps and they behaved as described
- [ ] I updated `VERIFIED.md` for any lesson whose status changed
- [ ] I did **not** mark anything verified that I did not run

Commands and observed results:

```
<!-- paste the commands you ran and what you saw -->
```

## Checklist

- [ ] `pnpm run check:links` passes
- [ ] `pnpm run build` passes
- [ ] Internal links are relative; upstream DSH links are absolute GitHub URLs
- [ ] New or changed code samples are runnable as written
- [ ] `content/` changes keep the OKF frontmatter (`type`, `title`, `description`)
- [ ] `ROADMAP.md` / `PLAN.md` checkboxes updated if this closes planned work
- [ ] Any newly derived upstream material is recorded in `THIRD-PARTY.md`
