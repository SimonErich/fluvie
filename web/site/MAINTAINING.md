# Maintaining the Fluvie landing site

This is the marketing landing at https://fluvie.dev. It is an Astro project in
`web/site`. The page is built from small components under `src/components/`,
composed in `src/pages/index.astro`. The package list and the lesson gallery are
**derived from the source tree at build time**, so they cannot drift: adding or
removing a package or a lesson updates the page automatically, and the build fails
if the curated copy gets out of step (see "The data-driven content" below).

This doc tells you exactly what to touch when the project changes. The docs site
(docs.fluvie.dev, Astro Starlight in `web/docs`) and the demo (demo.fluvie.dev,
Flutter web) are separate. Do not edit them from here.

> For copy, new sections, links, or accessibility, the `sync-website` skill
> (`.claude/skills/sync-website/SKILL.md`) walks the editorial reconcile. This doc
> is the manual reference behind it.

## Run it locally

```sh
cd web/site
npm ci          # first time, or after package-lock.json changes
npm run dev     # http://localhost:4321, hot reload
npm run build   # writes the static site to web/site/dist
npm run preview # serve the built dist as production would
```

The build runs from `web/site`, and the data loader reads the monorepo two levels
up. Run the build from the project root (`web/site`), not elsewhere.

## What lives where

- `src/pages/index.astro` composes the page from the section components.
- `src/components/*.astro` are the sections (Nav, Hero, Idea, Triggers, Proof,
  Start, Reel, Crew, Oss, Seats, Ai, Router, Footer) plus `Backdrop.astro`
  (skip link, film grain, ambient blurs). One section per file, small and atomic.
- `src/layouts/Base.astro` is the document shell: `<head>` (meta, Open Graph,
  fonts, favicon), the root theme variables, the backdrop, and the page script.
- `src/styles/global.css` is the global stylesheet (resets, focus styles,
  keyframes, the reduced-motion and small-screen media queries).
- `src/scripts/landing.ts` is the page behaviour (nav, the hero scrubber, the
  gallery filter, the trigger lever, copy buttons, hover styles, the seat
  counter). It is a small progressive-enhancement script, no framework.
- `src/data/content.json` is the curated marketing copy for the data-driven
  regions: each package's role/one-liner/icon, and each lesson's title/blurb.
- `src/data/site.ts` loads `content.json`, reads the package and lesson **set**
  from the source tree, and exports `packages`, `lessons`, and
  `packageCountWord`. It throws (fails the build) if the curated set and the
  on-disk set disagree.
- `public/` holds static assets served at the site root: the logos and `og.png`.
- `website-structure.md` is the design brief: structure, sections, motion,
  microinteractions, hover and focus, accessibility. It defines intent; the
  components implement it. Keep them in step.

## The data-driven content

`src/data/site.ts` is the guardrail. At build time it:

- reads every `packages/<name>/pubspec.yaml` that is not `publish_to: none`, and
- reads every `example/lib/lessons/NN_*.dart`,

then compares that set against `content.json`. If a published package or a lesson
has no entry, or `content.json` lists one that no longer exists, the build throws
with a clear message. So the page can never silently omit or invent a package or a
lesson.

`Crew.astro` renders the package rows from `packages`; `Reel.astro` renders the
gallery from `lessons` (it serialises them into a `gal-data` JSON tag that
`landing.ts` reads to build the tiles). The headline count ("Eight MIT packages")
comes from `packageCountWord`.

## When a new lesson or example is added

A new `example/lib/lessons/NN_*.dart` means a new gallery tile.

1. Add a `lessons` entry to `src/data/content.json`: `key` (NN), `title`, a
   one-sentence `teaches` line, a `category` (`basics`/`data`/`media`/`audio`/
   `code`/`transitions`), and `clip` `false` (or `true` once it has a real clip).
   Keep the wording aligned with `website-structure.md`.
2. `npm run build`. The build fails until every lesson on disk has an entry.
3. If the category is new, add a matching filter button to `Reel.astro`.
4. `npm run dev` and check the tile appears, the filter includes it, and the
   `aria-label` describes the lesson.

## When a package changes

The package list reflects the published `packages/*` automatically (currently
eight, including `fluvie_mobile_encoder` and `fluvie_web_encoder`).

- New package: add a `packages` entry to `content.json` (`key`, `role`, a one-line
  `line`, an `icon` HTML/SVG snippet, and `primary`/`badge` only for `fluvie`),
  then `npm run build`. The build fails until every published `packages/*` has an
  entry.
- Renamed or removed package: update or drop its entry. The build fails until the
  curated set matches disk.
- Keep the brief's ecosystem list (`website-structure.md`) in step.

## When copy or links change

- Tagline, hero, feature copy: edit the relevant component. Obey the voice rules:
  short sentences, second person, no em-dashes, none of the banned words (seamless,
  robust, leverage, powerful as filler, effortless, blazing, unleash).
- Canonical links to keep working: docs.fluvie.dev and its deep-links
  (getting-started/installation, getting-started/your-first-video,
  getting-started/core-concepts, guides/ai-and-mcp, guides/rendering-on-a-server,
  reference/cheatsheet), demo.fluvie.dev, mcp.fluvie.dev, the GitHub repo, and each
  pub.dev package page.
- After any link edit, do a quick dead-link pass. The page is small, so a manual
  scan is enough.

## Optional: embed real gallery clips

The tiles show animated gradient posters by default and link to
`https://demo.fluvie.dev/#NN`; no video files are required for the page to look
complete. To embed real footage:

1. Register the key in `pubspec.yaml` under `render:examples` and in the `KEYS`
   array of `tool/web/regenerate_gallery.sh`.
2. Run `melos run web:gallery` (Flutter + ffmpeg) to render `build/<key>.mp4` and
   encode `web/site/public/media/<key>.{mp4,webm,poster.webp,gif}`. To re-encode
   only, run `tool/web/regenerate_gallery.sh --encode-only`.
3. In `Reel.astro`/`landing.ts`, swap that tile's gradient poster for the
   progressive `<video>` (webm, mp4) with an `<img>` GIF fallback that points at
   `/media/<key>.*`, and mark the lesson `true`.
4. Eyeball the clip: clean loop, under the size budget, captioned. Commit the media
   together with the change. ffmpeg bytes differ machine to machine, so regenerate
   all affected assets on one machine in one go.

## How to deploy

- **Production (fluvie.dev) is GitHub Pages**, served from the
  `SimonErich/fluvie_website` repo. This monorepo's `website` workflow
  (`.github/workflows/website.yml`) builds `web/site` and pushes the static output
  to that repo, where a one-line Pages workflow publishes it. The cross-repo push
  needs a `FLUVIE_WEBSITE_TOKEN` secret; without it the build still runs and
  uploads the site as a workflow artifact, and the deploy step skips.
- **Local preview**: `npm run build` then `npm run preview` in `web/site`. There
  is no container for the landing; the old `fluvie-web` nginx image was retired
  when fluvie.dev moved to GitHub Pages.

## Release checklist

Run before shipping a landing change:

- [ ] `npm run build` is green (the data guardrail passes).
- [ ] Voice pass: short sentences, second person, no em-dashes, no banned words.
- [ ] All seven packages present and linked. Install version string current.
- [ ] Every gallery tile has a caption, an `aria-label`, and a demo link.
- [ ] All canonical links resolve (docs deep-links, demo, mcp, repo, pub.dev).
- [ ] `prefers-reduced-motion` honored. Keyboard tab order and visible focus
      checked. Contrast acceptable.
- [ ] `website-structure.md` reconciled with the page.
- [ ] Open-source emphasis intact (MIT, inspect, self-host, no lock-in, contribute).

## Where to next

- The design brief: [`website-structure.md`](website-structure.md).
- The gallery encoder: `tool/web/regenerate_gallery.sh`.
- The sync skill: `.claude/skills/sync-website/SKILL.md`.
- Deploy details: `deploy/README.md`.
