---
type: ADR
title: "ADR-0007 — A plugin Config must be a real Standard Schema"
description: A plugin Config must be a real Standard Schema.
status: Accepted
timestamp: 2026-10-01
---

# ADR-0007 — A plugin Config must be a real Standard Schema

## Status

Accepted

## Context

A hand-rolled object shaped like a schema is not one. This plugin:

```js
export const Config = { parse: value => ({ match: value?.match ?? '' }) }
```

failed at boot with:

```
l3-diagnose (dsh-exploration-kit-plugins/l3/diagnose.js): TypeError: Cannot read properties of undefined (reading 'validate')
```

Cordis validates an entry's `config` with a Standard Schema validator before `apply` runs. An object without a conforming interface is accepted as a plugin contribution and then fails during validation.

## Decision

Declare `Config` with Schemastery (`@deepseek-ai/schemastery`), as `kit-plugins/l2/wordcount.js` and `kit-plugins/l3/diagnose.js` do. Cordis accepts any Standard Schema validator; Schemastery is what the harness itself uses.

## Consequences

- One more declared dependency, already present in every base profile.
- Validation failures happen before `apply`, producing a field-naming error rather than a partial startup — the property the lessons rely on.
- A default belongs in the schema (`Schema.string().default(...)`), not in the plugin body, so `apply` always receives complete config.

## Evidence

[VERIFIED.md](../VERIFIED.md) "Two upstream-tutorial traps found by running it".
