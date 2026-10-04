---
type: Exploration Lesson
title: "L7 — Operate the harness"
description: Measure a real task — turn on session-query tools, read the trajectory from the log, account for tokens, and audit the cost of a multi-turn run.
resource: dsh
tags: [deepseek-harness, lesson, observability, telemetry, session-query, token-meter, replay]
timestamp: 2026-09-30
---

# L7 — Operate the harness

**Goal.** By the end of this lesson you can answer three questions about any run
without guessing: what actually happened, what it cost, and how to get the raw
evidence back out.

**Why here.** L6 gave you durable facts. This lesson turns those facts into
answers, so that L8's multi-agent fan-out is measurable rather than a leap of
faith.

## Concepts taught

| Concept | What you learn |
|---|---|
| Session query | `ctx.sessionQuery` plus the opt-in model-facing session tools |
| Workspace authority | Cross-session access requires exact `cwd` equality |
| Trajectory replay | Reconstructing a run from the log rather than from a live process |
| Token accounting | `dsh-token-meter` and `dsh-session-stats` |
| Telemetry modes | OTel export gated behind explicit user feedback, and how to opt out |
| Invariants | `runtime-diagnostics/invariants` as a self-check |
| Cost auditing | Turning a trajectory into a defensible number |

Reference: [observability & auditing](https://github.com/deepseek-ai/deepseek-harness/blob/main/docs/subsystems/otel.md) and the
[telemetry pipeline checklist](https://github.com/deepseek-ai/deepseek-harness/blob/main/docs/subsystems/session-telemetry.md).

## Prerequisites

L1–L6 complete, including your `l6/step` events — this lesson reads them back. A
model provider is required for the cost part; steps 1–4 here are testable without one.

## Step 1 — Turn on programmatic session history

Session history access is a service (`ctx.sessionQuery`) plus, optionally,
model-facing tools. Both pieces are opt-in, so enable them deliberately rather than
assuming they are present.

The kit ships the overlay at `<kit>/solutions/l7.patch.yml`. Note its **shape**: one
override and three inserts.

```yaml
# already mounted by the web bundle, configured never to open — override in place
- id: session-query-sqlite
  config:
    path: ':memory:'
    openAt: startup

# not mounted by any shipped bundle — insert
- insert:
    - id: tool-session-query
      name: '@deepseek-ai/dsh-tool-session-query'
    - id: invariants
      name: '@deepseek-ai/dsh-invariants'
    - id: session-invariant
      name: '@deepseek-ai/dsh-session/invariant'
```

The web bundle mounts `session-query-sqlite` with `openAt: never`, which provides the
capability without opening a store. Turning it on is therefore an **override** — no
`insert`, no `name` — the same in-place mechanism you used to override a config in L2
and to disable a provider in L3. The tool package, by contrast, is not in any shipped
bundle, so it is an insert.

### The tool package must be installed, and pinned

A row naming a package only works if that package is resolvable in the profile. Two
things bite here, both hit while building this lesson:

```sh
dsh plugin --profile kitdemo add @deepseek-ai/dsh-tool-session-query@<dsh version>
```

- **A row naming an uninstalled package fails at load:**
  `tool-session-query (@deepseek-ai/dsh-tool-session-query): failed to import`,
  because a row name resolves through the profile's installation.
- **Do not omit the version.** npm's `latest` tag for these optional packages is
  stale (`0.0.1-rc.1`), and dsh rejects it outright:
  `Plugin @deepseek-ai/dsh-tool-session-query@0.0.1-rc.1 is incompatible with dsh 0.2.0-rc.2`.
  Install the version matching your dsh runtime — `0.2.0-rc.2` here — and it installs
  cleanly and activates.

That second point is a real trap for a reader: the obvious command is the one without
a version, and it appears to work until the boot.

Now the model has five read-only tools: `session_search`, `session_event_search`,
`session_trace`, `session_event_trace`, and `session_event_read`.

Two contract details worth understanding before you rely on them:

- **Authorization is workspace-scoped.** Cross-session access requires the target
  session's `cwd` to equal the caller's exactly; a caller without a `cwd` can inspect
  only itself. Unauthorized boundaries appear as markers without hidden ids, and
  missing versus cross-workspace guesses behave identically — no information leak
  either way.
- **Search is cursor-free and capped.** A capped result asks the model to narrow its
  query rather than exposing offsets or page sizes. The caller's own session is always
  omitted from search, and for the current session the tools stop before the step that
  invoked them.

Enabling this package adds fixed guidance plus five tool schemas to **every** model
request, so it is a real prompt-budget decision, not a free toggle.

Boot with the overlay to confirm the whole composition still activates:

```sh
dsh --profile kitdemo --patch <kit>/solutions/l7.patch.yml --port 0 --no-open
```

## Step 2 — Read the trajectory instead of the terminal

Terminal scrollback is not evidence. Reconstruct the run from the log:

1. Ask the agent to `session_event_read` the events of the session you just ran,
   or read the JSONL yourself under `$DSH_HOME/sessions/` (`~/.dsh` by default).
2. Find your `l6/step` events from L6 and confirm their sequence position relative
   to `tool/result`.
3. Use `session_event_trace` on one event to see its positional replacements and
   cited source-event relationships. This is how you answer "what did the model
   actually see at this point" rather than "what does the transcript look like".

The mental model to keep: the session log is the source of truth,
`deriveMessages()` projects model history from it, and the human transcript is a
*different* projection. A trajectory view that cannot be reconstructed from the
log is a bug, not a feature.

## Step 3 — Account for tokens

Token accounting is always on: `token-meter` is in the base bundle. Two practical
moves:

- Ask for a **session statistics** view and compare per-turn totals before and after
  you mount the extra tools from step 1. You have just made a measurable trade: five
  schemas and fixed guidance on every request, in exchange for retrieval.
  `session-stats` is mounted by the **web** bundle, so this step needs a web-backed
  profile — `--profile web` — not the `kitdemo` one earlier lessons boot (see
  [ADR-0016](https://github.com/REPLACE_OWNER/dsh-exploration-kit/blob/main/decisions/0016-profile-choice-is-load-bearing.md)).
- Force a compaction (`/compact`, from `command-compact`) on a long session and
  observe the reduction. Compaction is the harness's own answer to context
  pressure, and watching it once teaches more than reading about it.

Record the numbers. L8 will have you compare a monolithic run against a
decomposed one, and that comparison is only meaningful if you can produce these
figures on demand.

## Step 4 — Know what telemetry leaves the machine

OTel export is mounted by the base bundle but gated: OTel releases a Session-log
prefix **only after explicit user feedback**, regardless of model provider —
ordinary activity never triggers capture. Useful controls:

| Control | Effect |
|---|---|
| `DSH_TELEMETRY_OTLP_URL` | Override the production endpoint |
| `DSH_TELEMETRY_DISABLED` | A non-empty value (including `'0'`/`'false'`) opts the process out |
| `DSH_TELEMETRY_MODE` | The `session-telemetry-otel` mode, default `FEEDBACK_ONLY` |

Note the mechanism: launchers patch the row `disabled`; config alone cannot
disable a mounted row. Opacity here is a feature — read the row's own comments in
`packages/bundle/base/cordis.patch.yml` before you change the mode, and decide
deliberately whether an exploration workspace should emit anything.

## Step 5 — Let the harness audit itself

`@deepseek-ai/dsh-invariants` checks runtime properties — including the
"model-visible means logged" invariant that L6 depended on. It is **not** mounted by
the base, web, or headless bundles (only `sdk-minimal` carries it), which is why
`solutions/l7.patch.yml` inserts it alongside the session-specific half:

```yaml
    - id: invariants
      name: '@deepseek-ai/dsh-invariants'
    - id: session-invariant
      name: '@deepseek-ai/dsh-session/invariant'
```

The shipped composition pairs them; copying only the first leaves the session checks
unarmed. Both are already in the overlay, so a boot with it runs the checks. An
invariant failure here is the cheapest possible way to find a design mistake you would
otherwise discover through corrupted replays weeks later.

Then write the audit down. A defensible cost statement has four parts: the task,
the turn and step count, the token totals, and the events that prove them. If any
part is missing, the number is a guess.

## Verification

```sh
bash <kit>/solutions/verify-l7.sh <path/to/deepseek-harness>
```

Observable without a session:

1. The overlay's shape is right: `session-query-sqlite` is an *override* (the web
   bundle already mounts it) while `tool-session-query` and the two invariants rows are
   *inserts*.
2. `openAt: startup` is present — the shipped default is `never`, so without it the
   store never opens.
3. A boot with the overlay produces **no activation warnings**. The signature of
   getting this wrong is worth recognizing on sight:
   `tool-session-query ...: failed to import` means a row names a package the profile
   does not have installed.
4. The profile manifest shows `@deepseek-ai/dsh-tool-session-query` pinned to your dsh
   version — not to npm's stale `latest` tag, which dsh rejects as incompatible.

Requires a session, and therefore a provider:

5. `session_event_read` returns events as JSON with neighbours.
6. A deliberate cross-workspace query is refused, and a missing target is
   indistinguishable from an unauthorized one.
7. You can state the token delta caused by mounting `tool-session-query`.
8. `/compact` produces a measurable reduction on a long session.
9. The invariant sweep reports no failure on the kit's composition.

Items 5–9 are recorded as unverified in
[VERIFIED.md](https://github.com/REPLACE_OWNER/dsh-exploration-kit/blob/main/VERIFIED.md).

## Exit check — you should now be able to explain

- Why the human transcript and the model history are two different projections.
- What the workspace-authority rule prevents, and how it fails closed.
- Why "trajectory replay" is a stronger claim than "we log things".
- Which of the four audit parts you would be tempted to fake, and what makes that
  detectable.

## Next

[L8 — Orchestrate multiple agents](./08-multi-agent-orchestration.md),
where these measurement skills pay off immediately.
