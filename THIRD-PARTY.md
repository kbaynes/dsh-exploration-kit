# Third-party notices and attribution

## DeepSeek Harness

This repository is an **independent, unofficial** teaching resource for [DeepSeek Harness](https://github.com/deepseek-ai/deepseek-harness) (`dsh`), which is developed by [DeepSeek AI](https://deepseek.com) and released under the MIT License.

Not affiliated with, sponsored by, or endorsed by DeepSeek AI. "DeepSeek", "DeepSeek Harness", and `dsh` are used descriptively to identify the software this curriculum teaches.

### What is derived

The curriculum's technical claims — plugin lifecycle states, event names and dispatch modes, configuration composition rules, tool and service contracts, session and projection semantics, and the CLI surface — are derived from the public DeepSeek Harness documentation and source code, including:

- `docs/architecture.md`, `docs/tool-catalog.md`, `docs/config-catalog.md`
- `docs/cordis-primer.md` and `docs/cordis-tutorial/01..07`
- `docs/cookbook/*` and `docs/subsystems/*`
- `docs/user/develop/*`
- Package `README.md` files under `packages/`

Links to that documentation point at the upstream repository and are clearly marked as upstream references.

### What is original

The lesson design and sequencing, the exercises and their verification steps, the capability map's grouping and presentation, the explanations, and all website code in this repository are original to this project.

### Upstream copyright notice

DeepSeek Harness is distributed under the MIT License, which requires that its copyright notice be retained wherever the material is redistributed. It is reproduced here for that purpose:

```
MIT License

Copyright (c) DeepSeek AI

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

The authoritative text is [the upstream LICENSE](https://github.com/deepseek-ai/deepseek-harness/blob/main/LICENSE). That URL is intentionally not path-checked by `scripts/check-upstream-links.mjs`, which validates `blob/main/` documentation paths against a checkout.

### Upstream citations

Where a lesson relies on a specific upstream document, it links to it directly rather than restating it. If an upstream document moves or is renamed, the link breaks — please open an issue. `pnpm run check:upstream <path-to-checkout>` verifies every such link against a real DSH checkout.

## Dependencies

The website uses [VitePress](https://vitepress.dev) (MIT) and its transitive dependencies. The exact versions are pinned in the **repository root** [`package.json`](https://github.com/kbaynes/dsh-exploration-kit/blob/main/package.json) and [`pnpm-lock.yaml`](https://github.com/kbaynes/dsh-exploration-kit/blob/main/pnpm-lock.yaml) — the site is built from the root, not from a manifest under `website/`.

The generated site bundles the Inter typeface (SIL Open Font License 1.1) and small MIT-licensed helpers through VitePress. Build output is git-ignored and is not redistributed as source; if a release ever ships `website/.vitepress/dist`, add the OFL notice for Inter alongside this file.
