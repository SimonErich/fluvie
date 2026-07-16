# Phase 1 — Foundation and fluvie Live Playback

**Goal:** Add `fluvie_presenter` to the monorepo and give fluvie the two things the presenter needs: a clock-driven live player and public access to the resolved timeline. End state: you can play a one-scene `Video` live, seek it, and hold it at any frame.

**Depends on:** the fluvie package (this repo).

**Produces:** `packages/fluvie_presenter` (skeleton), `apps/slides` (skeleton), and clean additions inside `packages/fluvie` for live playback and timeline introspection.

**Definition of done:** the workspace bootstraps with the new package and app; the gate is green; fluvie's `LivePlayer` and timeline introspection have unit and widget tests; a demo plays, pauses, seeks, and holds a single scene live; fluvie contains no presentation logic.

---

## Epics

### Epic 1.1 — Workspace wiring
1. Add `packages/fluvie_presenter` and `apps/slides` to the Melos workspace and pub workspace. Path dependency on `fluvie`. Add `obers_ui` from pub.dev. Reuse the root `analysis_options.yaml` (very_good_analysis + custom_lint) and the shared golden and test config.
2. Presenter `pubspec.yaml` with riverpod and the presenter's deps. The app depends on the presenter and (later) on `fluvie_ai`.
3. Barrel `packages/fluvie_presenter/lib/fluvie_presenter.dart` compiles (empty exports placeholder).
4. **Acceptance:** `melos bootstrap`, `melos analyze`, `melos test` green on the skeleton. **Commit.**

### Epic 1.2 — fluvie: `LivePlayer` (clock-driven playback)
1. In `packages/fluvie/lib/src/rendering/`, add a `LivePlayer` widget plus a `LivePlaybackController` that drives the existing `FrameProvider` with a `Ticker` instead of the capture stepper. Support `play`, `pause`, `seek(frame)`, `hold`, `playRange(start, end)` then stop, `rate`, and current-frame notifications.
2. Reuse the same `TimeScope` and per-frame rebuild path as capture, but in live mode (the Phase 4 `RenderModeContext` live branch). Live mode may use real platform views and real video playback.
3. Keep it decoupled: `LivePlayer` knows nothing about slides or steps.
4. **Acceptance:** widget tests that pump the ticker and assert the frame advances, seek lands exactly, hold stops, and `playRange` stops at the end frame. **Commit.**

### Epic 1.3 — fluvie: resolved-timeline introspection
1. Expose a public `TimelineIntrospector` (or extend the Phase 3 resolver output) that, given a `Video`, returns: ordered scenes with their absolute start and end frames, and per-element resolved windows keyed by a stable identity (the `Anchor`, or a widget key when present).
2. Provide a lookup from a widget in the tree to its resolved window, so a consumer can find where any element's entrance sits on the timeline.
3. Pure and deterministic. No IO.
4. **Acceptance:** unit tests resolving a multi-scene `Video` into scene bounds and element windows; a lookup test that finds a known element's entrance frame. **Commit.**

### Epic 1.4 — Presenter skeleton and smoke
1. In the presenter package, add a minimal `LiveScenePlayer` wrapper over fluvie's `LivePlayer` and a placeholder `FluvieSlides` widget that plays a single scene end to end.
2. A smoke widget test in the presenter that pumps a one-scene `Video` and asserts it renders and advances.
3. Seed `PROGRESS.md` with Phase 1 status.
4. **Acceptance:** smoke test green; a runnable example in the app shows one scene playing live. **Commit.**

---

## Testing
`packages/fluvie/test/rendering/live_player_test.dart`, `packages/fluvie/test/timing/introspection_test.dart`, and a presenter smoke test. Use fake tickers for deterministic playback tests.

## Guardrails and side effects
- Additions to fluvie must be clean and minimal. If a change would put presentation logic into fluvie, it belongs in the presenter instead.
- Live mode and capture mode share the timing engine but differ in the clock. Do not fork the timeline resolution.
- Keep the presenter's dependency on fluvie behind a thin wrapper so future fluvie changes are easy to absorb.

## Commit checkpoints
One commit per epic (1.1 to 1.4).
