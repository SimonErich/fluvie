# Phase 4 — Sidebar and Slide Previews

**Goal:** A togglable sidebar that lists slides with scaled-down previews you can click to jump. Previews are hybrid: rendered live and lazily, then cached as images, generated off the critical path, with a way to pre-generate them all.

**Depends on:** Phases 2 and 3.

**Produces:** `packages/fluvie_presenter/lib/src/sidebar/**` and a preview cache service.

**Definition of done:** the sidebar toggles; previews render lazily, cache, and show a placeholder until ready; clicking a preview jumps to that slide at step 0; the current slide is highlighted; an overview grid reuses the previews; tests for the cache and lazy generation, plus a sidebar golden.

---

## Epics

### Epic 4.1 — Preview render and cache service
1. A `SlidePreviewService` that renders a slide's final state into a scaled-down `RepaintBoundary`, captures a `ui.Image`, and caches it keyed by slide identity and a content hash.
2. Lazy and off the critical path: generate after first paint, throttle concurrency, cap the cache, evict sensibly. Regenerate when content changes.
3. Expose `pregenerateAll()` for warming the cache, and a placeholder for not-yet-rendered previews.
4. **Acceptance:** tests that a preview generates once and is served from cache next time, that concurrency is capped, and that a content change invalidates the entry. Use a fake renderer where possible.

### Epic 4.2 — Sidebar UI
1. A togglable obers_ui sidebar listing slides with their previews, index labels, and the current slide highlighted.
2. Click a preview to `jumpToSlide` at step 0. Keyboard focus and scroll follow the current slide.
3. **Acceptance:** widget test that clicking a preview jumps; golden for the sidebar with a few previews and the current one marked.

### Epic 4.3 — Overview grid
1. An overview mode (the O shortcut) that shows all slides as a grid of previews to pick from, reusing the cache.
2. Esc closes it; picking a slide navigates and closes.
3. **Acceptance:** widget test for open, pick, and close; golden for the grid.

---

## Testing
`packages/fluvie_presenter/test/sidebar/`. Cache logic is unit-tested with a fake renderer. Sidebar and grid get goldens. Keep preview generation deterministic in tests.

## Guardrails and side effects
- Previews must never block presenting. Generate them lazily and asynchronously, and always show something in the meantime.
- Watch memory with many slides. Cap and evict the image cache, and prefer scaled sizes.
- Reuse one cache for the sidebar and the overview grid. Do not render previews twice.

## Commit checkpoints
One commit per epic (4.1 to 4.3).
