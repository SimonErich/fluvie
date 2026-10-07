@Tags(['golden'])
library;

import 'package:alchemist/alchemist.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/fluvie.dart';

GoldenTestScenario cell(String name, EffectLayer effect) => GoldenTestScenario(
  name: name,
  child: SizedBox(
    width: 120,
    height: 100,
    child: RenderControllerScope(
      controller: RenderController(initialFrame: 15),
      child: Video(
        width: 120,
        height: 100,
        scenes: [
          Scene(
            duration: const Time.frames(30),
            children: [
              const Center(
                child: SizedBox(width: 75, height: 60, child: ColoredBox(color: Color(0xFF60BFDD))),
              ).effects([effect]),
            ],
          ),
        ],
      ),
    ),
  ),
);
Future<void> main() async {
  await goldenTest(
    'blur radius and glitch strength change pixels',
    fileName: 'blur_glitch',
    builder: () => GoldenTestGroup(
      columns: 2,
      children: [
        cell('blur 1', Effect.blur(sigma: 1)),
        cell('blur 12', Effect.blur(sigma: 12)),
        cell('glitch 20%', Effect.glitch(intensity: 0.2)),
        cell('glitch 100%', Effect.glitch()),
      ],
    ),
  );
}
