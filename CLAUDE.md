# CLAUDE.md — Fluvie working agreement

Fluvie renders declarative Flutter trees to a real video file (MP4 via FFmpeg).
You describe **what** the video is; Fluvie computes **when** everything happens.

> **Design reference:** [`concept/API_SPEC.md`](concept/API_SPEC.md) describes the
> public API and the design decisions behind it. When code and spec disagree, the
> spec is the intended behavior — fix the code or update the spec deliberately.

---

## Architecture & the layering law

Clean layering inside `packages/fluvie/lib/src/`. Dependencies point **down only**:

```
core            ← pure Dart: Time, Keyframe, enums, Defaults, exceptions, contracts
  ▲
timing          ← TimeScope, frame resolution, trigger/anchor resolver
  ▲
rendering · animation · composition · elements · effects · media · audio · theme · templates
  ▲
diagnostics     ← debugTimeline, inspector model, golden harness hooks (nothing depends on it)
```

- `core` depends on nothing (only Flutter math types: `Curve`, `Color`, `Alignment`, `Offset`, `Path`).
- `timing` depends only on `core`.
- Feature layers may depend on `core` + `timing` (+ documented peers) but **never** on `diagnostics`.
- **Nothing imports another package's `src/`** (enforced by the `implementation_imports` lint and the `no_src_import` custom lint).
- The single barrel `lib/fluvie.dart` is the **only** public entry. `src/` stays private.
- Forward dependencies are mediated by an **interface in the lowest stable layer**, with a fake for tests and the real implementation injected through a Riverpod provider. Pure exceptions (`FluvieTimingError`, `FluvieEncodeException`) live in `core/errors/`, not `diagnostics`.

### Name shadowing (`Animation`, `Image`, `Tween`, `Clip`)

Fluvie's `Animation`, `Image`, `Tween`, and `Clip` deliberately shadow Flutter's;
the barrel hides Flutter's versions. In library code that needs Flutter's types,
import with a prefix:

```dart
import 'package:flutter/widgets.dart' as flutter; // flutter.Animation<T>, etc.
```

---

## Service / repository / provider / MVVM conventions

- **Service** — stateless or scoped logic (IO or computation): `FfmpegEncoderService`, `MediaCacheService`, `FrameCaptureService`, `BeatDetectionService`. Abstract contract + separate implementation, injected via a Riverpod provider.
- **Repository** — owns access to a data source: `MediaRepository` (download + cache + decode). Widgets/ViewModels never do IO directly.
- **Provider (Riverpod)** — the wiring. One provider per service/repository; overridable in tests with fakes.
- **ViewModel / Notifier** — **only** in the example apps (under `examples/`) (MVVM: View ↔ ViewModel ↔ Repository/Service). The library has **no** ViewModels: its "view" is the widget API, its "model" is `core`, its "logic" is `timing` + services.

---

## Capture model

Headless capture needs the frame to be the only clock, so each frame builds as a
pure function of its index. This is a **correctness** requirement (not a
byte-identity guarantee):

- In **capture mode** (`RenderModeContext`): no async-in-frame, no platform views, media pre-resolved before the frame loop. You cannot await media or run a wall-clock ticker mid-frame in a synchronous capture pump.
- Media (`Image`/`Clip`/snapshots) are pre-resolved before capture and **cached by content hash** (an advisory cache for performance — it does not detect composition-code changes).
- Seeded `noise(seed)` / `random(seed)` keep effects stable run-to-run; prefer them so renders don't flicker, but they are not enforced.

Fluvie does **not** guarantee byte-identical output across machines, platforms, or
encoders. On-device decode (WebCodecs, native mobile) and hardware encoders vary;
that is fine — the bar is "it looks right," not "the bytes match."

---

## Testing policy (test-first, always)

- **Red → green → refactor for every change.** No production `.dart` file before its failing test exists and has been seen to fail for the right reason.
- **Unit tests** for everything pure (core, timing, services, math) — the bulk. Mock with **mocktail**; inject fakes through Riverpod overrides. No real network or filesystem in unit tests.
- **Goldens via Alchemist** (`golden` tag): visual-regression on the Linux baseline. ci goldens (Ahem font) run everywhere; platform goldens (real, bundled fonts) run on Linux only. Fixed fps, fixed seed, DPR 1.0. Regenerate with `flutter test --update-goldens --tags golden`, then review the PNG before committing.
- **Integration tests** are tagged by what they need: `ffmpeg`, `snapshot` (live Chromium), `wasm`, `render`. Plain `melos run test` excludes goldens/snapshots; CI gates tags per platform.
- **Coverage gate: ≥97% line coverage** on every package under `packages/` (all nine; generated files excluded, `// coverage:ignore` markers honored), enforced by `melos run coverage:check`; 100% is the goal. Justified `// coverage:ignore` needs a reason on the same line — see `documentation/contributing/coverage.md`.

---

## Security

- **FFmpeg is invoked with argument *lists*, never shell strings** — no string concatenation of paths/URLs into a command. Build a typed filter graph.
- Validate every external input (URLs, file paths, downloaded media).
- Sandbox temp directories; respect a strict **network allowlist** for any fetch/snapshot.

---

## Code standards

- **File-size budget:** ≤ ~200 lines per production (`lib/`) file, ≤ ~80 lines per widget `build`. Extract beyond that (use `part`/`part of` to keep a feature cohesive across files). Test files are exempt (they aggregate cases). A cohesive public-API surface that genuinely cannot be split — e.g. the `Animation` static-method preset facade — may carry a `// fluvie:large-file-ok: <reason>` marker to opt out; use sparingly.
- **One primary public type per file.** Private widgets (`_`-prefixed) may share the file. No `utils.dart` dumping grounds — name files by responsibility.
- **Naming:** `snake_case.dart` files; `UpperCamel` types.
- **Hard rules:** no `TODO`/`FIXME` left behind, no dead or commented-out code, no `print` (use `stderr`/logging), no `dynamic` unless unavoidable **and** justified with a file-scoped `// ignore:` + reason.
- **Dartdoc:** every public member of `packages/fluvie` is documented (`public_member_api_docs`). Annotate `@useResult` on `.animate()`/`.show()`; `@experimental` on `Timeline`/`FrameBuilder`/shader animations; `@Deprecated` on renamed members.
- **Generated code (`*.g.dart`, `*.freezed.dart`) is committed** (reviewable diffs + fast CI); `.gitattributes` collapses it in diffs; the analyzer excludes it. Run `build_runner` and commit the result in the same change.
- **Formatting:** page width 100 (root `analysis_options.yaml`), trailing commas required.
- **Add a dependency only in the package that first uses it** — no speculative deps (pana penalizes them).

---

## The quality gate

Run **before every commit**; all must be green (never leave the tree broken):

```sh
CI=true melos run gate     # = format → analyze → lint → coverage:check
# individually (direct runs of filtered scripts need --no-select):
melos run format           # dart format --set-exit-if-changed
melos run analyze          # dart analyze --fatal-infos --fatal-warnings
melos run lint --no-select # dart run custom_lint
melos run test             # dart test (pure-Dart pkgs) + flutter test (Flutter pkgs)
melos run test:goldens     # Alchemist goldens (Linux baseline)
```

Run Melos non-interactively (`CI=true`) to avoid the interactive-prompt path.

---

## Commits

- **Conventional Commits**, one logical change per commit, never bundle unrelated changes (`feat(timing): …`, `fix(rendering): …`). The commit-msg hook enforces the format.
- Install the hooks once after cloning: `bash .githooks/install.sh`.

---

## Documentation & the example lessons

- Human docs live in [`documentation/`](documentation/) (never `docs/`): `getting-started/`, `guides/`, `advanced/`, `reference/`, `contributing/`. **A new capability ships its docs page in the same change.**
- Voice: short sentences, active voice, second person. **No em-dashes.** No marketing vocabulary (seamless, robust, leverage, powerful as filler, effortless, …). Lead with a runnable example. One page answers one question. End every page with `## Where to next`.
- **Dart snippets are never hand-typed in docs**: they live in compiled, tested files under `examples/gallery/lib/` with `// #docregion` markers and flow into docs fences via `<?code-excerpt?>` (checked in CI).
- The gallery example app is **12 lessons** (`examples/gallery/lib/lessons/01_hello_video.dart` … `12_the_kitchen_sink.dart`) plus the MVVM inspector. Each lesson: a short intro, one complete readable `Video`, a representative Alchemist golden, and a render-to-file action.

---

## Workflow & delegation

For a substantial change: **architect → implementer → reviewer → tester**;
`docs-writer` updates the documentation pages. Bring in `render-engineer` for
render-heavy work (timing, encoding, capture, FFmpeg). See
[`.claude/agents/`](.claude/agents/) for roles and [`.claude/skills/`](.claude/skills/)
for the repeatable house patterns (`new-element`, `new-service`, `golden-frame`,
`new-animation-preset`).

## Running locally

```sh
melos bootstrap            # resolve the workspace
CI=true melos run gate     # the full quality gate
melos run test:goldens     # Alchemist goldens (Linux baseline)
melos run coverage:check   # the ≥97% coverage gate
melos run render:examples  # headless lesson renders (needs a Flutter SDK and ffmpeg)
```
