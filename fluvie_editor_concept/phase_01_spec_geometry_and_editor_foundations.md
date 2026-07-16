# Phase 1 — Spec Geometry and Editor Foundations

**Goal:** Give the `.fluvie` spec free element placement and stable identity, and stand up `packages/fluvie_editor` with a read-only canvas that renders a spec inside a new Edit mode in `apps/slides`. End state: a positioned `.fluvie` deck opens in Edit mode pixel-identical to how it presents, and you can zoom and pan around it.

**Depends on:** the fluvie package and fluvie_presenter (as shipped).

**Produces:** spec extensions inside `packages/fluvie/lib/src/serialization/` and a `Placed` element in `packages/fluvie/lib/src/elements/`; `packages/fluvie_editor` (skeleton: `lib/src/document/**`, `lib/src/canvas/**`, and `lib/src/widgets/**` — the home for every domain-free widget later phases build); an Edit mode entry in `apps/slides`.

**Definition of done:** the workspace bootstraps with the new package; the gate is green (format, analyze fatal, custom_lint, ≥97% coverage, goldens); a `.fluvie` file with positioned elements loads in Edit mode and renders exactly as the presenter renders it; specs without positions still center-stack (v1 files keep working); the spec conformance corpus test runs in the gate from here on.

---

## The architecture (state this exactly, it governs every later phase)

- **The extended VideoSpec IS the document.** The editor edits spec objects through a thin immutable `EditorDocument` wrapper. No parallel document model, no doc-to-spec codec. Round-trip is identity.
- Editor-only metadata (names, lock, guides, panel state) lives in a first-class top-level `editor` block: preserved verbatim through `fromJson`/`toJson`, excluded from `digest()` so renames never invalidate render caches.
- Every spec change lands three artifacts in one epic: the JSON codec, the JSON schema + `spec_validation.dart` known keys, and the fluvie_cli Dart printer. A conformance corpus test enforces this from Phase 1 onward.
- `fluvieSpec: 2` with the version 1 read path kept; a version field and migration hook exist from day one.

## Epics

### Epic 1.1 — fluvie: `id`, `transform`, and the `Placed` element
1. Add two reserved element keys to `ElementSpec`: `id` (a stable string, auto-minted on load when absent) and `transform` (`{x, y}` as fractions of the scene, optional `{w, h}` fractions, optional `rotation` in degrees, `anchor` defaulting to center).
2. Add a public `Placed` widget in `packages/fluvie/lib/src/elements/`: fractional `Align` plus `FractionallySizedBox` when `w`/`h` are given (intrinsic size otherwise) plus `Transform.rotate`. `buildElement` wraps any element carrying a `transform` in `Placed`; an element without one keeps today's center-stack. `Placed` exposes its fraction-to-pixel mapping as a public fluvie export — the ONE geometry mapper the editor's gizmo and snapping import, so rendering and hit-testing can never drift.
3. Add scene `layout: canvas | stack` with `stack` as the default, so version 1 files parse and render unchanged.
4. Keep schema defs, `spec_validation.dart` known-key sets, and the fluvie_cli Dart printer in step, in this same epic.
5. **Acceptance:** codec round-trip unit tests for `id`/`transform`; goldens for a positioned scene next to a stacked one; a digest-stability test; the printer emits `Placed`-style Dart for positioned elements. **Commit.**

### Epic 1.2 — fluvie: the `editor` block and the conformance corpus
1. Add `editor` to `VideoSpec.knownKeys`. `fromJson` preserves the whole subtree verbatim (`Map<String, Object?>? editorData`); `toJson` re-emits it; `unknownSpecProps` skips inside it. `digest()` hashes engine keys only — the `editor` block never affects it. Pin that with a regression test.
2. Build the conformance corpus: a folder of `.fluvie` fixtures that every gate run round-trips (json → spec → json equality) and cross-checks (json → build digest equals printed-Dart → build digest).
3. **Acceptance:** corpus test wired into the gate and green; the digest-discipline regression test passes. **Commit.**

### Epic 1.3 — fluvie_editor: package skeleton and workspace wiring
1. Add `packages/fluvie_editor` to the pub workspace and Melos scopes (coverage:gate list, test:goldens scope). Copy the presenter's `analysis_options.yaml` include, `dart_test.yaml` tags, and Alchemist `flutter_test_config.dart`.
2. Dependencies: `fluvie`, `fluvie_presenter`, `obers_ui` (git pin), `flutter_riverpod`, `meta`; dev deps mirror the presenter. `publish_to: none` while obers_ui is a git dep.
3. Barrel `lib/fluvie_editor.dart` compiles with placeholder exports.
4. **Acceptance:** `melos bootstrap`, analyze, and the full gate green on the skeleton. **Commit.**

### Epic 1.4 — fluvie_editor: `EditorDocument`
1. An immutable wrapper over `VideoSpec`: an id index, typed mutations (`replaceElement`, `insertElement`, `removeElement`, `moveElement`, `addScene`, `removeScene`, `reorderScene`, `setEditorMeta`), each returning a new document. Pure Dart, no widgets.
2. A command layer: sealed `EditorCommand` types with `apply(document)` and a captured inverse, hosted on obers_ui's `OiUndoStack` through its `groupId` + `merge` callback. The editor's merge policy (same command type + element id + property coalesces drags and typing; one group per multi-select gesture) is implemented in that callback — it is editor code, not a stack feature. Selection is not undoable; undo re-selects the affected ids.
3. Dirty tracking and an editor-side document digest (includes the `editor` block, unlike the render digest).
4. **Acceptance:** exhaustive unit tests: every mutation, undo and redo of each, coalescing of a simulated drag, id stability. **Commit.**

### Epic 1.5 — Read-only canvas and the Edit mode
1. `EditorCanvas` renders one scene of the derived `Video` through fluvie's `LivePlayer` with a held `LivePlaybackController` (`hold(frame)`), inside `OiPinchZoom` for zoom and pan. The slide sits on a soft neutral backdrop, centered. Zoom commands from day one: fit to screen, exact levels (50/100/200), zoom to a point.
2. Per-slide derivation keyed by a content digest, with `Anchor` instances cached per element id across re-derives.
3. `apps/slides` gains an Edit mode: a third home state beside the picker and the presenter, reachable from the picker, opening a bundled deck or a `.fluvie` file read-only.
4. **Acceptance:** a widget test asserting the canvas held frame matches the presenter's render of the same slide (golden); zoom and pan tests; the demo deck opens in Edit mode. **Commit.**

---

## Testing
`packages/fluvie/test/serialization/` grows the transform/id/editor-block suites and the corpus; `packages/fluvie_editor/test/document/` and `test/canvas/`. The document and command layers are pure and get exhaustive unit tests without pumping widgets. Canvas rendering gets goldens against presenter output.

## Guardrails and side effects
- fluvie learns geometry (`Placed`) but nothing about editing; fluvie_editor imports only barrels (fluvie, fluvie_presenter, obers_ui).
- Version 1 specs must keep parsing and rendering byte-for-byte; `layout: stack` is the default everywhere.
- The two digests (render digest excluding `editor`, document digest including it) are deliberately distinct; never merge them.
- File budget ≤ ~200 lines; pure engines (document, commands, derive) live apart from widgets.

## Commit checkpoints
One commit per epic (1.1 to 1.5).
