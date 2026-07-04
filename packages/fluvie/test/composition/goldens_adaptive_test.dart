// Epic 14.2 (WI-8, §14.2.3): the multi-aspect acceptance golden. ONE Adaptive
// composition definition, rendered for three aspects, produces three distinct
// aspect goldens (reels / square / landscape). Each scenario mounts the SAME
// subject under an AspectScope for its aspect inside a box of that aspect's
// shape — exactly the layout branch render(video, aspect:) drives through the
// shell, minus the frame loop and ffmpeg (gate-runnable, font-free).
@Tags(['golden'])
library;

import 'package:alchemist/alchemist.dart';
import 'package:flutter/widgets.dart' hide Animation, Clip, Image, Tween;
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/composition/adaptive.dart';
import 'package:fluvie/src/composition/runtime/aspect_scope.dart';
import 'package:fluvie/src/core/aspect.dart';

const _bar = ColoredBox(color: Color(0xFF6C5CE7), child: SizedBox.expand());
const _dot = ColoredBox(color: Color(0xFF00B894), child: SizedBox.expand());

/// The single composition definition exercised across every aspect: vertical
/// (reels/portrait45) stacks the bar over the dot; horizontal (square/landscape)
/// puts them side by side. Layout branches per aspect; nothing else changes.
Widget _subject() => Adaptive(
  reels: () => const Column(
    children: [
      Expanded(child: _bar),
      Expanded(child: _dot),
    ],
  ),
  portrait45: () => const Column(
    children: [
      Expanded(child: _bar),
      Expanded(child: _dot),
    ],
  ),
  square: () => const Row(
    children: [
      Expanded(child: _bar),
      Expanded(child: _dot),
    ],
  ),
  landscape: () => const Row(
    children: [
      Expanded(child: _bar),
      Expanded(child: _dot),
    ],
  ),
);

Widget _scenarioChild(Aspect aspect, Size size) => SizedBox(
  width: size.width,
  height: size.height,
  child: AspectScope(aspect: aspect, child: _subject()),
);

Future<void> main() async {
  await goldenTest(
    'Adaptive: one definition renders three distinct aspect goldens (§14.2.3)',
    fileName: 'adaptive_three_aspects',
    builder: () => GoldenTestGroup(
      children: [
        GoldenTestScenario(
          name: 'reels',
          child: _scenarioChild(Aspect.reels, const Size(54, 96)),
        ),
        GoldenTestScenario(
          name: 'square',
          child: _scenarioChild(Aspect.square, const Size(96, 96)),
        ),
        GoldenTestScenario(
          name: 'landscape',
          child: _scenarioChild(Aspect.landscape, const Size(96, 54)),
        ),
      ],
    ),
  );
}
