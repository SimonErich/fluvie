# Phase 6 — The Timeline Panel

**Goal:** The centerpiece: a real timeline under the canvas with per-element tracks, animation bars, keyframe diamonds, trigger links, build markers, and a scrubbing playhead the canvas follows exactly. End state: retime an entrance by dragging its bar, drag a build marker to change the click-through, scrub the slide, and present the result.

**Depends on:** Phases 3 and 4.

**Produces:** `packages/fluvie_editor/lib/src/timeline/**` and `lib/src/widgets/**` (the track timeline); introspection alignment in `packages/fluvie/lib/src/composition/introspection/`.

**Definition of done:** the collapsible bottom panel shows a time ruler, one track per element in layers order, phase-colored animation bars that move and trim, keyframes that add/move/delete, visible and editable trigger links, and Stop markers in parity with `compileSlidePlans`; the playhead is shared with the canvas; the quick Animate panel in the inspector writes to the same document the timeline edits; gate green.

---

## The data flow (build this exactly)

The timeline reads the **document** — the only home of keyframes, authored triggers, and steps. `introspectTimeline` supplies resolved absolute `FrameSpan`s for bar geometry (after trigger resolution); keyframe diamonds plot inside a bar by interpolating the document's `t` values across the introspected span. Edits dispatch commands; the slide re-derives; introspection re-runs; the timeline re-renders. Strictly one direction.

## Epics

### Epic 6.1 — fluvie: introspection keyed by element id
1. `introspectTimeline` output gains lookups by spec element `id` (alongside anchor/key/widget), so timeline rows join document elements to resolved spans without heuristics. Display-only: the spec stays scene-relative; absolutes exist only in introspection.
2. **Acceptance:** unit tests mapping spans to ids across chained triggers and multi-scene decks. **Commit.**

### Epic 6.2 — The track timeline widget
1. A scrubbable multi-track widget (custom painter): a seconds ruler with a draggable playhead, one named track per element grouped to match layers order, zoomable, collapsible per scene. Built under `src/widgets/`, domain-free. `// obers_ui upstream candidate`.
2. Animation bars per track, colored by phase (enter/emphasis/exit), showing their easing as a small curve; drag a bar to retime (`SetAnimationDelay`), drag an edge to change duration (`SetDuration`).
3. **Acceptance:** interaction unit tests (drag = retime, edge = duration, zoom math); goldens of a populated timeline. **Commit.**

### Epic 6.3 — Keyframe editing
1. Keyframe diamonds inside bars from the Phase 4 `keyframes` form; click a track at the playhead to add, drag to move, delete; value and per-segment easing edit in the inspector.
2. The quick Animate panel (inspector) — add an entrance/emphasis/exit preset, duration, easing, trigger — writes bars onto the same timeline; two views of one truth.
3. **Acceptance:** mutation and undo tests for add/move/delete; render goldens before and after a retime; a quick-panel-to-timeline consistency test. **Commit.**

### Epic 6.4 — Trigger links and build markers
1. Trigger links drawn between bars (`whenEnds`/`whenStarts`/`previous`); drag from one bar to another to create or retarget a trigger; offsets edit inline.
2. Build markers: vertical dividers on the ruler splitting the slide into click steps, in exact parity with `compileSlidePlans`; drag to reorder steps, insert and remove markers (Stop membership edits); `validateStepPlan` runs live and marks violations (cross-element triggers inside a step) on the offending bars.
3. **Acceptance:** trigger edit round-trip tests; step-lane parity tests against `compileSlidePlans`; a live-validation test surfacing a violation. **Commit.**

### Epic 6.5 — Scrub and transport
1. The shared playhead: one `LivePlaybackController` per active slide; scrubbing calls `seek`, the canvas reflects the exact frame; play/pause and play-from-here via `playRange`; a loop over a selected range; Space respects the presenter's step semantics when the panel is closed.
2. Switching slides swaps the controller; the timeline and canvas never disagree on the frame.
3. **Acceptance:** controller integration tests with a driven clock; a scrub test asserting canvas and ruler agree frame-exactly. **Commit.**

---

## Testing
`packages/fluvie_editor/test/timeline/`; introspection additions in `packages/fluvie/test/composition/introspection/`. Bar/keyframe/marker math is pure and exhaustively unit-tested; the panel gets goldens; parity with the presenter's compiler is pinned.

## Guardrails and side effects
- The timeline displays resolved absolute frames but always writes scene-relative values — the absolute-times deck constraint holds.
- Introspection stays read-only; no editing API leaks into fluvie.
- An empty timeline explains itself in one line and offers to add an animation — empty is never a dead end.

## Commit checkpoints
One commit per epic (6.1 to 6.5).
