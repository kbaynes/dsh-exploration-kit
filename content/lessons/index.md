# Exploration Lessons

The nine lessons of the [DSH exploration plan](../index.md). Work them in order;
each assumes only the artifacts of the lessons before it. The ordering rationale
is [the learning path](../learning-path.md), and the capability inventory is the
[feature map](../feature-map.md).

Work them in order. If you have half an hour rather than a weekend, the
[learning path](../learning-path.md#if-you-only-have-30-minutes) names the two that carry the
mental model.

- [L1 — Mount your first plugin](./01-plugin-lifecycle.md) - Install the kit's plugin bundle, write a real plugin into it, and observe the fiber lifecycle including a loud failure and a silent `PENDING`.
- [L2 — Register a tool, compose with config](./02-tool-and-effects.md) - A model-facing tool with a validated schema, a deliberately broken config, and a config override from a second patch layer.
- [L3 — Services, isolation, and hot reload](./03-service-and-hmr.md) - Provide `ctx.yourService`, force a consumer into `PENDING`, hot-edit a running plugin, and inspect the live loader tree.
- [L4 — Build a policy gate](./04-policy-waterfalls.md) - Waterfall interception at `tools/pre-execute`, monotonic guards, and mapping policy to the seams that already own it.
- [L5 — Assemble context deliberately](./05-context-assembly.md) - Hook the turn flow, inject durable context, ship a discoverable skill, and add a command with no model turn.
- [L6 — Give the session durable state](./06-durable-session-state.md) - Add a `SessionEventMap` event, fold it into a projection, and prove it survives a restart.
- [L7 — Operate the harness](./07-operating-the-harness.md) - Session query tools, trajectory replay, token accounting, telemetry modes, and runtime invariants.
- [L8 — Orchestrate multiple agents](./08-multi-agent-orchestration.md) - Subagents and forks, workflow fan-out with schema-validated results, and a measured monolith-versus-fan-out comparison.
- [L9 — Automate the harness](./09-automation-and-triggers.md) - Headless runs, the SDKs and ACP, schedules, webhooks, and the operating bar before unattended deployment.
