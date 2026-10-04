# Third-party notices and attribution

## DeepSeek Harness

This repository is an **independent, unofficial** teaching resource for
[DeepSeek Harness](https://github.com/deepseek-ai/deepseek-harness) (`dsh`), which
is developed by [DeepSeek AI](https://deepseek.com) and released under the MIT
License.

Not affiliated with, sponsored by, or endorsed by DeepSeek AI. "DeepSeek",
"DeepSeek Harness", and `dsh` are used descriptively to identify the software this
curriculum teaches.

### What is derived

The curriculum's technical claims — plugin lifecycle states, event names and
dispatch modes, configuration composition rules, tool and service contracts,
session and projection semantics, and the CLI surface — are derived from the
public DeepSeek Harness documentation and source code, including:

- `docs/architecture.md`, `docs/tool-catalog.md`, `docs/config-catalog.md`
- `docs/cordis-primer.md` and `docs/cordis-tutorial/01..07`
- `docs/cookbook/*` and `docs/subsystems/*`
- `docs/user/develop/*`
- Package `README.md` files under `packages/`

Links to that documentation point at the upstream repository and are clearly
marked as upstream references.

### What is original

The lesson design and sequencing, the exercises and their verification steps, the
capability map's grouping and presentation, the explanations, and all website
code in this repository are original to this project.

### Upstream citations

Where a lesson relies on a specific upstream document, it links to it directly
rather than restating it. If an upstream document moves or is renamed, the link
breaks — please open an issue.

## Dependencies

The website uses [VitePress](https://vitepress.dev) (MIT) and its transitive
dependencies. See `website/package.json` and `website/pnpm-lock.yaml` for the
exact versions.
