# Phase 5 — Speaker Notes and the Notes Panel

**Goal:** The `SpeakerNotes` widget and the bottom notes panel. Notes attach to a scene and optionally to a step, carry full text plus highlight bullets, are invisible in the presentation, and surface for the current position.

**Depends on:** Phases 2 and 3.

**Produces:** `packages/fluvie_presenter/lib/src/notes/**` and the public `SpeakerNotes` widget.

**Definition of done:** notes attach at scene level with optional per-step overrides and surface correctly for the current `(slide, step)`; the panel toggles; tests for the notes compiler and a golden for the panel.

---

## Epics

### Epic 5.1 — `SpeakerNotes` widget
1. `SpeakerNotes({String? text, List<String> highlights = const []})`. It renders nothing in the presentation. It attaches notes to the enclosing scene by default, or to a step when placed inside a `Stop` (per-step override).
2. Multiple `SpeakerNotes` in one scene merge predictably; a per-step note overrides or augments the scene default when that step is active. Document the merge rule.
3. **Acceptance:** widget test that the widget is invisible on stage; unit test that scene and step notes are collected with the right scope.

### Epic 5.2 — Notes compiler
1. Given a `Video`, produce notes per `(slide, step)`: the scene default plus any active per-step override, with the highlight lists resolved.
2. Pure and deterministic.
3. **Acceptance:** unit tests for scene-only notes, per-step overrides, and the merge behavior across steps.

### Epic 5.3 — Notes panel
1. A togglable obers_ui bottom panel showing the current position's notes: the text and the highlight bullets. Updates as you navigate.
2. Hidden by default when `showNotes` is false. On mobile this panel is also where speaker content lives, since there is no separate window.
3. **Acceptance:** widget test that the panel follows navigation; golden for the panel with text and highlights.

---

## Testing
`packages/fluvie_presenter/test/notes/`. The compiler is unit-tested. The panel gets a golden and a navigation test.

## Guardrails and side effects
- `SpeakerNotes` must be truly invisible on stage and must not affect layout or timing.
- Keep the merge rule for scene versus step notes simple and documented, so authors are never surprised.
- The compiler output feeds both this panel and the speaker window in Phase 6. Share one source of truth.

## Commit checkpoints
One commit per epic (5.1 to 5.3).
