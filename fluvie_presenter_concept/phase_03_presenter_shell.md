# Phase 3 — Presenter Shell (stage, input, fullscreen)

**Goal:** The thing you actually present with. The `FluvieSlides` viewer built on obers_ui, full input handling (keyboard, click, touch, presenter remotes), fullscreen, and black or white screen. Flat design, no Material.

**Depends on:** Phases 1 and 2.

**Produces:** `packages/fluvie_presenter/lib/src/shell/**` and the public `FluvieSlides` widget.

**Definition of done:** a navigable presentation with every input method; fullscreen works on each platform (guarded per platform); black and white screens toggle; a slide counter and progress indicator that can be hidden; goldens for the stage and chrome; widget tests for the input map.

---

## Epics

### Epic 3.1 — The stage
1. `FluvieSlides(video, {showSidebar = false, showNotes = false, startFullscreen = false, theme})` renders the current slide via `SlideView`, fitting the video's aspect into the viewport with letterboxing (contain the authored size). Flat background, obers_ui chrome.
2. A minimal, hideable slide counter and progress indicator.
3. **Acceptance:** golden for the stage at a sample slide, and for the letterboxing at two viewport aspect ratios.

### Epic 3.2 — Input mapping
1. A single `PresentationShortcuts` using Flutter Shortcuts and Actions. Bind: next (Right, Down, Space, PageDown, Enter, tap, swipe left), back (Left, Up, Shift+Space, PageUp, swipe right), first and last (Home, End), jump (digits then Enter), fullscreen (F), exit or close overlay (Esc), overview (O), speaker window (S), black screen (B or period), white screen (W).
2. Presenter remotes send PageUp and PageDown and sometimes F5 and period. Map those too.
3. Touch: tap advances, swipe navigates, on mobile and web.
4. **Acceptance:** widget tests firing each intent and asserting the controller action.

### Epic 3.3 — Fullscreen and screen blanking
1. A `FullscreenController` with platform implementations: the Fullscreen API on web, window fullscreen on desktop, immersive mode on mobile. Behind one interface.
2. Black and white screen overlays that hold the current position.
3. **Acceptance:** guarded platform tests for the controller; golden for the black and white overlays.

### Epic 3.4 — Minimal config surface
1. Honor `showSidebar`, `showNotes`, `startFullscreen`, and `theme`. Nothing more elaborate.
2. A simple `PresenterTheme` on top of obers_ui tokens (colors, type) with a sensible flat default.
3. **Acceptance:** tests that the flags hide or show the right chrome and that startup fullscreen triggers.

---

## Testing
`packages/fluvie_presenter/test/shell/`. Input mapping and config are widget-tested. Fullscreen is guarded per platform. Stage and overlays get goldens.

## Guardrails and side effects
- No Material or Cupertino imports in the presenter UI. Use obers_ui.
- Keep the shell thin. It wires input to the controller and renders the stage. No stepping logic here.
- Make focus handling robust so keyboard input works immediately on load, including on web.

## Commit checkpoints
One commit per epic (3.1 to 3.4).
