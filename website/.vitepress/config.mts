import { readFileSync } from 'node:fs'
import { resolve } from 'node:path'
import { defineConfig } from 'vitepress'

// The curriculum has a single source of truth: ../content (an OKF bundle).
// VitePress reads it directly — nothing is copied or generated into the site.

// Derived from package.json so the repository identity lives in ONE place. Anything here
// that needs an absolute URL (the social link, the edit link, link-preview metadata) is
// computed from it, which means publication substitutes the owner in package.json rather
// than in this file. See PUBLISHING.md and ADR-0026.
const pkg = JSON.parse(readFileSync(resolve(import.meta.dirname, '../../package.json'), 'utf8'))
const owner = pkg.kit?.repositoryOwner ?? 'REPLACE_OWNER'
const repoName = pkg.kit?.repositoryName ?? 'dsh-exploration-kit'
const repoUrl = `https://github.com/${owner}/${repoName}`
const siteUrl = `https://${owner}.github.io/${repoName}/`

export default defineConfig({
  srcDir: '../content',
  lang: 'en-US',
  title: 'DSH Exploration Kit',
  description:
    'A hands-on, nine-lesson curriculum for learning DeepSeek Harness by building real plugins.',

  // Change this to '/' when serving from a user/org root domain, or to your
  // repository name when serving from GitHub Pages project pages.
  base: '/dsh-exploration-kit/',

  cleanUrls: true,
  lastUpdated: true,
  markdown: { lineNumbers: true },

  head: [
    ['meta', { name: 'theme-color', content: '#0b7285' }],
    ['meta', { name: 'author', content: 'DSH Exploration Kit contributors' }],
    // Link-preview metadata. Without it, promoting the kit on Discord or in a discussion
    // produces a bare URL, which is a poor first impression for a curriculum whose whole
    // pitch is that it is hands-on.
    ['meta', { property: 'og:type', content: 'website' }],
    ['meta', { property: 'og:site_name', content: 'DSH Exploration Kit' }],
    ['meta', { property: 'og:title', content: 'DSH Exploration Kit' }],
    [
      'meta',
      {
        property: 'og:description',
        content:
          'A hands-on, nine-lesson curriculum for learning DeepSeek Harness by building real plugins.',
      },
    ],
    ['meta', { property: 'og:url', content: siteUrl }],
    ['meta', { name: 'twitter:card', content: 'summary' }],
  ],

  themeConfig: {
    outline: { level: [2, 3], label: 'On this page' },

    nav: [
      { text: 'Start', link: '/learning-path' },
      { text: 'Lessons', link: '/lessons/' },
      { text: 'Capability map', link: '/feature-map' },
    ],

    sidebar: [
      {
        text: 'Overview',
        items: [
          { text: 'Home', link: '/' },
          { text: 'Learning path', link: '/learning-path' },
          { text: 'Capability map', link: '/feature-map' },
        ],
      },
      {
        text: 'Lessons',
        collapsed: false,
        items: [
          { text: '1 — Mount your first plugin', link: '/lessons/01-plugin-lifecycle' },
          { text: '2 — Register a tool, compose with config', link: '/lessons/02-tool-and-effects' },
          { text: '3 — Services, isolation, and hot reload', link: '/lessons/03-service-and-hmr' },
          { text: '4 — Build a policy gate', link: '/lessons/04-policy-waterfalls' },
          { text: '5 — Assemble context deliberately', link: '/lessons/05-context-assembly' },
          { text: '6 — Give the session durable state', link: '/lessons/06-durable-session-state' },
          { text: '7 — Operate the harness', link: '/lessons/07-operating-the-harness' },
          { text: '8 — Orchestrate multiple agents', link: '/lessons/08-multi-agent-orchestration' },
          { text: '9 — Automate the harness', link: '/lessons/09-automation-and-triggers' },
        ],
      },
    ],

    socialLinks: [{ icon: 'github', link: repoUrl }],

    // The repository invites contributions, so give readers a way to make them from the page.
    editLink: {
      pattern: `${repoUrl}/edit/main/content/:path`,
      text: 'Edit this page',
    },

    search: { provider: 'local' },

    footer: {
      message:
        'Independent, unofficial teaching resource. DeepSeek Harness is by DeepSeek AI, MIT licensed.',
      copyright: 'MIT licensed',
    },

    docFooter: { prev: 'Previous', next: 'Next' },
    darkModeSwitchLabel: 'Appearance',
    returnToTopLabel: 'Return to top',
  },
})
