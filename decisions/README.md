# Decision records (ADRs)

The durable engineering decisions behind this kit, each one **earned by getting it
wrong first**. They exist so nobody — human or agent — pays for the same mistake
twice.

## Why these are separate from the other records

| Record | Answers | Lives in |
|---|---|---|
| Verification ledger | *What has actually been executed?* | [VERIFIED.md](../VERIFIED.md) |
| Task plan | *What is left to do?* | [PLAN.md](../PLAN.md) |
| These ADRs | *Why is it built this way, and what should I not try?* | `decisions/` |

An ADR is not a task and not a test result. It states a decision, the evidence that
forced it, and the consequences — including the alternatives that were rejected. A
future contributor should be able to read one and stop before making the mistake,
without re-running the experiment.

## Rules

1. **Every ADR has: Status, Context, Decision, Consequences, Evidence.** Evidence
   is what was observed, quoted. If a decision was not verified, say so in the ADR
   rather than implying certainty.
2. **Numbers are permanent.** Never renumber. Superseded records stay and get
   `Status: Superseded by ADR-00NN`.
3. **Add `decisions/README.md` to the index** when you add a record — enforced by
   `pnpm run check:decisions`.
4. **No decision without a reason.** If you cannot state what would go wrong
   without it, it is a preference, not a decision.

## Index

- [ADR-0001 — Verify a mechanism by running it before teaching it](0001-verify-by-running.md)
- [ADR-0002 — Never cite upstream documentation paths without checking them](0002-verify-upstream-links.md)
- [ADR-0003 — Lesson plugins ship as a dsh bundle, addressed by package name](0003-plugins-ship-as-a-bundle.md)
- [ADR-0004 — Install the bundle with `link:`, never `file:`](0004-link-not-file-install.md)
- [ADR-0005 — Keep lesson plugins dependency-free at runtime](0005-plain-js-no-external-deps.md)
- [ADR-0006 — `FiberState` is a const enum and must not be imported at runtime](0006-fiberstate-is-erased.md)
- [ADR-0007 — A plugin `Config` must be a real Standard Schema](0007-config-needs-a-real-schema.md)
- [ADR-0008 — Declare every context service with `inject`](0008-declare-injected-services.md)
- [ADR-0009 — Environment-specific paths come from configuration at load time](0009-config-time-paths.md)
- [ADR-0010 — Separate what a boot proves from what a session proves](0010-separate-what-a-boot-proves.md)
- [ADR-0011 — Load `.ts` lesson plugins only for type-only imports](0011-typescript-erasure-limits.md)
- [ADR-0012 — The curriculum, the bundle, and examples are one source of truth](0012-single-source-of-truth.md)
- [ADR-0013 — Pin optional DSH package versions; npm's `latest` tag is stale](0013-pin-optional-package-versions.md)
- [ADR-0014 — Tag each release to the DeepSeek Harness commit it was verified against](0014-tag-releases-to-a-harness-commit.md)
