---
type: ADR
title: "ADR-0025 — plugin_manager manages profile rows and bundles, not rows a bundle contributes"
description: plugin_manager manages profile rows and bundles, not rows a bundle contributes.
status: Accepted
timestamp: 2026-10-02
---

# ADR-0025 — plugin_manager manages profile rows and bundles, not rows a bundle contributes

## Status

Accepted

## Context

Lesson 3 told the reader to disable a row from the `plugin_manager` tool and watch the consumer disappear. The instruction cannot work for that lesson's rows, and running it showed why:

```
[l3-probe] initial: 115 row(s) total; l3 rows:
[l3-probe] disabled l3-uses-clock: {"application":"failed","error":{"code":"unkno…
[l3-probe] bundles: 11 total; kit bundle present: true
[l3-probe] ids containing "l3-uses-clock": (none)
```

In a composition whose plugin list reports **115 rows**, none of the kit's rows (`l1-hello`, `l2-wordcount`, `l3-clock`, `l3-uses-clock`) appears — while the kit's *bundle* is listed among the 11 bundles, and `set_plugin` on one of those ids returns `application: "failed"` with an unknown-target error. The service behind the tool, `ctx.pluginManager`, behaves identically.

This is the same layer boundary the install instructions depend on ([ADR-0003](0003-plugins-ship-as-a-bundle.md)): plugin **rows** live in a bundle, and a profile composes **bundles**. `plugin_manager` operates on the profile's own rows and on whole bundles, so a bundle-contributed row is not addressable through it.

## Decision

The lesson states the distinction, and the reverse experiment it asks for uses a mechanism that works at the row's own layer:

- to toggle a **bundle-contributed row**, edit `disabled` in the bundle's patch (the same hand-edit Lesson 3 step 2 already teaches), or disable the whole bundle with `set_bundle`;
- `plugin_manager` remains the right tool for the **profile's own rows** and for bundles;
- the **plugin inventory UI** and the Cordis inspection tools read the Loader tree, so they *do* show bundle-contributed rows — which is why "inspect the tree" and "manage the tree" are not the same capability.

`solutions/verify-l3.sh` asserts the four observations above, so the boundary is checked rather than remembered.

## Consequences

- A reader following the original instruction would have concluded the tool was broken, or that their plugin had not loaded. Both are demoralising and neither is true.
- "Which layer owns this row?" is now a question the lessons answer before asking the reader to change anything.
- The toolkit's own probes are unaffected: they test rows where the rows actually live.

## Evidence

[VERIFIED.md](../VERIFIED.md) "Evidence: L3" records the four lines, and `solutions/verify-l3.sh` asserts them.
