---
name: sync-website
description: Reconcile the marketing landing (web/landing/index.html), its gallery clips (web/landing/media/), the six-package ecosystem list, the getting-started, the design brief (web/landing/website-structure.md), and web/landing/MAINTAINING.md with the current repo. Use after adding or changing an example/lesson, after a package is added/renamed/removed, after a canonical link or copy change, or after any change the public site at fluvie.dev should reflect.
---

# sync-website

The landing at fluvie.dev is a single static file (`web/landing/index.html`) plus
committed gallery clips under `web/landing/media/`. It drifts the moment a lesson,
package, or canonical link changes. This skill walks the full reconcile so nothing
is missed. The page has no build step; you edit `index.html` directly.

Obey the voice rules everywhere: short sentences, second person, no em-dashes, none
of the banned words (seamless, robust, leverage, powerful as filler, effortless,
blazing, unleash). The full reference for every step is `web/landing/MAINTAINING.md`.

## Steps

1. **Diff the world against the page.** List the lessons
   (`example/lib/lessons/NN_*.dart`), the six published packages (`fluvie`,
   `fluvie_cli`, `fluvie_lints`, `fluvie_ai`, `fluvie_api`, `fluvie_mcp`), and the
   canonical links. Compare each to what `web/landing/index.html` shows. Note every
   add, rename, removal, and copy change.
2. **Update the gallery tiles.** The tiles are generated from a `GAL` array in the
   inline `<script>` of `index.html` (`["NN","Title","what it teaches","category",
   isRealClip]`), each rendered as an animated gradient poster. For a new or changed
   lesson, add or edit its `GAL` row (and a `filterBtn` if the category is new). Keep
   the wording aligned with the lesson list in `web/landing/website-structure.md`.
3. **Optional, embed a real clip.** Only when a tile should show real footage instead
   of its gradient poster: register the key in `pubspec.yaml` `render:examples` AND in
   the `KEYS` array of `tool/web/regenerate_gallery.sh`, run `melos run web:gallery`
   (Flutter plus ffmpeg) to render with Impeller and encode
   `web/landing/media/<key>.{mp4,webm,poster.webp,gif}` (or `--encode-only` to
   re-encode), then swap that tile's poster for the progressive `<video>`(webm, mp4) →
   `<img>` GIF fallback and mark the lesson `true`. Regenerate all affected media on
   ONE machine in one pass (ffmpeg bytes differ across machines).
4. **Update the ecosystem list.** All six packages present, each with its one-line
   role and best path (a pub.dev page or a doc deep-link). Fix renames and removals.
5. **Update getting-started inline.** Keep the flow real: prereqs (Flutter 3.44+,
   ffmpeg on PATH for rendering only), `flutter create`, add the `fluvie` dependency,
   `dart pub global activate fluvie_cli`, write the lesson-01 video, preview by
   scrubbing, render with `fluvie render <key> --out ...`, and the determinism payoff
   (run twice, byte-identical frames). Bump the install version only on a major change.
6. **Reconcile the design brief.** Mirror any structural change into
   `web/landing/website-structure.md` (sections, hierarchy, motion, microinteractions,
   hover and focus, accessibility). The brief carries NO colors or fonts; do not add
   any. If the page gained a section, the brief gains its description.
7. **Accessibility and reduced motion.** Confirm keyboard reachability, visible focus,
   contrast, and `prefers-reduced-motion` handling on every clip. No gratuitous
   motion. Every clip is captioned.
8. **Update MAINTAINING.md** if the process itself changed (a new asset type, a new
   `COPY` line in `deploy/landing.Dockerfile`, a new script knob).
9. **Verify the built artifact.** `docker compose -f deploy/docker-compose.yml up
   --build fluvie-web`, open http://localhost:8082, click through the gallery, and
   check the links resolve.
10. **Commit.** Land the HTML, the regenerated `web/landing/media/` assets, the
    `regenerate_gallery.sh` and `pubspec.yaml` key edits, the brief, and MAINTAINING.md
    together, so the diff is coherent. Use a human-like commit message with no AI
    trailer (per repo policy), for example `docs(web): add lesson NN tile and refresh
    gallery clips`.

## Template

A gallery tile (progressive enhancement: video first, GIF fallback, poster for no-JS
and reduced motion):

```html
<figure class="tile">
  <video class="tile-media" autoplay loop muted playsinline preload="none"
         poster="media/<key>.poster.webp"
         aria-label="Lesson NN: <Title>, <what animates>">
    <source src="media/<key>.webm" type="video/webm">
    <source src="media/<key>.mp4"  type="video/mp4">
    <img src="media/<key>.gif" alt="Lesson NN: <Title>, <what animates>">
  </video>
  <figcaption>
    <h3>NN . <Title></h3>
    <p><One sentence: what this lesson teaches.></p>
    <a href="https://demo.fluvie.dev/#<key>">Scrub it live</a>
  </figcaption>
</figure>
```

> Re-encode media with `tool/web/regenerate_gallery.sh --encode-only` (ffmpeg only).
> Re-render the source with `melos run web:gallery` (Flutter plus ffmpeg) only when
> the lesson code changed. Full process: `web/landing/MAINTAINING.md`.
