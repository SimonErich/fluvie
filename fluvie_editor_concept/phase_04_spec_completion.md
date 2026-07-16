# Phase 4 — Spec Completion

**Goal:** Close the serialization gap for good: every rich element, all animation presets, multi-stop keyframes, build steps, speaker notes, and shared-element pairing become representable in `.fluvie`. This phase is a parallel track — it only needs Phase 1 and touches fluvie, fluvie_presenter, and fluvie_cli, not the editor UI.

**Depends on:** Phase 1 (runs in parallel with Phases 2 and 3).

**Produces:** full element and preset coverage in `packages/fluvie/lib/src/serialization/`; a `keyframes` animation form; `deckFromSpec` and `validateStepPlan` in `packages/fluvie_presenter`; printer and schema parity in `packages/fluvie_cli`; an ADR in `documentation/`.

**Definition of done:** a rich `.fluvie` (chart, code, mermaid, keyframed motion, steps, notes) presents with full stepping and speaker notes; the coverage-matrix test proves every spec-representable element (the full fluvie widget set) and preset round-trips digest-stable; compile parity holds between widget-authored and spec-authored decks; gate green.

---

## Epics

### Epic 4.1 — ADR: steps, notes, and digest semantics
1. A short ADR deciding the exact spec shape for build steps and notes (scene-level `steps` markers referencing element ids versus alternatives), where notes text lives, and precisely which keys count into the render digest (presentation-affecting data does; `editor` block does not).
2. The decision gates epics 4.3 and 4.4; the format version and migration hook from Phase 1 absorb any later change.
3. **Acceptance:** the ADR page exists in `documentation/`, reviewed against both the presenter's compile model and the editor's authoring flows. **Commit.**

### Epic 4.2 — fluvie: element codec wave 2 and the preset sweep
1. Serialize the rest: `Typewriter` (no codec today), the remaining `Counter` props, `Code` (language, theme, reveal, highlights, diff, and line focus that can change across build steps), `Chart.bar/pie/donut/line/area/scatter` (series data, axes, legend, reveal), `Markdown`, `Mermaid`, `Terminal` (lines, prompt, chrome), `WebView`/`Html` (viewport), rich `Text` (styled spans, lists, links — a fluvie text capability this epic adds), and `sharedKey` for `SharedElement` pairing.
2. Every remaining animation preset joins the preset table.
3. Schema, validation, printer, and corpus fixtures land with each codec.
4. **Acceptance:** a coverage-matrix test asserting every spec-representable element type and preset has a codec, round-trips, and builds to a digest-stable `Video` (the editor's insert palette is a subset of this set by construction); per-codec render goldens. **Commit.**

### Epic 4.3 — fluvie: `keyframes` in `AnimationSpec`
1. A fourth animation form serializing the existing `Keyframe` model: an ordered list of stops (`t` plus any of opacity, x, y, scale, rotation, blur, color) with per-segment easing — a superset of `from`/`to`/`fromTo`.
2. **Acceptance:** round-trip tests; render-equivalence goldens against the same animation authored as widgets. **Commit.**

### Epic 4.4 — fluvie_presenter: steps and notes from the spec
1. Per the ADR, scene `steps` and `notes` enter the spec (engine-ignored: a rendered video never pauses). `deckFromSpec(spec)` in the presenter wraps the built scenes' elements in `Stop`s and injects `SpeakerNotes`, feeding the existing `compileSlidePlans` and `compileNotes` unchanged.
2. `validateStepPlan(spec)` surfaces `StepCompileError`s (cross-element or beat triggers inside a step, relative times) without presenting — the editor calls it live at edit time.
3. **Acceptance:** compile-parity tests — a widget-authored deck and its spec twin produce identical plans and notes; validation tests for each rejected construct. **Commit.**

### Epic 4.5 — Printer, schema, and corpus sweep
1. The fluvie_cli Dart printer emits every new form (elements, keyframes, steps as presenter-wrapping comments or constructs per the ADR); the JSON schema and `spec_validation` are complete; the conformance corpus covers a maximal fixture.
2. **Acceptance:** corpus round-trip json → dart → build digest equality across the full fixture set. **Commit.**

---

## Testing
`packages/fluvie/test/serialization/` (codec waves, keyframes, coverage matrix), `packages/fluvie_presenter/test/spec/` (parity, validation), `packages/fluvie_cli/test/` (printer). Everything here is pure and unit-testable; goldens pin render equivalence.

## Guardrails and side effects
- fluvie stays presentation-agnostic: `steps` and `notes` are data it stores and ignores; only the presenter interprets them. No fluvie import of fluvie_presenter, ever.
- Chart/Code/Mermaid codecs are large surfaces — one element per commit inside the epic if needed, but schema/validator/printer always move together.
- Digest semantics from the ADR are pinned by regression tests before anything depends on them.

## Commit checkpoints
One commit per epic (4.1 to 4.5).
