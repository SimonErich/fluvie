# Phase 3 — Authoring Surface

**Goal:** Create decks from scratch: the tool group, a contextual inspector, the slides and layers panels, thumbnails, and the floating selection toolbar. End state: start from a blank deck, build and style a three-slide deck, and present it — the first-milestone demo.

**Depends on:** Phase 2.

**Produces:** `packages/fluvie_editor/lib/src/{tools,inspector,panels,chrome}/**` and `lib/src/widgets/**` (the color picker); codec wave 1 in `packages/fluvie/lib/src/serialization/`; preview exports from the fluvie_presenter barrel.

**Definition of done:** the editor shell is the familiar shape (top bar, left slides/layers panel, canvas, right inspector) on obers_ui split panes; every insertable element can be placed, styled through the inspector, and saved; slide thumbnails render lazily through the presenter's preview service; gate green; a blank-to-presented journey test passes.

---

## Epics

### Epic 3.1 — fluvie: element codec wave 1
1. Serialize `Shape.rect`, `Shape.circle`, `Shape.line`, `Shape.path`, `Arrow`, `Connector`, and `Clip` (source, trim, fit, volume, poster — poster is a small fluvie `Clip` addition) — each with `transform` support; complete the `Image` codec (fit, corner radius, frame, and crop — crop is a fluvie `Image` addition this epic makes); add the next tranche of animation presets to the preset table.
2. Schema, validation, and the Dart printer stay in step; the corpus grows a fixture per new element.
3. A `SpecCapabilities` registry in fluvie_editor gates the insert palette by what the spec can express, so the editor never offers an element it cannot save.
4. **Acceptance:** per-codec round-trip unit tests and build goldens; capabilities registry unit tests. **Commit.**

### Epic 3.2 — The tool system
1. Tools with shortcuts and cursors: select/move (default, Escape always returns here), hand (Space to hold), text, shape (rectangle, ellipse, line, arrow; Shift constrains), media (image or video from a file), element (menu for the richer set). Each tool sets its cursor.
2. Click or drag to place with sensible defaults; the text tool drops straight into inline editing on the canvas, and double-clicking existing text re-enters it; placing dispatches an `AddElement` command with a minted id.
3. Media arrives three ways: the media tool's file picker, dragging a file onto the canvas (the app's existing drop-target pattern), or a lightweight asset panel listing the media already used in the deck for reuse.
4. **Acceptance:** unit tests for the tool state machine; a widget test per insert flow including the canvas drop; Escape-returns-to-select test. **Commit.**

### Epic 3.3 — The inspector
1. The right panel on obers_ui `OiPropertyGrid`: with nothing selected, slide size and background (solid, gradient, image, animated fluvie backgrounds); with a selection, transform (exact x/y/w/h/rotation/opacity), arrange, and style sections; per-type sections registered by element type.
2. Numeric fields accept typing, stepping, dragging, and simple math (`960/2`, `+10`) on top of `OiNumberInput`; every control dispatches a command, so every change is undoable. Type-specific sections include a small data-grid editor for charts (usable once their codec lands; `SpecCapabilities` gates insertion until then).
3. A real spectrum color picker (hue/saturation area, alpha, hex, theme palette on top) built under `src/widgets/` — obers_ui's `OiColorInput` has presets, hex, and alpha, but no spectrum area. `// obers_ui upstream candidate`.
4. **Acceptance:** widget tests that inspector edits mutate the spec and undo; color picker unit and golden tests; a nothing-selected background-editing test. **Commit.**

### Epic 3.4 — Slides panel and layers panel
1. fluvie_presenter exports its preview machinery (`SlidePreviewService`, `PreviewRenderHost`, `SlidePreviewFrame`) from the barrel, so the editor reuses the lazy, capped thumbnail cache instead of duplicating it.
2. The left panel: a slide strip with live thumbnails, add, duplicate, delete, and drag-reorder of scenes; the current slide marked; right-click actions match the panel controls.
3. A Layers tab for the current slide: the element list in z-order with rename (inline edit), visibility and lock toggles (lock and name live in the `editor` block), and drag to reorder z-index.
4. **Acceptance:** presenter export test; thumbnail invalidation-on-edit test; reorder, rename, lock, and hide tests through the command layer. **Commit.**

### Epic 3.5 — Floating toolbar and the small stuff
1. A small toolbar just above the selection with the two or three most useful actions per element type (color, font size, alignment, delete), positioned by obers_ui `OiFloating`.
2. The considered details the concept calls out: a tooltip (name plus shortcut, short delay) on every icon-only control; empty states that invite an action (a new slide, an empty deck); micro-interactions (a soft settle when an element lands, a gentle offset on duplicate, a clear focus ring in text editing); the deck name in the top bar renames inline.
3. **Acceptance:** widget tests per element type for the toolbar; a tooltip presence sweep over the chrome's icon controls; empty-state and rename tests. **Commit.**

---

## Testing
`packages/fluvie_editor/test/{tools,inspector,panels,chrome}/`; codec tests in `packages/fluvie/test/serialization/`. Inspector sections and tools get widget tests against the command layer; panels get goldens; the phase closes with the blank-deck-to-presented journey test.

## Guardrails and side effects
- The insert palette is gated by `SpecCapabilities` — nothing insertable may be unsaveable.
- Lock and name never affect the render digest (they live in the `editor` block); visibility does affect rendering and belongs to the spec (Phase 5 formalizes it — until then hide is editor-preview-only and marked as such in the UI).
- The presenter's exported preview service stays presenter-owned; the editor consumes it, never forks it.

## Commit checkpoints
One commit per epic (3.1 to 3.5).
