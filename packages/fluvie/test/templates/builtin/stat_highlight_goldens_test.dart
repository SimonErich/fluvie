// Epic 14.3 (WI-11, §14.3): the StatHighlight poster golden. The built-in builds
// a real Video whose Counter headline is frame-driven; the poster mounts it
// under its own clock at a frame past the count and the label fade-in, and
// Alchemist captures the resolved card. ci goldens use Ahem (zero font
// variance). The reels Video lays out at its real canvas, then FittedBox scales
// the poster into the golden box.
@Tags(['golden'])
library;

import 'package:alchemist/alchemist.dart';
import 'package:flutter/widgets.dart' show Color, FittedBox, SizedBox;
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/rendering/runtime/render_controller.dart';
import 'package:fluvie/src/rendering/runtime/render_controller_scope.dart';
import 'package:fluvie/src/templates/builtin/stat_highlight.dart';

Future<void> main() async {
  await goldenTest(
    'StatHighlight: the poster frame of a built stat card (§14.3)',
    fileName: 'stat_highlight_poster',
    builder: () => GoldenTestGroup(
      children: [
        GoldenTestScenario(
          name: 'poster',
          child: SizedBox(
            width: 108,
            height: 192,
            child: FittedBox(
              child: SizedBox(
                width: 1080,
                height: 1920,
                child: RenderControllerScope(
                  // Frame 75 (2.5s in at 30fps): the count has reached its value
                  // and the label has faded in, so the poster shows the result.
                  controller: RenderController(initialFrame: 75),
                  child: const StatHighlight().build(
                    const StatHighlightProps(
                      value: 48230,
                      label: 'minutes listened',
                      background: Color(0xFF111827),
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
