# Phase 2 — Canvas Round-Trip

**Goal:** The first real editing: select, move, resize, and rotate elements on the canvas; save and reopen the `.fluvie`; present the edited deck. End state: rearrange the demo deck, save it, reload it, and present it — the editor's whole pipeline proven end to end.

**Depends on:** Phase 1.

**Produces:** `packages/fluvie_editor/lib/src/selection/**`, `.../gizmo/**` (interaction logic), `.../widgets/**` (the reusable gizmo overlay), `.../interaction/**`; file open/save/present flows in `apps/slides`.

**Definition of done:** click, shift-click, and marquee selection work against document geometry; the transform gizmo moves, resizes (aspect and center modifiers), and rotates with snap modifiers, writing undoable `transform` mutations where one drag is one undo step; open → edit → save → reopen round-trips with only the edit changed; Present hands the current spec to `FluvieSlides`; a perf budget test pins drag responsiveness; gate green.

---

## Epics

### Epic 2.1 — Selection model and hit testing
1. A pure geometry engine: hit tests and marquee intersection run against document transforms (fraction space mapped to canvas pixels), rotation-aware, never against the widget tree. Intrinsic-sized elements report their laid-out size through an editor-mode-only geometry reporter injected at derive time.
2. Selection state in its own provider: click selects, shift-click adds and removes, empty-canvas click deselects, drag on empty canvas draws a marquee (obers_ui `OiSelectionOverlay`), Escape clears.
3. A selected element shows a bounding box; a hovered unselected element shows a thin highlight outline. Zoom-to-selection joins the zoom commands now that a selection exists.
4. **Acceptance:** exhaustive unit tests for hit and marquee math including rotated bounds; widget tests for the click flows and hover outline. **Commit.**

### Epic 2.2 — The transform gizmo
1. An overlay with eight resize handles and a rotation zone just outside the corners, painted in canvas space, hit-tested first. Built inside the editor under `src/widgets/` (domain-free, `// obers_ui upstream candidate`).
2. Drag the body to move; arrow keys nudge (Shift for the larger step). Corner handles resize both axes, side handles one; Shift keeps aspect; Alt resizes around center. Rotate snaps to common angles with Shift. Live dimensions and angle show near the cursor. Cursors match the handle direction.
3. Every gesture writes `transform` mutations through the command layer; a drag coalesces into one undo step; a multi-selection drags as one group.
4. During a drag, render the moving element with a transform-only fast path and commit the document mutation on release — the perf budget test pins this.
5. **Acceptance:** gizmo geometry unit tests (resize anchoring, rotation, aspect and center modifiers); Alchemist goldens of gizmo states; undo-coalescing tests; the perf budget test. **Commit.**

### Epic 2.3 — File round-trip in the app
1. Open a `.fluvie` into the editor through the existing loader path (`parseFluvieJson`); Save and Save-as write `toJson` (the File System Access API where the browser has it, download fallback otherwise; a file dialog on desktop); a dirty guard prompts before discarding unsaved changes.
2. The title bar shows the file name and a quiet saved indicator.
3. **Acceptance:** an integration test opening a fixture, moving one element, saving, reopening, and asserting the documents differ only by that transform; unsaved-guard widget test. **Commit.**

### Epic 2.4 — Present from the editor
1. A Present button hands the current spec's built `Video` to the existing `FluvieSlides` flow (step 0 only until Phase 4 brings steps); closing returns to the editor with state intact.
2. **Acceptance:** a journey test: edit an element's position, present, and assert the presented slide shows the element at its new position. **Commit.**

---

## Testing
`packages/fluvie_editor/test/selection/`, `test/gizmo/`, `test/interaction/`; app flows in `apps/slides/test/`. The geometry engines are pure and exhaustively unit-tested; interaction gets widget tests; visuals get goldens.

## Guardrails and side effects
- Hit-testing and selection geometry always come from the document, never from render objects; the geometry reporter is the single sanctioned exception (intrinsic sizes flow one way, into a provider).
- The document mutates only through commands; no widget writes the spec directly.
- Rotated-bounds math must match `Placed`'s rendering exactly — one shared fraction-space mapper, tested once, used everywhere.

## Commit checkpoints
One commit per epic (2.1 to 2.4).
