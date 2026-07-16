# Phase 7 — The Slides App, Examples, Docs and Polish

**Goal:** Ship it. The deployable `apps/slides` shell for web, desktop, and mobile, loading a `.fluvie` file through `fluvie_ai` on web and Dart-defined presentations everywhere, plus example presentations, the documentation folder in the house voice, and a final verification pass.

**Depends on:** Phases 1 through 6.

**Produces:** `apps/slides/**`, example presentations, `packages/fluvie_presenter/documentation/**`, README, CHANGELOG, and CI for the app and package.

**Definition of done:** the app runs on web, desktop, and mobile; on web it opens a local `.fluvie` file via `fluvie_ai` and presents it; the example presentations present correctly with passing goldens; the docs are complete, cross-linked, split beginner and advanced, and read like a person wrote them; the gate is green; a clean checkout builds and runs.

---

## Epics

### Epic 7.1 — The slides app
1. `apps/slides`: a minimal shell. Entry is close to `void main() => runApp(SlidesApp())`. It presents a `Video` with `FluvieSlides`.
2. Web: open a local `.fluvie` file by picker and drag and drop, parse it with `fluvie_ai` into a `Video`, then present. Handle parse errors with a clear, friendly message.
3. Desktop and mobile: pick a file, or run a bundled example. Sensible file handling per platform.
4. **Acceptance:** the app runs on web and desktop; opening a sample `.fluvie` presents it; a bad file shows a helpful error. **Commit.**

### Epic 7.2 — Example presentations (the tutorial)
1. A handful of Dart-defined presentations that teach the tool from simple to a full talk: plain slides, builds with `Stop`, speaker notes with highlights, a media-heavy slide, and one real end-to-end talk using most features.
2. Each runs in the app and is covered by a golden on a representative slide.
3. **Acceptance:** all examples present; goldens pass. **Commit.**

### Epic 7.3 — Documentation
1. Fill `packages/fluvie_presenter/documentation/` per the structure in the build prompt. Getting started, guides, advanced, reference. Split beginner and advanced, link across the seam, end pages with where-to-next.
2. Voice: warm, clear, a little funny, short sentences, show the code first, no em-dashes, none of the marketing vocabulary, no AI tells. Pull snippets from the real examples so they stay compiling.
3. Root README with a short description, a five-line example, install, a feature list, links to the docs and the app, and badges. CHANGELOG in Keep a Changelog style.
4. **Acceptance:** dartdoc builds clean; the docs read well out loud; README and CHANGELOG present. **Commit.**

### Epic 7.4 — CI and final verification
1. CI for the presenter package and app: format, analyze (fatal), custom_lint, test with coverage gated, and a web build job for the app. A screenshot or golden smoke for the examples.
2. Performance pass: preview generation throughput, smooth stepping on a heavy deck, memory under many slides.
3. Final check on a fresh clone: bootstrap, gate, docs build, run the app on web and desktop, open the speaker window, present an example end to end.
4. **Acceptance:** CI green; the fresh-clone check passes. Update `PROGRESS.md` to complete. **Commit.**

---

## Testing
`apps/slides/test/` and the example goldens. File loading is tested with a fake `fluvie_ai` loader and sample data. The examples are golden-tested. Keep everything deterministic.

## Guardrails and side effects
- The app is a thin shell. Presentation logic stays in the package. The app only loads content and hosts `FluvieSlides`.
- The web file path depends on `fluvie_ai`. Keep that dependency at the app layer, not in the presenter package.
- Do not let the docs drift into marketing or AI cadence. Keep them human and to the point.

## Commit checkpoints
One commit per epic (7.1 to 7.4). The final commit marks the presenter ready and updates `PROGRESS.md`.
