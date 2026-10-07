// A keyframed exposure, read at three frames of one element's life: dim a
// stop under, neutral, half a stop over. The three cells differ only in the
// frame they were captured at, so what they prove is that the grade moved.
// Subjects stay font-free (D20).
@Tags(['golden'])
library;

import 'package:alchemist/alchemist.dart';
import 'package:flutter/widgets.dart' hide Animation, Clip, Image, Tween;
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/fluvie.dart';

/// A 60-frame element whose exposure climbs from a stop under to half over.
Map<String, Object?> _deck() => {
  'fluvieSpec': 1,
  'size': {'width': 130, 'height': 130},
  'fps': 30,
  'scenes': [
    {
      'duration': '60f',
      'children': [
        {
          'id': 'el-graded',
          'type': 'Box',
          'color': '#7A9E7E',
          'transform': {'x': 0.5, 'y': 0.5, 'w': 0.7, 'h': 0.7},
          'effects': [
            {
              'kind': 'grade',
              'saturation': 1.2,
              'exposure': {
                'values': [-1, 0.5],
                'positions': ['0f', '60f'],
              },
            },
          ],
        },
      ],
    },
  ],
};

GoldenTestScenario _cell(int frame) => GoldenTestScenario(
  name: 'frame $frame',
  child: SizedBox(
    width: 130,
    height: 130,
    child: RenderModeContext(
      mode: RenderMode.capture,
      child: RenderControllerScope(
        controller: RenderController(initialFrame: frame),
        child: VideoSpec.fromJson(_deck()).build(),
      ),
    ),
  ),
);

Future<void> main() async {
  await goldenTest(
    'a keyframed exposure climbs over its element life',
    fileName: 'keyframed_grade',
    builder: () => GoldenTestGroup(
      columns: 3,
      children: [_cell(0), _cell(30), _cell(59)],
    ),
  );
}
