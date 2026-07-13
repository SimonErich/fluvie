# fluvie_presenter — build progress

The running log for the presenter build (`fluvie_presenter_concept/` phases 1–7).
One checkbox per epic; decisions that the concept left open are recorded under
[Decisions](#decisions) as they are made.

## Phase 1 — Foundation and fluvie live playback

- [x] 1.1 Workspace wiring (`packages/fluvie_presenter`, `apps/slides`, obers_ui)
- [x] 1.2 fluvie: `LivePlayer` (clock-driven playback)
- [x] 1.3 fluvie: resolved-timeline introspection
- [x] 1.4 Presenter skeleton and smoke

## Phase 2 — Stepping engine

- [x] 2.1 `Stop` widget
- [x] 2.2 Step compiler
- [x] 2.3 `PresentationController`
- [x] 2.4 Slide rendering with steps

## Phase 3 — Presenter shell

- [x] 3.1 The stage
- [x] 3.2 Input mapping
- [x] 3.3 Fullscreen and screen blanking
- [x] 3.4 Minimal config surface

## Phase 4 — Sidebar and slide previews

- [x] 4.1 Preview render and cache service
- [x] 4.2 Sidebar UI
- [x] 4.3 Overview grid

## Phase 5 — Speaker notes

- [x] 5.1 `SpeakerNotes` widget
- [x] 5.2 Notes compiler
- [x] 5.3 Notes panel

## Phase 6 — Speaker window

- [ ] 6.1 `PresentationSyncChannel`
- [ ] 6.2 Next-state preview
- [ ] 6.3 Speaker view and window opening
- [ ] 6.4 Sync in practice

## Phase 7 — Slides app, examples, docs, polish

- [ ] 7.1 The slides app
- [ ] 7.2 Example presentations
- [ ] 7.3 Documentation
- [ ] 7.4 CI and final verification

## Decisions

Concept corrections and choices the phase docs left open, in the order they
were hit. Each follows the option most consistent with the concept decisions
and the fluvie spec.

1. **obers_ui is not on pub.dev.** The concept says "obers_ui comes from
   pub.dev", but pub.dev has no such package. It is the author's own public
   GitHub package (`SimonErich/obers_ui`, `publish_to: none`), so
   `fluvie_presenter` depends on it as a git dependency pinned to a commit.
   Consequence: the presenter itself stays `publish_to: none` until obers_ui
   publishes (pub.dev rejects git dependencies).
2. **The `.fluvie` parser lives in `package:fluvie`.** Phase 7 says "parse it
   with `fluvie_ai`"; in the repo the JSON→`Video` mapping lives in fluvie's
   serialization layer with `fluvie_ai` layered in front. The app wires
   whatever loader entry `fluvie_ai` exposes, and the parse dependency stays
   at the app layer either way.
3. **Gate cadence.** The full workspace gate (`CI=true melos run gate`)
   runs at every phase boundary and before the final report. Per epic, the
   commit gate is: workspace format + analyze + custom_lint, plus the full
   test suite *and* the 97% coverage gate of every package the epic touched.
   Same bar, without re-running the untouched packages' coverage dozens of
   times.
4. **fluvie docs for the fluvie-side additions.** LivePlayer and
   introspectTimeline are public fluvie API, so they shipped with a fluvie
   docs page (`documentation/advanced/live-playback.md`) with compiled
   snippets, alongside the presenter skeleton in Phase 1.
5. **The hold model.** A held step never pauses the clock: each slide is a
   single-scene composition stretched to a huge horizon on a free-running
   clock, revealed steps live on rebased subtree clocks (`FrameRebase` +
   fluvie's `LocalMotionScope`), and exits never fire (they anchor to the
   horizon; slides leave via presenter-level blends mapped from the authored
   `Transition`). Consequences, documented for authors: relative `Time`s
   resolve against the stretched scene, and elements inside a `Stop` cannot
   use cross-element or beat triggers (the compiler reports both).
6. **Chrome details the phases left open.** The HUD (counter + progress)
   toggles with `H`. Presenter remotes' F5 maps to the fullscreen toggle.
   Desktop fullscreen uses `window_manager` 0.5.2 behind a testable bridge
   (the desktop_multi_window README recommends a pinned fork of it if the
   two ever conflict — checked again in Phase 6). obers_ui is git-pinned;
   the shell mounts its own `OiThemeScope`, so the chrome renders without
   an `OiApp` above.
7. **Riverpod flavor.** The concept asks for MVVM with Riverpod in the
   presenter UI; fluvie library packages use pure `riverpod` while only apps
   use `flutter_riverpod`. The presenter is a UI package (its views are
   widgets), so it takes `flutter_riverpod` — the first library package to do
   so, per the concept's explicit instruction.
