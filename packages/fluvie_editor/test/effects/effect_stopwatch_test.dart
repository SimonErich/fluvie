// The stopwatch's two directions: a literal becomes a flat two-stop ramp
// over the element's own window (the picture does not change, the diamonds
// appear), and a ramp collapses to the value it reads at the playhead.

import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie_editor/fluvie_editor.dart';

Map<String, Object?> _deck() => {
  'fluvieSpec': 1,
  'size': {'width': 320, 'height': 180},
  'fps': 30,
  'overlays': [
    {'id': 'el-logo', 'type': 'Text', 'text': 'logo'},
  ],
  'scenes': [
    {
      'duration': '120f',
      'children': [
        {
          'id': 'el-win',
          'type': 'Box',
          'show': {'from': '30f', 'to': '90f'},
        },
        {'id': 'el-bare', 'type': 'Box'},
      ],
    },
    {'duration': '60f', 'children': <Object?>[]},
  ],
};

void main() {
  group('turning the stopwatch on', () {
    test('a windowed element ramps flat over its own window', () {
      final ramp = stopwatchRampFor(EditorDocument.fromJson(_deck()), 'el-win', 0.4);

      expect(ramp, {
        'values': [0.4, 0.4],
        'positions': ['0f', '60f'],
      });
    });

    test('a bare element ramps over its whole scene', () {
      final ramp = stopwatchRampFor(EditorDocument.fromJson(_deck()), 'el-bare', 0.4);

      expect(ramp['positions'], ['0f', '120f']);
    });

    test('an overlay ramps over the whole video', () {
      final ramp = stopwatchRampFor(EditorDocument.fromJson(_deck()), 'el-logo', 0.4);

      expect(ramp['positions'], ['0f', '180f']);
    });
  });

  group('turning it off', () {
    test('reads the ramp at the playhead fraction of the element window', () {
      final value = stopwatchLiteralFor(
        EditorDocument.fromJson(_deck()),
        'el-bare',
        {
          'values': [0, 1],
          'positions': ['0f', '120f'],
        },
        progress: 0.5,
      );

      expect(value, closeTo(0.5, 1e-9));
    });

    test('resolves against the window the render uses, not the last stop', () {
      // The ramp ends at 60f but the element lives 120f: at progress 0.5 the
      // screen already shows 1.0, and what you see is what you keep.
      final value = stopwatchLiteralFor(
        EditorDocument.fromJson(_deck()),
        'el-bare',
        {
          'values': [0, 1],
          'positions': ['0f', '60f'],
        },
        progress: 0.5,
      );

      expect(value, closeTo(1, 1e-9));
    });

    test('reads seconds-authored positions exactly like the render', () {
      final value = stopwatchLiteralFor(
        EditorDocument.fromJson(_deck()),
        'el-bare',
        {
          'values': [0, 1],
          'positions': ['0s', '4s'],
        },
        progress: 0.9,
      );

      expect(value, closeTo(0.9, 1e-9));
    });

    test('an overlay reads against the whole video', () {
      final value = stopwatchLiteralFor(
        EditorDocument.fromJson(_deck()),
        'el-logo',
        {
          'values': [0, 1],
          'positions': ['0f', '180f'],
        },
        progress: 0.5,
      );

      expect(value, closeTo(0.5, 1e-9));
    });

    test('with no playhead to read at, it is the first value', () {
      final value = stopwatchLiteralFor(EditorDocument.fromJson(_deck()), 'el-bare', {
        'values': [0.2, 1],
        'positions': ['0f', '120f'],
      });

      expect(value, 0.2);
    });
  });
}
