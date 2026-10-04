# Solutions and verification

Two things live here: the **overlays** each lesson applies, and a **verification script per lesson**.

## Verification scripts

```sh
bash solutions/verify-l2.sh <path/to/deepseek-harness>
```

Each script checks the wiring a lesson depends on — that the bundle carries the right rows, that a plugin declares the services it uses, that an overlay composes the way the lesson says — and prints `PASS`/`FAIL` per assertion. They need a DSH checkout and a provisioned profile:

```sh
bash scripts/install-dsh-shim.sh <path/to/deepseek-harness> /tmp/dsh-bin
PATH=/tmp/dsh-bin:$PATH bash scripts/setup-verify-profiles.sh
```

`pnpm run check:kit` runs all of them when `DSH_CHECKOUT` is set, and the `verify against dsh` workflow runs them in CI against the pinned commit.

**Boots end when the work is done, not after a fixed sleep.** `lib.sh` provides `boot_and_wait`, which polls the boot log for the probe's own `[<lesson>-probe] done` line and stops there. A fixed wait has to suit the slowest machine and wastes time on the fastest, and when it is too short the failure is *silent*: a boot killed early leaves an empty log, and a check asserting on a pattern's **absence** still passes. Polling removed both problems — L6's two-phase check went from ~50 seconds to ~7 — and a genuine timeout is now reported rather than mistaken for a clean result.

`VERIFY_BOOT_WAIT` is obsolete; the timeout is the last argument to `boot_and_wait`.

**Each script states what it does not check.** Every lesson has claims that need a model provider — a real tool call, a payload shape, a fan-out — and no script pretends to cover them. Those are listed per lesson in [VERIFIED.md](../VERIFIED.md).

## Running the checks that need a real provider

Three exit-check items need real model judgement rather than the scriptable mock: L7's input-token delta, and L8's "a child does not know the parent's conversation" and "a model chooses `send_message`/`interrupt_agent`". They are **opt-in**. With no provider patch set, those phases print `SKIP` and the suite stays keyless.

Point `DSH_REAL_PROVIDER_PATCH` at a patch that registers a real route. Any provider the `llm-pi-ai` adapter knows works; this recipe is the one that was run:

```yaml
# /tmp/real-provider.patch.yml
- id: llm-pi-ai
  config:
    providers:
      openrouter:
        apiKeyEnv: OPENROUTER_API_KEY
```

```sh
export DSH_REAL_PROVIDER=openrouter
export DSH_REAL_MODEL=deepseek/deepseek-chat
export DSH_REAL_PROVIDER_PATCH=/tmp/real-provider.patch.yml
bash solutions/verify-l7.sh <path/to/deepseek-harness>
bash solutions/verify-l8.sh <path/to/deepseek-harness>
```

Details that cost iterations, and are worth not repeating:

- **The patch registers the ROUTE; the two env vars tell the probes which route to hand to `agents.create()`.** Setting one without the other is the usual half-configuration, and it fails in a way that looks like a provider fault: the turn runs on the mock route and reports zero tokens.
- **`apiKeyEnv` is a credential *reference*, resolved per request** — inherited process environment first, then `$DSH_HOME/.credentials.yaml`, then `.env` fallbacks. `export` works, and so does an entry under `refs:` in that file. Where `DSH_HOME` points decides which credential file is read.
- **`models:` is optional.** A provider profile that declares none inherits the models `@earendil-works/pi-ai` ships for that provider id, so a catalog slug needs no hand-written entry.
- **Two error signatures mean different things.** `NO_ADAPTER: no adapter registered for provider "…"` means the route did not register (the patch, the profile, or the row id). `no API key for provider route "…"` means a turn ran on the **wrong** route — the caller chose it, not the patch.
- **`settings.yaml` is the wrong lever.** The active provider config is a profile patch; `settings.yaml` is a legacy document imported once, and writing it by hand does not register the route.

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

- **`l2.patch.yml` and `l3.hmr.patch.yml` are teaching aids, not the way to add a plugin.** The lesson plugins ship in [`../kit-plugins/`](../kit-plugins/README.md); these files show the overlay mechanism being used where it is the right tool — overriding an installed row's config, or turning on a watch root.
- **`l9.patch.yml` must be applied to a web-backed profile.** On a base-backed one both rows sit in `PENDING`, naming services only the web bundle provides ([ADR-0016](../decisions/0016-profile-choice-is-load-bearing.md)).

## Where the lesson code lives

[`../examples/`](../examples/README.md) is a **generated** mirror of `../kit-plugins/`, so lesson text and booting code cannot drift. Never edit it by hand.
