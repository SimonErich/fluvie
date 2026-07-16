# Phase 6 — Speaker Window (multi-window and web popup)

**Goal:** The presenter view in a separate window. It shows the current speaker notes, a live preview of the next state, and the highlight bullets down the side, and it stays in sync with the main window. Multi-window on desktop, a synced popup on web, a graceful fallback, and an in-app panel on mobile.

**Depends on:** Phases 2, 3, and 5.

**Produces:** `packages/fluvie_presenter/lib/src/speaker/**` and a `PresentationSyncChannel` with platform implementations.

**Definition of done:** the speaker window opens on desktop (multi-window) and web (popup), shows notes, the next-state preview, and highlights, and follows the main window's position; a fallback tells you to open a URL when a window cannot open; mobile shows the in-app notes panel instead; tests for the sync channel (with a fake) and the next-state computation, plus a golden for the speaker layout.

---

## Layout of the speaker view

Three regions, flat obers_ui:
- A live preview of the **next state**, meaning what the next input produces (the next step, or the next slide at step 0).
- The current speaker notes text.
- The highlight bullets, filling the window height down the right side, as a quick glance list.
Plus a clock or elapsed timer and current and next slide indicators.

## Epics

### Epic 6.1 — `PresentationSyncChannel`
1. An abstract channel that broadcasts the current `(slideIndex, stepIndex)` and playback state between windows, and lets either window request navigation.
2. Web implementation over `BroadcastChannel`. Desktop implementation over the multi-window messaging API (`flutter_multi_window` or `desktop_multi_window`), registering plugins per window as required.
3. **Acceptance:** tests with a fake channel that a position change on one end arrives on the other, and that a navigation request round-trips.

### Epic 6.2 — Next-state preview
1. Compute the next position from the controller and render it in a mini `LivePlayer` held at that state, reusing the step model.
2. Handle the end of the deck (no next state) cleanly.
3. **Acceptance:** unit test for next-position computation across steps and slide boundaries; widget test that the mini preview renders the expected state.

### Epic 6.3 — Speaker view and window opening
1. The speaker view widget composing the next-state preview, the notes, the highlights, and the timer.
2. Open it: a `window.open` popup to the speaker route on web, a new window on desktop, an in-app full-screen panel on mobile. The S shortcut toggles it.
3. Fallback: when no window can open, show the URL and a short instruction to open it in a second window.
4. **Acceptance:** golden for the speaker layout; guarded tests for opening on web and desktop; a fallback test.

### Epic 6.4 — Sync in practice
1. Wire the main window and speaker window to the same position over the channel. Either can advance. Keep them consistent, including instant seek on back and jump.
2. **Acceptance:** an integration-style test with two controllers bridged by a fake channel that stay in lockstep through a sequence of navigations.

---

## Testing
`packages/fluvie_presenter/test/speaker/`. The channel and next-state logic are unit-tested with fakes. Window opening is guarded per platform. The speaker layout gets a golden.

## Guardrails and side effects
- Community multi-window plugins give each window its own engine and isolate, so do not assume a shared Riverpod container. Sync only through the channel.
- The speaker window is a convenience, not a requirement. Everything must still work with only the main window.
- Keep the same notes source of truth as Phase 5. Do not recompute notes differently here.

## Commit checkpoints
One commit per epic (6.1 to 6.4).
