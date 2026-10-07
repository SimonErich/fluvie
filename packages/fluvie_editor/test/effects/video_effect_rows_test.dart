// The effect rows of the video timeline: one row per effect under its
// element's bar, diamonds where a keyframed parameter has stops, and the
// bindings that turn a diamond edit back into a document command.

import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/fluvie.dart' show FrameSpan;
import 'package:fluvie_editor/fluvie_editor.dart';

Map<String, Object?> _deck() => {
  'fluvieSpec': 1,
  'size': {'width': 320, 'height': 180},
  'fps': 30,
  'lanes': [
    {'id': 'v1', 'name': 'V1'},
  ],
  'overlays': [
    {
      'id': 'el-logo',
      'type': 'Text',
      'text': 'logo',
      'effects': [
        {'kind': 'bloom', 'amount': 0.3},
      ],
    },
  ],
  'scenes': [
    {
      'duration': '120f',
      'children': [
        {
          'id': 'el-clip',
          'type': 'Clip',
          'source': {'kind': 'asset', 'value': 'clips/broll.mp4'},
          'effects': [
            {'kind': 'grain', 'amount': 0.2},
            {
              'kind': 'vignette',
              'amount': {
                'values': [0, 0.5, 0.9],
                'positions': ['0f', '60f', '120f'],
              },
            },
          ],
        },
        {
          'id': 'el-laned',
          'type': 'Text',
          'text': 'on a lane',
          'lane': 'v1',
          'show': {'from': '30f', 'to': '90f'},
          'effects': [
            {
              'kind': 'grain',
              'amount': {
                'values': [0.1, 0.4],
                'positions': ['0f', '60f'],
              },
            },
          ],
        },
        {
          'id': 'el-plain',
          'type': 'Text',
          'text': 'canvas only',
          'effects': [
            {'kind': 'vignette', 'amount': 0.4},
          ],
        },
        {
          'id': 'el-shaded',
          'type': 'Box',
          'color': '#333344',
          'show': {'from': '0f', 'to': '60f'},
          'effects': [
            {
              'kind': 'shader',
              'asset': 'shaders/warp.frag',
              'uniforms': {
                'values': 1.0,
                'positions': 0.25,
              },
            },
          ],
        },
      ],
    },
  ],
};

VideoLaneModel _model() => VideoLaneModel.build(document: EditorDocument.fromJson(_deck()));

TimelineTrack _track(VideoLaneModel model, String id) =>
    model.tracks.firstWhere((track) => track.id == id);

void main() {
  group('effect rows', () {
    test('one row per effect, indented under the element row', () {
      final model = _model();
      final ids = model.tracks.map((track) => track.id).toList();

      final element = ids.indexOf('el-track:el-clip');
      expect(ids.indexOf('fx-track:el-clip:0'), element + 1);
      expect(ids.indexOf('fx-track:el-clip:1'), element + 2);
      expect(_track(model, 'fx-track:el-clip:0').label, 'grain');
      expect(_track(model, 'fx-track:el-clip:0').depth, 1);
      expect(_track(model, 'fx-track:el-clip:1').label, 'vignette');
    });

    test('the bar spans the element window and a still effect has no diamonds', () {
      final model = _model();
      final bar = _track(model, 'fx-track:el-clip:0').bars.single;

      expect(bar.id, 'fx:el-clip:0');
      expect(bar.start, 0);
      expect(bar.end, 120);
      expect(bar.diamonds, isEmpty);
    });

    test('a keyframed parameter draws one diamond per stop, on absolute frames', () {
      final model = _model();
      final bar = _track(model, 'fx-track:el-clip:1').bars.single;

      expect(bar.diamonds.map((diamond) => diamond.id), [
        'fx:el-clip:1:amount:k0',
        'fx:el-clip:1:amount:k1',
        'fx:el-clip:1:amount:k2',
      ]);
      expect(bar.diamonds.map((diamond) => diamond.frame), [0, 60, 120]);
    });

    test('a canvas-only element grows no effect rows', () {
      // Its element has no bar for the rows to sit under; the Effects tab is
      // the way in (V5.4), exactly as canvas-only timing lives in slides mode.
      expect(
        _model().tracks.map((track) => track.id),
        isNot(contains('fx-track:el-plain:0')),
      );
    });

    test('an element on a declared lane keeps its effects reachable, named for it', () {
      final model = _model();
      final track = _track(model, 'fx-track:el-laned:0');

      expect(track.label, 'Text · grain');
      expect(track.depth, 0);
      // The window is 30..90, so the two stops land at 30 and 90.
      expect(track.bars.single.diamonds.map((diamond) => diamond.frame), [30, 90]);
    });

    test('a shader uniform named "values" draws no diamonds and does not crash', () {
      // "values" names a float slot on this shader, not a ramp. Only the
      // kind's own numeric parameters can carry stops.
      final model = _model();
      final bar = _track(model, 'fx-track:el-shaded:0').bars.single;

      expect(bar.diamonds, isEmpty);
      expect(model.effectBars['fx:el-shaded:0']!.stopFramesByParam, isEmpty);
    });

    test('an overlay carries its effect rows too', () {
      final model = _model();
      final track = _track(model, 'fx-track:el-logo:0');

      expect(track.label, 'bloom');
      expect(track.bars.single.start, 0);
      expect(track.bars.single.end, 120);
    });
  });

  group('effect bindings', () {
    test('a bar binds back to its element and effect, stops per parameter', () {
      final model = _model();
      final binding = model.effectBars['fx:el-clip:1']!;

      expect(binding.elementId, 'el-clip');
      expect(binding.effectIndex, 1);
      expect(binding.window, const FrameSpan(0, 120));
      expect(binding.stopFramesByParam, {
        'amount': [0, 60, 120],
      });
      expect(model.effectBars['fx:el-clip:0']!.stopFramesByParam, isEmpty);
    });

    test('a diamond binds back to its parameter and stop', () {
      final model = _model();
      final diamond = model.effectDiamonds['fx:el-clip:1:amount:k1']!;

      expect(diamond.elementId, 'el-clip');
      expect(diamond.effectIndex, 1);
      expect(diamond.param, 'amount');
      expect(diamond.stop, 1);
    });
  });
}
