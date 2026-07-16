# Phase 7 — Themes, Masters, and Templates

**Goal:** Deck-wide design systems: theme tokens that restyle everything bound to them, master layouts with placeholders, and a template gallery for new decks. End state: start a deck from a template, switch its theme, and watch the whole deck restyle.

**Depends on:** Phase 4 (spec) and Phase 3 (UI).

**Produces:** `ThemeSpec` and `MasterSpec` in `packages/fluvie/lib/src/serialization/`; `packages/fluvie_editor/lib/src/{theme,masters,templates}/**` and `lib/src/widgets/**` (the gradient editor); the new-deck flow in `apps/slides`.

**Definition of done:** theme tokens (palette, type scale, spacing, default animation settings) serialize in the spec and elements can bind to them; masters apply to slides, and editing a master updates its slides; the gradient editor ships; built-in templates create decks that adopt the current theme; gate green.

---

## Epics

### Epic 7.1 — fluvie: `ThemeSpec` and token binding
1. Serialize a deck theme into the spec: a palette, a type scale, spacing, and default animation settings. Elements may reference tokens (`"color": {"token": "accent"}`) instead of literals; the builder resolves tokens at build time; literals keep working everywhere.
2. Schema, validation, printer, corpus in step. Token resolution counts into the render digest (a theme change re-renders).
3. **Acceptance:** token-resolution unit tests and goldens; round-trip; a mixed literal-and-token fixture. **Commit.**

### Epic 7.2 — fluvie: `MasterSpec`
1. Masters as reusable slide layouts with named placeholders (title, body, media); a scene can adopt a master and fill its placeholders, with scene-level overrides; a scene without a master is fully freeform.
2. Editing a master's definition changes every adopting scene at build time — no copies.
3. **Acceptance:** master-application unit tests (placeholder fill, override precedence, no-master passthrough); goldens. **Commit.**

### Epic 7.3 — Theme editing UX
1. A theme panel: edit tokens with live preview across the deck; color fields lead with the theme palette, then recents, then the full picker.
2. The gradient editor (stops bar with draggable stops, per-stop color, angle or radial) lands here as the token and background fill editor — obers_ui has none. Built under `src/widgets/`. `// obers_ui upstream candidate`.
3. A few built-in themes to start from.
4. **Acceptance:** theme-switch goldens across a fixture deck; gradient editor unit and golden tests; token binding from the inspector is undoable. **Commit.**

### Epic 7.4 — Masters editing and the template gallery
1. A master edit mode (enter from the slide panel; the canvas edits the master; adopting slides badge themselves); apply/detach a master per slide.
2. The template gallery in `apps/slides`: new-from-template and insert-template-slide, organized by purpose; templates are spec-based decks that adopt the current theme on insert.
3. **Acceptance:** placeholder-fill journey tests; master-edit-propagates test; new-deck-from-template journey ending in Present. **Commit.**

---

## Testing
`packages/fluvie/test/serialization/` (theme, master), `packages/fluvie_editor/test/{theme,masters,templates}/`, app journey in `apps/slides/test/`. Token resolution and master application are pure build-time transforms — exhaustive unit tests first, goldens for the visual truth.

## Guardrails and side effects
- The layering holds: templates give a starting deck, masters keep slides consistent, tokens keep styling consistent, freeform stays available — none of the four forces the others.
- Token references are spec data (digest-relevant); theme editor panel state is `editor` data.
- Masters must not break element identity: placeholder-filled elements get stable ids on adoption, tested through undo and reordering.

## Commit checkpoints
One commit per epic (7.1 to 7.4).
