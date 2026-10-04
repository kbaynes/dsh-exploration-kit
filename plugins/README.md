# Exercise plugins

Build your lesson exercise plugins here, under `<kit>/plugins/`.

Each lesson names the exact files to create, for example:

```
plugins/
  l1/
    hello.ts
  l1.patch.yml
  l2/
    wordcount.ts
  l2.patch.yml
```

The `.patch.yml` overlays are passed to the harness with `--patch`, so a lesson's
command looks like:

```sh
cd <path/to/deepseek-harness>
dsh --profile web --patch <kit>/plugins/l1.patch.yml --port 0 --no-open
```

Two footguns, both documented in [Lesson 1](../content/lessons/01-plugin-lifecycle.md):

- New plugin rows go under `- insert:`. A bare `- id: <new-id>` fails with
  `patch: entry "<id>" not found`.
- An entry's `name` is resolved **relative to the patch file**, not to the
  workspace root.

The [examples/](../examples/) directory holds the exact files as each lesson
presents them, and [solutions/](../solutions/) holds a working answer key for
diffing when you get stuck.

This directory is git-ignored except for this README, because it is your working
scratch space.
