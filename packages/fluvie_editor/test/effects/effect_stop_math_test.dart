// Pure math for keyframed effect-parameter stops on a timeline bar: where
// the diamonds sit, and what an insert reads at the frame it lands on. The
// move and rescale laws are the animation stops' own, shared unchanged.

import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie_editor/fluvie_editor.dart';

Map<String, Object?> _ramp({List<Object?>? easings}) => {
  'values': [0, 1],
  'positions': ['0f', '60f'],
  'easings': ?easings,
};

void main() {
  group('keyframedValueStopFrames', () {
    test('resolves each authored position against the bar span', () {
      expect(
        keyframedValueStopFrames(
          {
            'values': [0, 0.5, 1],
            'positions': ['0f', '30f', '60f'],
          },
          spanFrames: 60,
          fps: 30,
        ),
        [0, 30, 60],
      );
    });

    test('resolves seconds and relative forms the same way a render would', () {
      expect(
        keyframedValueStopFrames(
          {
            'values': [0, 1],
            'positions': ['0f', '1s'],
          },
          spanFrames: 60,
          fps: 30,
        ),
        [0, 30],
      );
    });

    test('is null for a plain number, which is the other case', () {
      expect(keyframedValueStopFrames(0.4, spanFrames: 60, fps: 30), isNull);
      expect(keyframedValueStopFrames(null, spanFrames: 60, fps: 30), isNull);
    });
  });

  group('insertedEffectStop', () {
    test('reads the inserted value off the ramp at the landing frame', () {
      final inserted = insertedEffectStop(
        param: _ramp(),
        stopFrames: const [0, 60],
        offset: 30,
        spanFrames: 60,
        fps: 30,
      )!;

      expect(inserted.stop, 1);
      expect(inserted.value, closeTo(0.5, 1e-9));
      expect(inserted.positionFrames, [0, 30, 60]);
    });

    test('respects the segment easing, so the diamond changes nothing visually', () {
      final linear = insertedEffectStop(
        param: _ramp(),
        stopFrames: const [0, 60],
        offset: 15,
        spanFrames: 60,
        fps: 30,
      )!;
      final eased = insertedEffectStop(
        param: _ramp(easings: ['smooth']),
        stopFrames: const [0, 60],
        offset: 15,
        spanFrames: 60,
        fps: 30,
      )!;

      expect(linear.value, closeTo(0.25, 1e-9));
      expect(eased.value, isNot(closeTo(0.25, 1e-6)));
    });

    test('a boundary insert copies the boundary value', () {
      final inserted = insertedEffectStop(
        param: {
          'values': [0.2, 0.8],
          'positions': ['20f', '40f'],
        },
        stopFrames: const [20, 40],
        offset: 5,
        spanFrames: 60,
        fps: 30,
      )!;

      expect(inserted.stop, 0);
      expect(inserted.value, 0.2);
      expect(inserted.positionFrames, [5, 20, 40]);
    });

    test('is null where a stop already sits', () {
      expect(
        insertedEffectStop(
          param: _ramp(),
          stopFrames: const [0, 60],
          offset: 60,
          spanFrames: 60,
          fps: 30,
        ),
        isNull,
      );
    });
  });
}
