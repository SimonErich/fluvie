# Build fluvie_editor (Claude Code starter prompt)

Build the fluvie slides editor, end to end, without stopping for confirmation. The
concept and all decisions live in this folder: read every `phase_01` … `phase_08` file
before you start, then execute them in order (Phase 4 may run interleaved after
Phase 1 — it only touches fluvie, fluvie_presenter, and fluvie_cli).

## What you are building

A visual presentation editor: a Figma-grade canvas with direct manipulation, a
contextual inspector, slides and layers panels, a real timeline (bars, keyframes,
trigger links, build markers), themes/masters/templates, smart-layout blocks, speaker
notes, autosave — editing `.fluvie` files that the existing presenter presents and the
existing render pipeline exports. New package `packages/fluvie_editor`; spec extensions
in `packages/fluvie`; an Edit mode in `apps/slides`.

## Decisions already made — do not re-litigate

1. **The extended VideoSpec IS the document.** The editor edits spec objects through an
   immutable `EditorDocument` wrapper. No parallel model. `SpecCapabilities` gates the
   insert palette to what the spec can save.
2. **Spec v2 in fluvie**: element `id` + `transform` (fractions) + `Placed` widget;
   `keyframes` animation form; element coverage grown to the full widget set; scene
   `steps` + `notes` (presenter-consumed, engine-ignored); `sharedKey` for
   SharedElement; a first-class `editor` block preserved verbatim and excluded from
   `digest()`. Version field + migration hook from day one; v1 files keep working.
3. **Tri-artifact lockstep**: every spec change lands codec + schema/validation + the
   fluvie_cli Dart printer in one epic, enforced by a conformance corpus test in the
   gate from Phase 1.
4. **Commands + OiUndoStack**: sealed typed commands, inverse captured at apply;
   coalescing (drags, typing, multi-select groups) is editor merge policy implemented
   through OiUndoStack's groupId + merge callback; selection not undoable.
5. **Hit-testing against the document** (fraction space), never the widget tree; one
   geometry mapper shared by `Placed`, the gizmo, and snapping; an editor-mode-only
   geometry reporter for intrinsic sizes.
6. **The timeline reads the document**; `introspectTimeline` supplies resolved absolute
   spans for display; edits write scene-relative values.
7. **Chrome is flat obers_ui** (no Material). Missing pieces (spectrum color picker,
   gradient editor, track timeline, transform gizmo, snapping overlay) are built inside
   `fluvie_editor/lib/src/widgets/`, domain-free, each marked
   `// obers_ui upstream candidate`.
8. **Web-first editing** in `apps/slides`; desktop follows for free; mobile stays
   present-only.
9. Deferred by choice: AI generation, real-time collaboration. The id-based document
   plus command stack must not design them out.

## How to work

- **Test-first, always.** Red → green → refactor for every change; pure engines
  (document, commands, hit-testing, snapping, reflow, pairing) get exhaustive unit
  tests; visuals get Alchemist goldens (Linux baseline); flows get widget/journey
  tests.
- **The gate before every commit**: `CI=true melos run gate` (format, analyze fatal,
  custom_lint, ≥97% coverage on every package under `packages/` and `apps/slides`),
  plus `melos run test:goldens --no-select` when goldens changed. Never leave the tree
  broken.
- **Conventional Commits, one commit per epic.** Human-like messages, no AI trailer.
- **Track progress in `PROGRESS.md`** at the repo root: check off epics, and record
  every decision the phase files left open (numbered, with the reasoning) the way the
  presenter build did.
- **Docs ship with capabilities**: each phase's user-visible feature adds its
  documentation page (house voice: short sentences, active, second person, no
  em-dashes, no marketing words, `## Where to next` at the end, compiled snippets via
  `#docregion`).
- File budget ≤ ~200 lines per production file; one primary public type per file;
  layering law (fluvie ⟂ presenter ⟂ editor; barrels only).
- If you hit something genuinely undecided, pick the option most consistent with the
  decisions here, the phase files, and the fluvie spec; write it down in PROGRESS.md;
  keep going.

## Definition of done

Every phase's Definition of done met; the whole gate green on a fresh clone
(`tool/verify_fresh_clone.sh` extended with the editor smoke); the demo path works by
hand: open the slides app → New from template → author a deck (elements, animations on
the timeline, build markers, notes, theme switch) → autosave survives a reload →
Present with the speaker window → export `.fluvie`, Dart, and a rendered video.
