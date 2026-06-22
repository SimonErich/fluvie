---
name: sync-website
description: Reconcile the marketing landing (the Astro site in web/site) with the repo: the package list and lesson gallery (data-driven via web/site/src/data/content.json + site.ts), the section copy and links, the design brief (web/site/website-structure.md), and gallery clips (web/site/public/media). Use after adding or changing an example/lesson, after a package is added/renamed/removed, after a canonical link or copy change, or after any change the public site at fluvie.dev should reflect.
---

# sync-website

The landing at fluvie.dev is an Astro project in `web/site` (sections under
`src/components/`, composed in `src/pages/index.astro`). The package list and the
lesson gallery are derived from the source tree at build time by `src/data/site.ts`,
so they cannot silently drift: `npm run build` fails if the curated copy in
`src/data/content.json` and the on-disk packages and lessons disagree. Edit the
components for copy and sections; edit `content.json` for the data-driven regions.
The full reference is `web/site/MAINTAINING.md`; this skill is the editorial
walkthrough behind it.

Obey the voice rules everywhere: short sentences, second person, no em-dashes, none
of the banned words (seamless, robust, leverage, powerful as filler, effortless,
blazing, unleash).

## Steps

1. **Diff the world against the page.** Run `npm run build` in `web/site`:
   `src/data/site.ts` fails the build if any published `packages/*` or any
   `example/lib/lessons/NN_*.dart` has no entry in `content.json`, or if
   `content.json` lists one that no longer exists. Then check the copy, the
   getting-started flow, and the canonical links by eye in `src/components/`.
2. **Update the gallery.** `Reel.astro` renders the gallery from the `lessons` in
   `src/data/content.json` (`key`, `title`, `teaches`, `category`, `clip`). For a
   new or changed lesson, edit its entry. Add a filter button to `Reel.astro` only
   if the category is new. Keep the wording aligned with `website-structure.md`.
3. **Optional, embed a real clip.** Tiles show gradient posters by default. To show
   real footage: register the key in `pubspec.yaml` `render:examples` AND in the
   `KEYS` array of `tool/web/regenerate_gallery.sh`, run `melos run web:gallery`
   (Flutter plus ffmpeg) to render and encode
   `web/site/public/media/<key>.{mp4,webm,poster.webp,gif}` (or `--encode-only` to
   re-encode), wire the clip into `Reel.astro`/`landing.ts`, and mark the lesson
   `clip: true`. Regenerate all affected media on ONE machine in one pass (ffmpeg
   bytes differ across machines).
4. **Update the package list.** `Crew.astro` renders from the `packages` in
   `content.json` (`key`, `role`, one-line `line`, `icon`, and `primary`/`badge`
   only for `fluvie`). Add, rename, or drop the entry to match disk; the build
   fails until the curated set matches.
5. **Reconcile the design brief.** Mirror any structural change into
   `web/site/website-structure.md` (sections, hierarchy, motion, microinteractions,
   hover and focus, accessibility). The brief carries no colors or fonts; do not add
   any. If the page gained a section, the brief gains its description.
6. **Accessibility and reduced motion.** Confirm keyboard reachability, visible
   focus, contrast, and `prefers-reduced-motion` handling on every clip. No
   gratuitous motion. Every clip is captioned.
7. **Update MAINTAINING.md** if the process itself changed (a new asset type, a new
   data field, a new script knob).
8. **Verify the built artifact.** `npm run build` then `npm run preview` in
   `web/site`, open the preview URL, click through the gallery, and check the links
   resolve.
9. **Commit.** Land the component edits, `content.json`, any regenerated
   `web/site/public/media/` assets, the `regenerate_gallery.sh`/`pubspec.yaml` key
   edits, and the brief together, so the diff is coherent. The `website` workflow
   deploys fluvie.dev on push to `main`. Use a human-like commit message with no AI
   trailer (per repo policy), for example `docs(web): add lesson NN tile and refresh
   the gallery`.

## The content entries

Add a lesson or a package by editing `src/data/content.json`, not by hand-writing
HTML: `Crew.astro` and `Reel.astro` render from the data, and `site.ts` checks it
against the source tree.

```json
{
  "packages": [
    { "key": "fluvie", "role": "<role>", "line": "<one line>",
      "icon": "<svg>", "primary": true }
  ],
  "lessons": [
    { "key": "NN", "title": "<Title>", "teaches": "<one sentence>",
      "category": "basics", "clip": false }
  ]
}
```

> Re-encode media with `tool/web/regenerate_gallery.sh --encode-only` (ffmpeg only).
> Re-render the source with `melos run web:gallery` (Flutter plus ffmpeg) only when
> the lesson code changed. Full process: `web/site/MAINTAINING.md`.
