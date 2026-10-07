@Tags(['golden'])
library;

import 'package:alchemist/alchemist.dart';
import 'package:flutter/widgets.dart' hide Animation;
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/fluvie.dart';

Widget headline(Curve ease, int frame) => SizedBox(
  width: 300,
  height: 100,
  child: RenderControllerScope(
    controller: RenderController(initialFrame: frame),
    child: Video(
      width: 300,
      height: 100,
      scenes: [
        Scene(
          duration: const Time.frames(80),
          children: [
            Center(
              child:
                  SplitText(
                    'Words move together',
                    style: const TextStyle(fontSize: 22, color: Color(0xFFF6F7FB)),
                  ).animate([
                    Animation.slideFadeIn(
                      duration: const Time.frames(30),
                      ease: ease,
                      stagger: const Stagger.each(Time.frames(6)),
                    ),
                  ]),
            ),
          ],
        ),
      ],
    ),
  ),
);
Future<void> main() async {
  await goldenTest(
    'split headlines use word stagger and custom easing at the same frame',
    fileName: 'split_text_cubic',
    builder: () => GoldenTestGroup(
      columns: 2,
      children: [
        for (final frame in [12, 24, 50]) ...[
          GoldenTestScenario(name: 'linear at $frame', child: headline(Ease.linear, frame)),
          GoldenTestScenario(
            name: 'cubic at $frame',
            child: headline(const Cubic(0.2, 0.9, 0.6, 1), frame),
          ),
        ],
      ],
    ),
  );
}
