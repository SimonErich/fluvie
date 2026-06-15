// Epic 14.3 (WI-10, §14.3): the TitleIntro poster golden. The built-in builds a
// real Video; the poster scenario mounts it under its own frame clock at a
// settled frame and Alchemist captures the title (and subtitle) it painted. ci
// goldens use Ahem, so the poster carries zero font variance. The Video is
// reels (9:16), shown in a box of that shape.
@Tags(['golden'])
library;

import 'package:alchemist/alchemist.dart';
import 'package:flutter/widgets.dart' show Color, FittedBox, SizedBox;
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/rendering/runtime/render_controller.dart';
import 'package:fluvie/src/rendering/runtime/render_controller_scope.dart';
import 'package:fluvie/src/templates/builtin/title_intro.dart';

Future<void> main() async {
  await goldenTest(
    'TitleIntro: the poster frame of a built title + subtitle (§14.3)',
    fileName: 'title_intro_poster',
    builder: () => GoldenTestGroup(
      children: [
        GoldenTestScenario(
          name: 'poster',
          // The built Video lays out at its real reels canvas (1080x1920) so the
          // template's font sizes fit, then FittedBox scales the whole poster
          // down into the golden box — exactly the downscale a thumbnail uses.
          child: SizedBox(
            width: 108,
            height: 192,
            child: FittedBox(
              child: SizedBox(
                width: 1080,
                height: 1920,
                child: RenderControllerScope(
                  // Frame 60 (2s in at 30fps): the pop has settled and the
                  // subtitle has slid in, so the poster shows the resolved card.
                  controller: RenderController(initialFrame: 60),
                  child: const TitleIntro().build(
                    const TitleIntroProps(
                      title: '2025',
                      subtitle: 'Year in review',
                      background: Color(0xFF1D2671),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}
