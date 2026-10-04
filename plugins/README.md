# Scratch space

Your own experiments, not the lessons.

**The lesson exercise plugins do not live here.** They live in [`../kit-plugins/`](../kit-plugins/README.md), because a plugin that imports anything from dsh must be part of an **installed bundle** — a loose file reached by a `--patch` overlay cannot resolve `@deepseek-ai/*`, and the entry fails to activate. Lesson 1 step 2 walks through why, and [ADR-0003](../decisions/0003-plugins-ship-as-a-bundle.md) records it.

So use this directory for what it is good at:

- **A plugin that imports nothing from dsh.** That is the one case where a loose file works, and it is a fast way to try something. Lesson 1's `hello.ts` is exactly this shape, and it is the reason that one lesson can be a `.ts` file ([ADR-0011](../decisions/0011-typescript-erasure-limits.md)).
- **Notes, half-finished ideas, and throwaway overlays** while you work through a lesson.

## Mounting a scratch plugin

A row in an overlay resolves its `name` **relative to the patch file**, so `./hello.ts` points beside the overlay, not at the repository root:

```yaml
# plugins/scratch.patch.yml
- insert:
    - id: scratch
      name: './hello.ts'
```

```sh
dsh --profile kitdemo --patch <kit>/plugins/scratch.patch.yml --port 0 --no-open
```

Two traps, both from Lesson 1:

- A bare `- id: <new-id>` entry is a *patch* of an existing row. For a new row it fails quietly with `patch: entry "<id>" not found` and the plugin never mounts.
- Getting the relative path wrong produces a doubled path (`plugins/plugins/hello.ts`) rather than an error you would recognise.

Anything beyond a scratch experiment belongs in the bundle. This directory is git-ignored apart from this file.
