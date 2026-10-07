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

// The video-mode palette: scene blocks violet, element lanes blue, music
// green, effects amber — mirroring the panel's theme mapping.
const _palette = VideoLanePalette(
  scene: Color(0xFF8E4EC6),
  element: Color(0xFF0091FF),
  music: Color(0xFF46A758),
  sfx: Color(0xFFFFB224),
);

Map<String, Object?> _deck() => {
  'fluvieSpec': 1,
  'fps': 30,
  'lanes': [
    {'id': 'v1', 'name': 'V1'},
  ],
  'scenes': [
    {
      'duration': '180f',
      'transitions': [
        {
          'between': ['a', 'b'],
          'kind': 'crossFade',
          'duration': '15f',
        },
      ],
      'children': [
        {
          'id': 'a',
          'type': 'Clip',
          'lane': 'v1',
          'source': {'kind': 'asset', 'value': 'outgoing.mp4'},
          'show': {'from': '0f', 'to': '60f'},
        },
        {
          'id': 'b',
          'type': 'Clip',
          'lane': 'v1',
          'source': {'kind': 'asset', 'value': 'incoming.mp4'},
          'show': {'from': '60f', 'to': '120f'},
        },
        {
          'id': 'ramp',
          'type': 'Clip',
          'lane': 'v1',
          'source': {'kind': 'asset', 'value': 'slow_motion.mp4'},
          'show': {'from': '105f', 'to': '180f'},
          'speed': {
            'values': [1, 0.25],
            'positions': ['0r', '1r'],
          },
        },
      ],
    },
  ],
};

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
        child: SizedBox(width: 620, height: 220, child: child),
      ),
    ),
  ),
);

/// The whole-video lanes of a real document: the scenes lane with its
/// boundary marker, a windowed clip and a full-scene clip on absolute
/// frames, the windowed clip's effect row with its keyframe diamonds, and
/// two audio lanes (a trimmed bed, a time-placed effect), the playhead
/// standing in scene two.
Widget _timeline() {
  final model = VideoLaneModel.build(document: EditorDocument.fromJson(_deck()), palette: _palette);
  return _frame(
    TrackTimeline(
      tracks: model.tracks,
      markers: model.markers,
      fps: model.fps.toDouble(),
      totalFrames: model.totalFrames.toDouble(),
      playhead: 130,
      controller: TrackTimelineController(pixelsPerFrame: 2),
    ),
  );
}

Future<void> main() async {
  await goldenTest(
    'the timeline shows a clip dissolve and a source-preserving speed ramp',
    fileName: 'transition_speed_timeline',
    builder: () => GoldenTestGroup(
      columns: 1,
      children: [
        GoldenTestScenario(
          name: 'overlapping clips, dissolve window, speed ramp',
          child: _timeline(),
        ),
      ],
    ),
  );
}
