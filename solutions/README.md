# Solutions and verification

Two things live here: the **overlays** each lesson applies, and a **verification script
per lesson**.

## Verification scripts

```sh
bash solutions/verify-l2.sh <path/to/deepseek-harness>
```

Each script checks the wiring a lesson depends on — that the bundle carries the right
rows, that a plugin declares the services it uses, that an overlay composes the way the
lesson says — and prints `PASS`/`FAIL` per assertion. They need a DSH checkout and a
provisioned profile:

```sh
bash scripts/install-dsh-shim.sh <path/to/deepseek-harness> /tmp/dsh-bin
PATH=/tmp/dsh-bin:$PATH bash scripts/setup-verify-profiles.sh
```

`pnpm run check:kit` runs all of them when `DSH_CHECKOUT` is set, and the
`verify against dsh` workflow runs them in CI against the pinned commit.

**Boots end when the work is done, not after a fixed sleep.** `lib.sh` provides
`boot_and_wait`, which polls the boot log for the probe's own `[<lesson>-probe] done` line
and stops there. A fixed wait has to suit the slowest machine and wastes time on the fastest,
and when it is too short the failure is *silent*: a boot killed early leaves an empty log, and
a check asserting on a pattern's **absence** still passes. Polling removed both problems —
L6's two-phase check went from ~50 seconds to ~7 — and a genuine timeout is now reported
rather than mistaken for a clean result.

`VERIFY_BOOT_WAIT` is obsolete; the timeout is the last argument to `boot_and_wait`.

**Each script states what it does not check.** Every lesson has claims that need a model
provider — a real tool call, a payload shape, a fan-out — and no script pretends to cover
them. Those are listed per lesson in [VERIFIED.md](../VERIFIED.md).

## Overlays

| File | Lesson | What it does |
|---|---|---|
| `l2.patch.yml` | 2 | The row for the `word_count` tool, as a `--patch` overlay rather than a bundle row |
| `l2.override.patch.yml` | 2 | Overrides the **installed** row's config in place — no `insert`, no `name` |
| `l3.hmr.patch.yml` | 3 | Points `dsh-hmr` at the kit's plugin directory so an edit reloads live |
| `l5.skills.patch.yml` | 5 | Points `skill-filesystem` at the kit's own skill directory |
| `l7.patch.yml` | 7 | Opens the session store, inserts the query tool and the invariant checks |
| `l9.patch.yml` | 9 | Inserts the opt-in `schedule` and `webhook` packages |

Two things about these are deliberate and worth reading before adapting them:

- **`l2.patch.yml` and `l3.hmr.patch.yml` are teaching aids, not the way to add a
  plugin.** The lesson plugins ship in [`../kit-plugins/`](../kit-plugins/README.md);
  these files show the overlay mechanism being used where it is the right tool —
  overriding an installed row's config, or turning on a watch root.
- **`l9.patch.yml` must be applied to a web-backed profile.** On a base-backed one both
  rows sit in `PENDING`, naming services only the web bundle provides
  ([ADR-0016](../decisions/0016-profile-choice-is-load-bearing.md)).

## Where the lesson code lives

[`../examples/`](../examples/README.md) is a **generated** mirror of
`../kit-plugins/`, so lesson text and booting code cannot drift. Never edit it by hand.
