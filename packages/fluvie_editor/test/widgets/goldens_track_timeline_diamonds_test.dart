@Tags(['golden'])
library;

import 'package:alchemist/alchemist.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie_editor/fluvie_editor.dart';
import 'package:obers_ui/obers_ui.dart'
    show
        OiDensity,
        OiDensityScope,
        OiInputModality,
        OiPlatform,
        OiPlatformData,
        OiThemeData,
        OiThemeScope;

const _enter = Color(0xFF46A758);
const _during = Color(0xFFFFB224);

Widget _frame(Widget child) => OiThemeScope(
  data: OiThemeData.dark(),
  child: OiPlatform(
    data: const OiPlatformData(
      platform: TargetPlatform.linux,
      keyboardHeight: 0,
      keyboardVisible: false,
      inputModality: OiInputModality.pointer,
    ),
    child: OiDensityScope(
      density: OiDensity.compact,
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: SizedBox(width: 620, height: 160, child: child),
      ),
    ),
  ),
);

/// A keyframes bar carrying its stop diamonds — the middle one selected —
/// over a plain preset bar that stays diamond-free.
Widget _diamonds() => _frame(
  const TrackTimeline(
    tracks: [
      TimelineTrack(
        id: 'hero',
        label: 'Hero',
        bars: [
          TimelineBar(
            id: 'hero-0',
            start: 10,
            end: 130,
            color: _enter,
            badge: 'keyframes',
            diamonds: [
              TimelineDiamond(id: 'k0', frame: 10),
              TimelineDiamond(id: 'k1', frame: 55),
              TimelineDiamond(id: 'k2', frame: 100),
              TimelineDiamond(id: 'k3', frame: 130),
            ],
          ),
        ],
      ),
      TimelineTrack(
        id: 'caption',
        label: 'Caption',
        bars: [
          TimelineBar(id: 'caption-0', start: 40, end: 180, color: _during, badge: 'float'),
        ],
      ),
    ],
    fps: 30,
    totalFrames: 240,
    playhead: 55,
    selection: TrackTimelineSelection(
      selectedDiamondId: 'k1',
    ),
  ),
);

Future<void> main() async {
  await goldenTest(
    'keyframe diamonds ride their bar with the selected stop highlighted',
    fileName: 'track_timeline_diamonds',
    builder: () => GoldenTestGroup(
      columns: 1,
      children: [
        GoldenTestScenario(name: 'a keyframes bar with a selected diamond', child: _diamonds()),
      ],
    ),
  );
}
