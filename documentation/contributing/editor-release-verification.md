# Editor release verification

Use the repository's release SDK, Flutter 3.47.2 / Dart 3.13.2, for both the
commands below and their child processes. A different Flutter renderer can
change golden pixels. Commands run from the repository root unless indicated.

## Regression and package gates

```sh
flutter pub get
melos run gate
bash tool/verify_packages.sh /absolute/path/to/flutter-sdk
```

The standard gate checks formatting, static analysis, custom lints, tests and
97% library/app line coverage. It includes the CI golden variants. The
[package gate](package-release.md) additionally checks isolated publication
contents. It fails on regressions; its analyzer compatibility exception applies
only to the lint package's documented dependency freshness deduction.

The real Linux application journey exercises import, editing, save/reopen and
actual export, including decoded video and audio assertions:

```sh
cd apps/slides
flutter test integration_test/editor_e2e_test.dart -d linux
```

The broader `tool/run_full_qa.sh` also runs the opt-in suites, example renders,
documentation checks and fresh-checkout acceptance. Retain its report separately
from focused hardening runs so an earlier full pass cannot be mistaken for a
later source revision's result.

## Browser engines

```sh
bash apps/slides/tool/fetch_ffmpeg.sh
(cd apps/slides && flutter build web --release)
node --test tool/test/browser*_test.mjs
bash tool/verify_browser_matrix.sh
```

The matrix uses installed Chrome and pinned Playwright Firefox/WebKit binaries.
Test dependencies live under ignored `build/`, not in production dependencies.
Use `--with-deps` on a provisioned Linux CI runner to install browser system
libraries. `CHROME_EXECUTABLE` can select a specific installed Chrome binary;
`FLUVIE_BROWSERS=chrome,firefox,webkit-linux` selects engines and rejects typos.

The tests exercise the shipped FFmpeg/WebCodecs bridges, H.264 output,
cancellation/reload, temporary-file cleanup, source metadata and decoded media.
They also boot the compiled application, open the editor from New deck, and
verify the speaker route. JSON evidence and screenshots go to
`build/release-hardening/browsers/` or `FLUVIE_BROWSER_OUT`.
Linux WebKit is engine coverage, not Safari-on-Apple-device certification.
[Playwright documents that distinction and its platform-specific media support](https://playwright.dev/docs/browsers).
The [pixel oracle notes](browser-release-checks.md) explain the independent
native-frame checks and browser-specific chroma interpolation.

Verify the actual retained icon constants against bundled font outlines after
the release web build, using a Python environment with the pinned dependency:

```sh
python3 -m venv build/font-check
build/font-check/bin/pip install -r tool/requirements-font-validation.txt
PYTHONDONTWRITEBYTECODE=1 build/font-check/bin/python -m unittest discover -s tool -p test_verify_icon_fonts.py
build/font-check/bin/python tool/verify_icon_fonts.py --app apps/slides --flutter-root /absolute/path/to/flutter-sdk
```

The verifier rejects missing families, missing glyphs, empty outlines and
nonconstant icon declarations that cannot be checked statically.

## Optimized performance

```sh
bash tool/verify_editor_performance.sh profile
bash tool/verify_editor_performance.sh release
```

Use a real Linux display and FFmpeg. Stop this task's other builds, tests and
emulators before collecting final measurements; record any unrelated machine
load that cannot be controlled. `FLUVIE_PERF_OUT` selects an evidence directory.
The wrapper deletes stale reports and validates the running program's build
mode and assertion state. Release executes an AOT test program without a VM
service and exits with the test verdict.

The workload is a three-minute 3840×2160, 24 fps document: eight video lanes,
240 clip placements, eight initially visible clips, and one repeated six-second
source file. It is not a benchmark of 240 independent decoders. Measurements
include document/model work, actual timeline wheel scrolling and zoom, canvas
dragging through the full editor host, exact undo restoration, preview generation
and Full/Half/Quarter source decoding.

Engine build/raster `FrameTiming` is reported separately from interaction
wall-clock time, which includes test-driver and frame scheduling waits. The
report retains medians, p95, maxima, budget counts and ordered per-frame timings,
including scheduling and build-to-raster waits. Drag updates and the final
commit are split by engine frame number without pausing the gesture. Readiness
requires the first decoded canvas image; initial filmstrip/background work can
still overlap the first zoom interaction. This measures that actual first-use
scenario and does not claim an isolated, fully warmed interaction or infer
release frame rates from debug timings. See Flutter's
[performance profiling guidance](https://docs.flutter.dev/cookbook/testing/integration/profiling)
and [frame timing collection](https://api.flutter.dev/flutter/package-integration_test_integration_test/IntegrationTestWidgetsFlutterBinding/watchPerformance.html).

The benchmark build replaces the Linux bundle's entry point. Restore the normal
application afterwards:

```sh
(cd apps/slides && flutter build linux --release)
```

## Native mobile acceptance

The [mobile example README](../../examples/mobile_purrfect/README.md) contains
the exact Android and iOS commands. `native_clip_reader_test.dart` checks
fractional/VFR timestamps, B-frame presentation order, rotation, duplicate and
out-of-range requests and replacement at the same path.
`native_media_acceptance_test.dart` renders a source and two consecutive
trimmed/ramped exports. The host FFmpeg oracle independently checks every video
frame, timestamps, embedded audio, a source-time frequency event, gains and fades.
Keep the installed test application until its media has been collected.

The macOS CI job compiles the iOS plugin and runs both native suites on a real
iOS simulator runtime. Merely adding that job, parsing Swift or passing Dart
method-channel tests does not establish native compilation or AVFoundation
correctness. Record an actual native job result before certifying iOS support.
Emulator/simulator acceptance likewise does not establish physical-device
throughput, memory limits or all hardware codec implementations.
The VFR fixtures prove native source-frame ordering and extraction. Composition
still maps source time through a scalar frame rate; these tests do not certify
arbitrary variable-frame-rate playback cadence. Use constant-frame-rate media
when exact composition timing is required by the current model.
