# Phase 5 — Canvas Pro and Workflow

**Goal:** Precision and safety: snapping, guides, and rulers; grouping, ordering, locking, hiding, aligning; context menus, the command palette, and the clipboard; autosave and crash recovery. End state: a precisely laid-out, grouped slide built with smart guides, driven from the palette, that survives a killed tab.

**Depends on:** Phase 3 (uses Phase 4's codecs where present).

**Produces:** `packages/fluvie_editor/lib/src/{snapping,arrange,commands,persistence,deck}/**` and `lib/src/widgets/**` (the snapping overlay); `GroupSpec` and `visible` in `packages/fluvie/lib/src/serialization/`; autosave and recents in `apps/slides`.

**Definition of done:** smart guides appear and snap while dragging (edges, centers, equal spacing, manual guides from rulers, grid when on, hold-to-disable); group/ungroup, z-order, lock/hide, align/distribute all work on multi-selections and reflect in the layers panel; right-click menus and the command palette expose every editor command with shortcuts; copy/paste re-mints ids; autosave recovers after a crash; gate green.

---

## Epics

### Epic 5.1 — fluvie: `Group` and `visible` in the spec
1. A `Group` container element (children plus a shared `transform`) and a `visible` flag on elements — both render-affecting, so they live in the spec and count into the digest. Lock stays editor-block metadata.
2. Schema, validation, printer, corpus in step.
3. **Acceptance:** codec round-trips; nested-group render goldens; hidden-element render test. **Commit.**

### Epic 5.2 — Snapping engine, rulers, and guides
1. A pure snapping engine: candidate lines from other elements' edges and centers, the slide edges and center, equal-spacing hints for three or more elements, manual guides, and the optional grid; a tolerance in canvas pixels mapped back to fractions; a modifier key disables snapping for a fine nudge.
2. Rulers on request; drag from a ruler to place a manual guide (stored in the `editor` block); the smart-guide overlay pulses briefly on snap.
3. Built under `src/widgets/` where generic. `// obers_ui upstream candidate`.
4. **Acceptance:** exhaustive engine unit tests (each candidate type, tolerance, disable modifier); overlay goldens; guide persistence round-trip. **Commit.**

### Epic 5.3 — Arrange operations
1. Group and ungroup (entering a group edits a child), bring/send forward/backward/front/back, lock and hide, align and distribute relative to the selection or the slide — all as commands on multi-selections.
2. The layers panel reflects groups as subtrees and all toggles live.
3. **Acceptance:** a document-mutation plus undo test per operation; a group-drag test moving members together; id stability through group/ungroup. **Commit.**

### Epic 5.4 — Context menus, command palette, and clipboard
1. Right-click menus (obers_ui `OiContextMenu`): element (cut/copy/paste/duplicate/delete, order, group, lock, hide, add animation), canvas (paste, select all, slide actions), slide strip (duplicate, delete, move) — short, grouped, shortcuts shown.
2. The command palette (obers_ui `OiCommandBar`): every editor command searchable, recents on top, shortcuts wired through `OiShortcutScope` so the hints are real bindings.
3. Clipboard: copy/paste/duplicate within and across slides with id re-minting (fresh ids, preserved internal references).
4. **Acceptance:** command registry unit tests (every command reachable from palette and menu); paste id-collision tests; shortcut dispatch tests. **Commit.**

### Epic 5.5 — Deck management
1. Named slide sections in the slide strip: group slides, collapse a section, reorder a section as a unit (section structure lives in the `editor` block).
2. Copy and paste whole slides, within the deck and across decks (the clipboard carries spec JSON, ids re-minted on paste).
3. A recent-files list on the open screen (local storage on the web, preferences on desktop); deck rename and Save-a-copy alongside Save-as.
4. **Acceptance:** section grouping/collapse/reorder tests; a cross-deck slide paste test (two documents, ids re-minted); recents and rename round-trip tests. **Commit.**

### Epic 5.6 — Autosave and recovery
1. Debounced autosave of the working document (IndexedDB on the web, a sidecar file on desktop), version-stamped; a recovery prompt on next open when a newer autosave than the file exists; Save clears it.
2. A quiet saved indicator in the top bar; long operations show unobtrusive progress.
3. **Acceptance:** fake-clock autosave tests; a recovery journey test (edit, simulate crash, reopen, recover). **Commit.**

---

## Testing
`packages/fluvie_editor/test/{snapping,arrange,commands,persistence,deck}/`; app-level recovery journey in `apps/slides/test/`. The snapping engine and clipboard re-minting are pure and get exhaustive unit tests.

## Guardrails and side effects
- Snapping math shares the public fluvie fraction-space mapper from Phase 1 — no second geometry implementation.
- `visible` is spec data (render-affecting, in the digest); `locked` and guides are `editor` data (never in the render digest). Tests pin both directions.
- Palette and menu shortcuts must be the same bindings the keyboard uses — one registry, no drift between hint and behavior.

## Commit checkpoints
One commit per epic (5.1 to 5.6).
