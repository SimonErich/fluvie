import { defineConfig } from 'astro/config';

// The marketing site at fluvie.dev. Pure static output (no UI framework): the
// page is built from small .astro components, the package list and lesson
// gallery come from the monorepo at build time (src/data/site.ts), and the
// interactivity is one bundled script. The build (`astro build`) runs in the
// main repo's CI; the fluvie_website repo serves the result.
export default defineConfig({
  site: 'https://fluvie.dev',
});
