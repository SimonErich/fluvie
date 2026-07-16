# Phase 8 — Smart Blocks, Auto-Animate, and Release Polish

**Goal:** The finishing set: smart-layout blocks, auto-animate between slides, the speaker-notes editor, the export menu, and the documentation. End state: author a full deck — smart blocks for structure, auto-animated transitions, notes — then present it and export it in every format.

**Depends on:** Phases 5, 6, and 7.

**Produces:** `packages/fluvie_editor/lib/src/{blocks,autoanimate,notes}/**`; export flows in `apps/slides`; the fluvie_editor documentation set.

**Definition of done:** smart blocks arrange and re-balance their children and nest; auto-animate matches elements across consecutive slides and previews the morph; notes edit per slide and per step and show in the speaker window; export offers `.fluvie`, Dart source, and a rendered video; docs complete and gated; the fresh-clone script covers the editor; gate green.

---

## Epics

### Epic 8.1 — Smart-layout blocks
1. Blocks for v1: row, column, grid, bullet/feature list, two-column split, title-with-body — parameterized `Group`s with spacing, alignment, and distribution controls that re-balance when children are added, removed, or resized. Blocks nest.
2. Freeform stays the default; dragging a child out of a block releases it; block membership lives in the `editor` block, the arranged transforms in the spec (a block is sugar over real geometry, so decks render everywhere).
3. **Acceptance:** reflow unit tests per block type (add/remove/resize/nest); goldens per block; a release-from-block test. **Commit.**

### Epic 8.2 — Auto-animate
1. A per-slide switch: match elements to the previous slide by `sharedKey` (explicit) or by id (same element duplicated across slides), generate `SharedElement` pairings, and preview the morph. Link and unlink affordances per element.
2. The presenter and file render play the same morph — one machinery, three surfaces.
3. **Acceptance:** pairing unit tests (explicit key beats id, unmatched elements fall back to the authored transition); morph goldens; presenter parity test. **Commit.**

### Epic 8.3 — The speaker-notes editor
1. A notes editor under the canvas (or a tab), bound to the Phase 4 notes spec: scene-level by default, per-step overrides when the timeline's build markers are present, text plus highlight bullets.
2. What you author is what the speaker window and notes panel show — pinned by a parity test through `compileNotes`.
3. **Acceptance:** round-trip tests; a step-override editing test; the presenter-display parity test. **Commit.**

### Epic 8.4 — Export and the documentation set
1. The export menu: `.fluvie` (save-as), Dart source (the fluvie_cli printer), and render-to-video through fluvie's pipeline; a PDF/image-per-slide export from settled final states via the preview machinery.
2. The fluvie_editor documentation set in the house voice (getting started, canvas, timeline, themes, shortcuts reference, FAQ), compiled snippets, wired into the docs gates; verify each earlier phase shipped its page and backfill any gap.
3. The fresh-clone script gains an editor smoke (open Edit mode headless, assert it boots); the website sync reflects the editor.
4. **Acceptance:** export journey tests; docs lint and snippet gates green; fresh-clone script green. **Commit.**

---

## Testing
`packages/fluvie_editor/test/{blocks,autoanimate,notes}/`; export journeys in `apps/slides/test/`. Block reflow and pairing are pure engines with exhaustive unit tests; morphs and blocks get goldens.

## Guardrails and side effects
- A block is never a layout prison: its children hold real spec transforms at all times, so ungrouping or opening the file elsewhere loses nothing.
- Auto-animate never invents motion for unmatched elements — they use the slide's authored transition.
- Docs ship with capabilities (house rule); this phase's docs epic is the backstop, not the plan.

## Commit checkpoints
One commit per epic (8.1 to 8.4).
