import 'dart:ui' show Color;

import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie_editor/fluvie_editor.dart';

const _palette = TimelinePhasePalette(
  enter: Color(0xFF46A758),
  during: Color(0xFFFFB224),
  exit: Color(0xFFE5484D),
);

Map<String, Object?> _deck({List<Map<String, Object?>>? animate}) => {
  'fluvieSpec': 1,
  'size': {'width': 320, 'height': 180},
  'fps': 30,
  'scenes': [
    {
      'duration': '120f',
      'children': [
        {
          'id': 'el-k',
          'type': 'Box',
          'width': 80,
          'height': 40,
          'animate':
              animate ??
              [
                {
                  'keyframes': [
                    {'opacity': 0},
                    {'x': 0.5},
                    <String, Object?>{},
                  ],
                  'duration': '30f',
                },
              ],
        },
      ],
    },
  ],
};

SlideTimelineModel _model(Map<String, Object?> deck) => SlideTimelineModel.build(
  document: EditorDocument.fromJson(deck),
  slide: 0,
  palette: _palette,
  linkPalette: const TimelineLinkPalette(ends: Color(0xFF0000FF), starts: Color(0xFF00FFFF)),
);

void main() {
  group('keyframeStopFrames', () {
    test('a preset animation resolves no stops', () {
      expect(
        keyframeStopFrames(const {'preset': 'fadeIn'}, spanFrames: 30, fps: 30),
        isNull,
      );
    });

    test('stops without positions space evenly across the span', () {
      final frames = keyframeStopFrames(
        const {
          'keyframes': [<String, Object?>{}, <String, Object?>{}, <String, Object?>{}],
        },
        spanFrames: 30,
        fps: 30,
      );
      expect(frames, [0, 15, 30]);
    });

    test('frames-form positions resolve verbatim', () {
      final frames = keyframeStopFrames(
        const {
          'keyframes': [<String, Object?>{}, <String, Object?>{}, <String, Object?>{}],
          'positions': ['0f', '10f', '30f'],
        },
        spanFrames: 30,
        fps: 30,
      );
      expect(frames, [0, 10, 30]);
    });

    test('seconds and relative positions resolve against the span', () {
      final frames = keyframeStopFrames(
        const {
          'keyframes': [<String, Object?>{}, <String, Object?>{}, <String, Object?>{}],
          'positions': ['0f', '0.5s', '1r'],
        },
        spanFrames: 30,
        fps: 30,
      );
      expect(frames, [0, 15, 30]);
    });
  });

  group('the model grows diamonds on keyframes bars', () {
    test('one diamond per stop, placed on the resolved frame', () {
      final model = _model(_deck());
      final bar = model.tracks.single.bars.single;
      expect(bar.diamonds.map((d) => d.frame), [
        bar.start,
        bar.start + 15,
        bar.start + 30,
      ]);
      // Each diamond binds back to its stop.
      for (var i = 0; i < 3; i++) {
        final binding = model.diamondBindings[bar.diamonds[i].id]!;
        expect(binding.barId, bar.id);
        expect(binding.stop, i);
      }
      expect(model.bindings[bar.id]!.stopFrames, [0, 15, 30]);
    });

    test('authored positions place the diamonds unevenly', () {
      final model = _model(
        _deck(
          animate: [
            {
              'keyframes': [<String, Object?>{}, <String, Object?>{}, <String, Object?>{}],
              'positions': ['0f', '6f', '30f'],
              'duration': '30f',
            },
          ],
        ),
      );
      final bar = model.tracks.single.bars.single;
      expect(bar.diamonds.map((d) => d.frame), [bar.start, bar.start + 6, bar.start + 30]);
    });

    test('preset bars stay diamond-free with a null stopFrames binding', () {
      final model = _model(
        _deck(
          animate: [
            {'preset': 'fadeIn', 'duration': '30f'},
          ],
        ),
      );
      final bar = model.tracks.single.bars.single;
      expect(bar.diamonds, isEmpty);
      expect(model.bindings[bar.id]!.stopFrames, isNull);
      expect(model.diamondBindings, isEmpty);
    });
  });
}
