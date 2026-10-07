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
  'size': {'width': 320, 'height': 180},
  'fps': 30,
  'audio': [
    {
      'kind': 'music',
      'source': {'kind': 'asset', 'value': 'audio/bed.mp3'},
      'trim': {'from': '0f', 'to': '150f'},
    },
    {
      'kind': 'sfx',
      'source': {'kind': 'asset', 'value': 'audio/whoosh.wav'},
      'at': {'kind': 'at', 'time': '30f'},
    },
  ],
  'scenes': <Object?>[
    {
      'duration': '120f',
      'children': [
        {
          'id': 'el-clip',
          'type': 'Clip',
          'source': {'kind': 'asset', 'value': 'clips/broll.mp4'},
          'show': {'from': '20f', 'to': '100f'},
          'effects': [
            {
              'kind': 'vignette',
              'amount': {
                'values': [0, 0.7, 0.2],
                'positions': ['10f', '40f', '70f'],
              },
            },
          ],
        },
      ],
    },
    {
      'duration': '90f',
      'children': [
        {
          'id': 'el-outro',
          'type': 'Clip',
          'source': {'kind': 'asset', 'value': 'clips/outro.mp4'},
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
    'the video timeline lays the whole composition on one absolute ruler',
    fileName: 'video_mode_timeline',
    builder: () => GoldenTestGroup(
      columns: 1,
      children: [
        GoldenTestScenario(
          name: 'scene blocks, clip lanes, an effect row, and two audio lanes',
          child: _timeline(),
        ),
      ],
    ),
  );
}
