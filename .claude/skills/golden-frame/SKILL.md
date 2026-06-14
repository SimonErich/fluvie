---
name: golden-frame
description: Render a Fluvie scene at one or more frames and snapshot it deterministically via Alchemist (fixed fps, bundled fonts, fixed seed). Use to add or update golden-frame tests for any widget, animation, or effect.
---

# golden-frame

Golden tests must be byte-identical across machines, so they pin everything
that could vary: fps, fonts, seed, and device-pixel-ratio. Goldens run through
**Alchemist** (configured in each package's `test/flutter_test_config.dart`):

- **ci goldens** (`test/goldens/ci/`, Ahem font) run and compare everywhere;
  they protect geometry/layout.
- **platform goldens** (`test/goldens/linux/`, real bundled fonts) run on
  Linux only (the baseline platform) and protect real rendering.

## Steps

1. **Write the failing golden test first.** Use Alchemist's `goldenTest` with a
   `GoldenTestGroup`/`GoldenTestScenario` per state. Tests are auto-tagged
   `golden` (declared in `dart_test.yaml`; excluded from plain `melos run test`).
2. **Pick representative frames** — for an enter/exit animation, 0%, 50%, 100%
   of its window; for continuous motion, a few phase points; for effects,
   fixed params. Drive the frame through the harness (fixed fps, fixed seed),
   never wall-clock.
3. **Name by state**: `fileName: 'fade_in'`, scenarios `at_0`, `at_50`, `at_100`.
4. **Generate** with `flutter test --update-goldens --tags golden`, then
   **review the PNGs** — a golden is only correct once a human confirmed it.
5. **Determinism check** where relevant — capture the same frame twice and
   assert identical bytes (no flakiness).
6. **Gate** — `CI=true melos run gate` + `melos run test:goldens` green; commit
   the goldens with the feature.

## Template

```dart
import 'package:alchemist/alchemist.dart';
import 'package:fluvie/fluvie.dart';

Future<void> main() async {
  await goldenTest(
    'fadeIn renders correctly across its window',
    fileName: 'fade_in',
    builder: () => GoldenTestGroup(
      children: [
        for (final (name, frame) in [('at_0', 0), ('at_50', 30), ('at_100', 60)])
          GoldenTestScenario(
            name: name,
            child: pumpFrameFixture(frame: frame, child: /* composition */),
          ),
      ],
    ),
  );
}
```

> The `pumpFrameFixture` helper (the shared golden harness in `test/`) pins fps,
> seed, fonts, and DPR so the frame is byte-stable.
