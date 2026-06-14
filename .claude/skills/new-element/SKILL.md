---
name: new-element
description: Scaffold a new Fluvie element widget consistently — file, public type, dartdoc, .animate() compatibility, Alchemist golden test (written first, red), barrel export, and lesson entry (extend the matching example/lib/lessons/NN_*.dart, or 12_the_kitchen_sink). Use when adding any widget under packages/fluvie/lib/src/elements/.
---

# new-element

Every Fluvie element follows the same house pattern so the library stays
consistent and DRY. Given an element name (e.g. `Typewriter`), produce all of:

## Steps

1. **Source file** — `packages/fluvie/lib/src/elements/<snake_name>.dart`.
   - One public widget class; constructor params are **content behaviour only** (transforms/effects always go through `.animate()`, never constructor params).
   - Full dartdoc with a usage snippet. Keep `build` ≤ ~80 lines; extract private `_`-prefixed widgets into the same file if small, else a sibling file.
   - Read the frame deterministically (`FrameProvider.of(context).frame`); no wall-clock, no unseeded random. Pre-resolve any media via `MediaRepository` before capture.
2. **`.animate()` compatibility** — the widget must compose under `MotionTarget` (it does automatically once it returns a normal widget subtree; verify with a compose golden).
3. **Barrel export** — add `export 'src/elements/<snake_name>.dart';` to `lib/fluvie.dart`, in layer order.
4. **Golden test** — `packages/fluvie/test/elements/<snake_name>_test.dart` with goldens at 0%, 50%, 100% progress via the deterministic harness (see `golden-frame`).
5. **Example gallery entry** — add a small, readable usage in `example/` using the public barrel only.
6. **Gate** — `melos run gate` green; commit `feat(elements): add <Name>`.

## Template

```dart
import 'package:flutter/widgets.dart';

import '../rendering/frame_provider.dart';

/// {Short description of what <Name> shows and how it animates.}
///
/// ```dart
/// <Name>(/* content params */).animate([Animation.fadeIn()]);
/// ```
class <Name> extends StatelessWidget {
  /// Creates a <Name>. {Document each content param.}
  const <Name>({super.key, /* content params */});

  @override
  Widget build(BuildContext context) {
    final frame = FrameProvider.of(context).frame;
    // ... deterministic, frame-driven build ...
    return const SizedBox.shrink();
  }
}
```
