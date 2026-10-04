---
type: ADR
title: "ADR-0004 — Install the bundle with link:, never file:"
description: Install the bundle with link:, never file:.
status: Accepted
timestamp: 2026-10-01
---

# ADR-0004 — Install the bundle with link:, never file:

## Status

Accepted

## Context

`dsh plugin add file:<path>` **copies** the package into the profile. A row added to the kit minutes later did not compose until reinstall:

```
$ dsh --profile kitdemo --dump-config | grep -A8 dsh-exploration-kit-plugins
# == dsh-exploration-kit-plugins
- id: l2-wordcount            # the l1-hello row added earlier is absent
```

Every lesson asks the reader to edit a plugin file and observe the change. A copying install silently defeats that, and the symptom — "my edit did nothing" — looks like a mistake the reader made.

## Decision

All install instructions use `dsh plugin ... add link:<path>`, which symlinks the package so edits compose live.

## Consequences

- Editing a plugin file while the profile runs takes effect immediately, which is what makes the Lesson 3 hot-reload exercise possible at all.
- A `link:` install depends on the kit path staying valid; moving the checkout breaks the profile until the bundle is re-added.
- A `file:` install remains correct for reproducible, frozen deployments. It is simply wrong for a curriculum.

## Evidence

[VERIFIED.md](../VERIFIED.md) the section "link: is required while editing, file: is not enough" quotes the missing row and the resulting symlink.
