---
type: Feature Map
title: DeepSeek Harness Capability Map
description: The complete inventory of DeepSeek Harness capabilities, grouped by subsystem, with the packaged plugin or seam each one comes from and the exploration lesson that exercises it.
resource: dsh
tags: [deepseek-harness, capabilities, feature-map, plugins, seams, tooling]
timestamp: 2026-09-30
---

# DeepSeek Harness Capability Map

The reference inventory behind the [exploration lesson plan](index.md). Every row is a capability that ships in the repository checkout, named by the package or seam that provides it. The **Lesson** column points at the [guided lesson](index.md) that puts that capability under your hands.

**Reading that column.** A link means the lesson teaches or exercises the capability. An em dash (`—`) means it ships in the harness but **no lesson here covers it** — this is a path through the harness, not a survey of it, and saying so is more useful than a link that does not deliver.

Sources: the [plugin model](https://github.com/deepseek-ai/deepseek-harness/blob/main/docs/user/develop/framework/index.md), the architecture doc's "where new behavior goes" table (`docs/architecture.md`), the tool schema catalog (`docs/tool-catalog.md`), and the shipped bundle patches (`packages/bundle/base/cordis.patch.yml`, `packages/bundle/web-app/cordis.patch.yml`).

## 1. Plugin core — the defining capability

| Capability | Provided by | Lesson |
|---|---|---|
| Everything-is-a-plugin composition into one shared context | Cordis core | [L1](./lessons/01-plugin-lifecycle.md) |
| Two plugin shapes exercised: function, `Service` subclass (the object form is documented upstream, not taught here) | Cordis | [L1](./lessons/01-plugin-lifecycle.md), [L3](./lessons/03-service-and-hmr.md) |
| Fiber lifecycle `PENDING → LOADING → ACTIVE → UNLOADING → DISPOSED`, plus `FAILED` | Cordis registry | [L1](./lessons/01-plugin-lifecycle.md) |
| Reversible effects — registrations unwind on unload | `ctx.on`, `ctx.plugin`, `ctx.effect` | [L1](./lessons/01-plugin-lifecycle.md), [L2](./lessons/02-tool-and-effects.md), [L3](./lessons/03-service-and-hmr.md) |
| Dependency injection and load ordering via `inject` | Cordis services | [L3](./lessons/03-service-and-hmr.md) |
| Typed events in five dispatch modes: `emit`, `parallel`, `serial`, `bail`, `waterfall` | Cordis events | — |
| Config validation before `apply` runs (Schemastery) | Cordis config | [L2](./lessons/02-tool-and-effects.md) |
| Service isolation — two groups seeing different instances of one service name | Cordis `isolate` realms | [L3](./lessons/03-service-and-hmr.md) |
| `!!js` load-time config and `disabled` expressions | Loader | [L2](./lessons/02-tool-and-effects.md) |
| Profiles, bundles, patches; ordered composition at boot | `dsh-base`, `dsh-web-app`, `dsh-headless`, `dsh-sdk-app` | [L1](./lessons/01-plugin-lifecycle.md), [L2](./lessons/02-tool-and-effects.md) |
| Live config inspection — `dsh --dump-config`, `--dump-config-schema` | `apps/cli` | [L1](./lessons/01-plugin-lifecycle.md), [L2](./lessons/02-tool-and-effects.md) |
| Hot module reload of changed plugins | `@deepseek-ai/dsh-hmr` | [L3](./lessons/03-service-and-hmr.md) |
| Read-only live loader-tree projection | `@deepseek-ai/dsh-host-plugin-inventory` | [L3](./lessons/03-service-and-hmr.md) |
| Runtime define/run of Cordis packages, host and browser halves | `extensions/{tool-cordis,cordis-host-runner,cordis-client-runner,ui-cordis}` | — |

## 2. Extension seams — where new behavior attaches

| Seam | `ctx` key / event | Lesson |
|---|---|---|
| Model provider | register adapter on `ctx.llm` | — (see [cookbook](https://github.com/deepseek-ai/deepseek-harness/blob/main/docs/cookbook/adding-an-llm-adapter.md)) |
| Model-facing capability | `ctx.tools.register(...)` | [L2](./lessons/02-tool-and-effects.md) |
| Per-session capability set | agent preset (a service row there needs an `isolate` realm) | [L9](./lessons/09-automation-and-triggers.md) |
| Shell execution backend | `ctx.shell` (`bash-local`, `bash-sandbox`, `pwsh-*`) | — (swap providers, not author) |
| Persistent terminal backend | `ctx.terminals` + `dsh-tool-terminal` | — |
| Human command (no model turn) | `ctx.commands` | [L5](./lessons/05-context-assembly.md) |
| Background work | `ctx.jobs.start(...)` + `job_*` tools | — |
| External webhook → new Session | `ctx.webhookRuntime` + a provider adapter | [L9](./lessons/09-automation-and-triggers.md) |
| Filesystem provider or policy | `ctx.fs` provider, `fs/*` events | [L4](./lessons/04-policy-waterfalls.md) |
| Process confinement | `ctx.sandbox` backend | [L4](./lessons/04-policy-waterfalls.md) |
| Interception of requests, tools, turns | `agent/*`, `tools/*` events | [L4](./lessons/04-policy-waterfalls.md), [L5](./lessons/05-context-assembly.md) |
| Monotonic tool guards — a denial no later listener can reverse | `ctx.tools.guard()` | [L4](./lessons/04-policy-waterfalls.md) |
| Model-facing context injection | `agent.inject()` | [L5](./lessons/05-context-assembly.md) |
| Durable session state | `ctx.sessionProjections.register(…)` folding a **known** first-party event | [L6](./lessons/06-durable-session-state.md) |
| Stored-event vocabulary validation — a log containing an unknown event type is refused unless the event is marked `ignorable` | `validateStoredEvents`, `KNOWN_SESSION_EVENT_TYPES` | [L6](./lessons/06-durable-session-state.md), [L7](./lessons/07-operating-the-harness.md) |
| Skill discovery | `skill-filesystem` (`customSkillDirs`) + the `skill` tool | [L5](./lessons/05-context-assembly.md) |
| UI / editor integration | `ctx.agents`, `session/event`, `ConversationNodeDefinition` | — |
| Session title generation | `ctx.sessionTitle` provider | — |

## 3. Agent runtime

| Capability | Provided by |
|---|---|
| Agent loop, turn/step admission, steering and follow-ups | `dsh-agent`, `dsh-agent-loop` |
| System-prompt assembly (tool schemas join it automatically) | `dsh-system-prompt` |
| Plan mode with an approval gate | `dsh-plan-mode` |
| Same-session objectives across rounds (`create_goal`/`get_goal`/`update_goal`) | `dsh-goal`, `dsh-goal-round-driver` |
| Todo checklist state | `dsh-tool-todo` |
| Conversation compaction, image offload, tool-result pruning | `compaction-*` |
| Token metering and cost accounting | `dsh-token-meter` |
| Timeout policy, repeat-tool reminder | `guard/timeout-policy`, `guard/repeat-tool-reminder` |
| Output spill and truncation policies | `spill-local`, `spill-policy` |

## 4. Tool surface

| Group | Tools |
|---|---|
| Filesystem | `read`, `write`, `edit`, `read_image`, `str_replace_editor` |
| Shell | `bash`, `pwsh` (one-shot; `*_run_in_background`), persistent PTY variants |
| Discovery | `glob`, `grep` (packaged ripgrep via `ctx.subprocess`) |
| Terminal control | `terminal_open/read/send/signal/list/close` |
| Web | `web_search`, `web_fetch` (providers: deepseek, exa, perplexity, http) |
| Code as glue (PTC) | `run_code` in `mode: ptc` / `both` — programs call visible tools as `await tools.<name>(args)` |
| Language intelligence | `lsp` (provider behind `ctx.lsp`, e.g. `lsp-stdio`) |
| MCP | MCP client plus `list_mcp_resources`, `read_mcp_resource`, `list_mcp_resource_templates` |
| Human interaction | `ask_user_question`, approval prompts, `exit_plan_mode` |
| Deliverables | `present`, workspace-changes diffing, `office-to-pdf` |
| Introspection | `cordis_inspect_list`, `cordis_inspect_query`, `plugin_manager`, `load_workspace_dependencies` |
| Session history | `session_search`, `session_trace`, `session_event_read/search/trace` |

## 5. Delegation and orchestration

| Capability | Provided by | Lesson |
|---|---|---|
| Delegate one focused task to an isolated context | `subagent` tool + `subagent-spawn-in-process` | [L8](./lessons/08-multi-agent-orchestration.md) |
| Fork the current conversation into a child | `subagent_fork` + `subagent-fork-in-process` | [L8](./lessons/08-multi-agent-orchestration.md) |
| Continuable children: message, interrupt, list | `send_message`, `interrupt_agent`, `list_agents` | [L8](./lessons/08-multi-agent-orchestration.md) |
| Scripted fan-out with phases, pipelines, barriers, schema-validated results | `workflow` tool + `ctx.workflowEngine` | [L8](./lessons/08-multi-agent-orchestration.md) |
| Fresh child per round on one immutable objective | `ralph` tool | — |
| Alternative delegation backends (ACP, Claude Code, Codex, dsh-sdk) | `subagent-*` providers | [L8](./lessons/08-multi-agent-orchestration.md) |
| Roster + task board + mailbox coordination | experimental `agent-team` (`ctx.agentTeams`) | [L8](./lessons/08-multi-agent-orchestration.md) |

## 6. Context engineering

| Capability | Provided by | Lesson |
|---|---|---|
| `AGENTS.md` / `CLAUDE.md` auto-loading with directory precedence | `dsh-agent-instructions` | [L5](./lessons/05-context-assembly.md) |
| Skills (filesystem, office, badges) loaded on demand | `skill*`, `tool-skill` | [L5](./lessons/05-context-assembly.md) |
| File and session references with `@path` semantics | `file-reference*`, `session-reference` | — |
| Ambient time and tmux context | `time-context`, `tmux-context` | — |
| Credential redaction in context | `dsh-credentials` | [L4](./lessons/04-policy-waterfalls.md) |

## 7. Sessions, state, and persistence

| Capability | Provided by | Lesson |
|---|---|---|
| Durable session log as the source of truth | `dsh-session`, `session-format` | [L6](./lessons/06-durable-session-state.md) |
| JSONL persistence with versioned migrations | `session-persistence-jsonl`, `session-format-vN-to-vN+1` | — |
| Incremental projections and cached client views | `session-projection`, `session-projection-cache` | [L6](./lessons/06-durable-session-state.md) |
| SQLite session query and export | `session-query-sqlite`, `session-log-export` | — |
| Fork and resume at a turn boundary | `ctx.agents.create({ seed, inheritedEventCount, meta })` / `ctx.agents.resume` | [L6](./lessons/06-durable-session-state.md), [L8](./lessons/08-multi-agent-orchestration.md) |
| Checkpointing policy | `session-checkpoint-policy` | — |

## 8. Web GUI and client

| Capability | Provided by |
|---|---|
| Session/conversation surfaces and streaming render | `client/ui-*`, `web-runtime` |
| Approval prompts and permission presets | `ui-approval`, `permission-presets` |
| Right sidebar: files, terminal, browser, document preview | `ui-sidebar-*` |
| Plugin manager and plugin inventory UI | `ui-plugin-manager`, `ui-settings-plugin-inventory` |
| Settings cards contributed per plugin | `ui-settings-*`, `settings-controller` |
| File upload, directory picker, open-in-app | `file-upload`, `directory-picker*`, `open-in-app` |
| Deliverable cards, workspace diffs, goal and jobs panels | `ui-deliverables`, `workspace-changes`, `ui-goal`, `ui-jobs` |
| Theming, i18n, shortcuts, client HMR | `ui-theme`, `locale`, `ui-shortcuts`, `client-hmr` |

## 9. Integration and automation

| Capability | Provided by | Lesson |
|---|---|---|
| TypeScript SDK (spawns a runtime, drives turns) | `packages/sdk/client` | [L9](./lessons/09-automation-and-triggers.md) |
| Python SDK over the same protocol | `python/` | [L9](./lessons/09-automation-and-triggers.md) |
| Newline-delimited JSON-RPC wire protocol | `sdk/protocol`, `sdk/server` | [L9](./lessons/09-automation-and-triggers.md) |
| Agent Client Protocol server for programmatic clients | `packages/acp` | — |
| One-shot headless execution | `dsh-headless` bundle | [L9](./lessons/09-automation-and-triggers.md) |
| Scheduled wakes (interval, absolute, daily/weekly, cron) | `dsh-schedule` + `schedule_*` tools | [L9](./lessons/09-automation-and-triggers.md) |
| Webhook-triggered sessions, including GitHub events | `webhook`, `webhook-github` | [L9](./lessons/09-automation-and-triggers.md) |
| Hook protocol adapters for Claude Code and Codex | `hooks-*`, `hook-protocol` | [L9](./lessons/09-automation-and-triggers.md) |
| Remote execution over SSH | `ssh`, `fs-ssh`, `subprocess-ssh`, `sandbox-ssh` | — |
| HTTP API gateway with controllers | `packages/api/*` | — |
| Browser automation and computer use | `browser-use*`, `computer-use*` (experimental) | — |
| Speech-to-text and voice input | `experimental/speech-to-text*` | — |

## 10. Model providers

| Capability | Provided by |
|---|---|
| DeepSeek API key and account-backed routes | `llm-deepseek`, `llm-deepseek-api-key`, `llm-deepseek-account` |
| Third-party providers (e.g. OpenRouter) with per-model reasoning control | `llm-pi-ai` |
| Retry and fallback policy | `llm-retry` |
| Sandboxed execution backends | `sandbox-local`, `e2b`, `sandbox-windows-acl` |

See [OpenRouter integration & reasoning error hardening](https://github.com/deepseek-ai/deepseek-harness/blob/main/docs/user/guide/providers.md) for the verified provider-configuration recipe.

## 11. Observability and operations

| Capability | Provided by | Lesson |
|---|---|---|
| OpenTelemetry traces and metrics | `otel`, `session-telemetry-otel` | [L7](./lessons/07-operating-the-harness.md) |
| Token/cost accounting per session | `token-meter`, `session-stats` | [L7](./lessons/07-operating-the-harness.md) |
| Trajectory replay from the durable log | `session-projection`, `session-query` | [L7](./lessons/07-operating-the-harness.md) |
| Runtime invariant checking | `runtime-diagnostics/invariants` | [L7](./lessons/07-operating-the-harness.md) |

Deploy-time hardening guidance is **not** published by DSH as documentation; it lives in the package READMEs for the container, session-store, and telemetry packages, plus your own operational judgment. Treat every row above as a capability to harden rather than a deployment recipe.

## Related Concepts

- [Exploration lesson plan](index.md) — the ordered path through this map
- [Plugin model](https://github.com/deepseek-ai/deepseek-harness/blob/main/docs/user/develop/framework/index.md) — the mechanism behind every row in section 1
- [Plugin discovery](https://github.com/deepseek-ai/deepseek-harness/blob/main/docs/user/develop/basic/publish.md) — finding third-party plugins that add rows
- [Headless integration model](https://github.com/deepseek-ai/deepseek-harness/blob/main/packages/bundle/headless/README.md) — deploying section 9
- [Observability & auditing](https://github.com/deepseek-ai/deepseek-harness/blob/main/docs/subsystems/otel.md) — deploying section 11
