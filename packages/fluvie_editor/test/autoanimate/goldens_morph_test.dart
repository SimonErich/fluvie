// Epic 8.2 acceptance goldens: the auto-animate command's output morphs in
// the plain spec build — the file render's truth. The deck starts with no
// shared ids and no transitions; ApplyAutoAnimateCommand pairs the yellow
// box by content (large centred on slide 1, small top-left on slide 2),
// mints its shared id, and writes the crossFade enter that gives the morph
// its blend window. The green box exists only on slide 2 — unmatched, so it
// rides that authored crossFade with no invented motion. Font-free (D20).
//
// Two 60f scenes at 30 fps with the auto 500ms (15f) overlapping crossFade:
// starts [0, 45], blend window [45, 60). Mid samples frame 52 (the hero
// between both rects at full opacity while the scenes blend beneath); end
// samples frame 59 (≈ the target rect).
@Tags(['golden'])
library;

import 'package:alchemist/alchemist.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/fluvie.dart' show RenderController, RenderControllerScope;
import 'package:fluvie_editor/fluvie_editor.dart';

Map<String, Object?> _deck() => {
  'fluvieSpec': 1,
  'size': {'width': 320, 'height': 180},
  'fps': 30,
  'scenes': [
    {
      'duration': '60f',
      'layout': 'canvas',
      'background': {'kind': 'color', 'color': '#2C3E50'},
      'children': [
        {
          'id': 'el-hero',
          'type': 'Box',
          'color': '#F1C40F',
          'transform': {'x': 0.5, 'y': 0.5, 'w': 0.4, 'h': 0.5},
        },
      ],
    },
    {
      'duration': '60f',
      'layout': 'canvas',
      'background': {'kind': 'color', 'color': '#8E44AD'},
      'children': [
        {
          'id': 'el-hero-2',
          'type': 'Box',
          'color': '#F1C40F',
          'transform': {'x': 0.12, 'y': 0.15, 'w': 0.12, 'h': 0.2},
        },
        {
          'id': 'el-new',
          'type': 'Box',
          'color': '#2ECC8F',
          'transform': {'x': 0.7, 'y': 0.7, 'w': 0.25, 'h': 0.3},
        },
      ],
    },
  ],
};

Widget _frame(int frame) {
  final document = const ApplyAutoAnimateCommand(
    slide: 1,
    enabled: true,
  ).apply(EditorDocument.fromJson(_deck()));
  return SizedBox(
    width: 320,
    height: 180,
    child: RenderControllerScope(
      controller: RenderController(initialFrame: frame),
      child: document.spec.build(),
    ),
  );
}

Future<void> main() async {
  await goldenTest(
    'the auto-animated boundary morphs the paired box across the crossFade',
    fileName: 'auto_animate_morph',
    builder: () => GoldenTestGroup(
      children: [
        GoldenTestScenario(name: 'frame 52 (mid-window)', child: _frame(52)),
        GoldenTestScenario(name: 'frame 59 (last blend)', child: _frame(59)),
      ],
    ),
  );
}
