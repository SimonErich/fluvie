import starlight from '@astrojs/starlight';
import { defineConfig } from 'astro/config';

// The docs site for docs.fluvie.dev. Content is generated from /documentation
// by scripts/import-docs.mjs (run automatically by `npm run build`/`dev`).
export default defineConfig({
  site: 'https://docs.fluvie.dev',
  integrations: [
    starlight({
      title: 'Fluvie',
      description: 'Render declarative Flutter widget trees to real video.',
      logo: {
        light: './src/assets/fluvie_logo.svg',
        dark: './src/assets/fluvie_logo_inverted.svg',
        alt: 'Fluvie',
      },
      favicon: '/favicon.svg',
      social: [
        { icon: 'github', label: 'GitHub', href: 'https://github.com/SimonErich/fluvie' },
      ],
      editLink: {
        baseUrl: 'https://github.com/SimonErich/fluvie/edit/main/documentation/',
      },
      sidebar: [
        {
          label: 'Getting started',
          items: [
            { label: 'Installation', slug: 'getting-started/installation' },
            { label: 'Your first video', slug: 'getting-started/your-first-video' },
            { label: 'Core concepts', slug: 'getting-started/core-concepts' },
          ],
        },
        {
          label: 'Guides',
          items: [
            { label: 'Layouts', slug: 'guides/layouts' },
            { label: 'Backgrounds and gradients', slug: 'guides/backgrounds-and-gradients' },
            { label: 'Text and typography', slug: 'guides/text-and-typography' },
            { label: 'Animating elements', slug: 'guides/animating-elements' },
            { label: 'Timing and triggers', slug: 'guides/timing-and-triggers' },
            { label: 'Scenes and transitions', slug: 'guides/scenes-and-transitions' },
            { label: 'Images and video clips', slug: 'guides/images-and-video-clips' },
            { label: 'Charts and data', slug: 'guides/charts-and-data' },
            { label: 'Code and terminal videos', slug: 'guides/code-and-terminal-videos' },
            { label: 'Diagrams and web views', slug: 'guides/diagrams-and-webviews' },
            { label: 'Audio and captions', slug: 'guides/audio-and-captions' },
            { label: 'Authoring with specs', slug: 'guides/authoring-with-specs' },
            { label: 'AI and MCP', slug: 'guides/ai-and-mcp' },
            { label: 'Rendering on a server', slug: 'guides/rendering-on-a-server' },
            { label: 'On-device mobile rendering', slug: 'guides/on-device-mobile-rendering' },
            { label: 'Exporting your video', slug: 'guides/exporting-your-video' },
          ],
        },
        { label: 'Cookbook', slug: 'cookbook' },
        {
          label: 'Advanced',
          items: [
            { label: 'Timeline orchestration', slug: 'advanced/timeline-orchestration' },
            { label: 'The FrameBuilder escape hatch', slug: 'advanced/frame-builder' },
            { label: 'Shaders and effects', slug: 'advanced/shaders-and-effects' },
            { label: 'Templates', slug: 'advanced/templates' },
            { label: 'Multi-aspect', slug: 'advanced/multi-aspect' },
            { label: 'Theming', slug: 'advanced/theming' },
            { label: 'Determinism and caching', slug: 'advanced/determinism-and-caching' },
            { label: 'Performance', slug: 'advanced/performance' },
          ],
        },
        {
          label: 'Reference',
          items: [
            { label: 'Cheatsheet', slug: 'reference/cheatsheet' },
            { label: 'Migration', slug: 'reference/migration' },
            { label: 'FAQ', slug: 'reference/faq' },
          ],
        },
        {
          label: 'Contributing',
          items: [
            { label: 'Overview', slug: 'contributing/overview' },
            { label: 'Testing', slug: 'contributing/testing' },
            { label: 'Coverage', slug: 'contributing/coverage' },
          ],
        },
      ],
    }),
  ],
});
