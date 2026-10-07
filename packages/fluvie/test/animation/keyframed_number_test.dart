// A parameter that changes over its element's life. This is the shape colour,
// audio automation and transition parameters all inherit, so its rules are
// pinned here once rather than re-decided three more times.

import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/fluvie.dart';

/// A 60-frame element at 30 fps: the window every stop resolves against.
EffectFrame _at(double progress) => (progress: progress, fps: 30, windowFrames: 60);

KeyframedNumber _ramp({List<Object?>? easings}) => KeyframedNumber.maybeFromJson({
  'values': [0, 1],
  'positions': ['0f', '60f'],
  'easings': ?easings,
})!;

void main() {
  group('reading it', () {
    test('is the first value before the first stop', () {
      // Held rather than extrapolated: a parameter must never take a value
      // nobody authored just because the playhead left the span.
      final ramp = KeyframedNumber.maybeFromJson({
        'values': [0.2, 0.8],
        'positions': ['20f', '40f'],
      })!;

      expect(ramp.at(_at(0)), 0.2);
      expect(ramp.at(_at(0.1)), 0.2);
    });

    test('is the last value after the last stop', () {
      final ramp = KeyframedNumber.maybeFromJson({
        'values': [0.2, 0.8],
        'positions': ['20f', '40f'],
      })!;

      expect(ramp.at(_at(0.9)), 0.8);
      expect(ramp.at(_at(1)), 0.8);
    });

    test('lands exactly on each stop', () {
      final ramp = _ramp();

      expect(ramp.at(_at(0)), 0);
      expect(ramp.at(_at(1)), 1);
    });

    test('interpolates linearly between two stops by default', () {
      expect(_ramp().at(_at(0.25)), closeTo(0.25, 1e-9));
      expect(_ramp().at(_at(0.5)), closeTo(0.5, 1e-9));
      expect(_ramp().at(_at(0.75)), closeTo(0.75, 1e-9));
    });

    test('shapes a segment by its own easing', () {
      // Not linear any more, but still pinned at both ends.
      final eased = _ramp(easings: ['smooth']);

      expect(eased.at(_at(0)), 0);
      expect(eased.at(_at(1)), 1);
      expect(eased.at(_at(0.25)), isNot(closeTo(0.25, 1e-6)));
    });

    test('walks three stops through both of its segments', () {
      final ramp = KeyframedNumber.maybeFromJson({
        'values': [0, 1, 0],
        'positions': ['0f', '30f', '60f'],
      })!;

      expect(ramp.at(_at(0)), 0);
      expect(ramp.at(_at(0.5)), closeTo(1, 1e-9));
      expect(ramp.at(_at(0.75)), closeTo(0.5, 1e-9));
      expect(ramp.at(_at(1)), 0);
    });

    test('reads the same number twice for the same frame', () {
      // The determinism the capture model needs: no clock, no state.
      final ramp = _ramp(easings: ['back']);

      expect(ramp.at(_at(0.4)), ramp.at(_at(0.4)));
    });

    test('holds its first value on an element with no length at all', () {
      expect(_ramp().at((progress: 0.5, fps: 30, windowFrames: 0)), 0);
    });

    test('handles two stops that resolve to one frame without dividing by zero', () {
      // Same-clock duplicates are refused at parse; mixed clocks can still
      // collide once the resolver runs them ('30f' and '1s' at 30 fps), and
      // that collision must not divide by zero.
      final ramp = KeyframedNumber.maybeFromJson({
        'values': [0, 1, 2],
        'positions': ['0f', '30f', '1s'],
      })!;

      expect(ramp.at(_at(0.5)), isA<double>());
      expect(ramp.at(_at(1)), 2);
    });
  });

  group('what it is not', () {
    test('a plain number, which is the other case rather than an error', () {
      expect(KeyframedNumber.maybeFromJson(0.5), isNull);
      expect(KeyframedNumber.maybeFromJson(null), isNull);
    });
  });

  group('what it refuses', () {
    void refuses(Map<String, Object?> json) => expect(
      () => KeyframedNumber.maybeFromJson(json),
      throwsA(isA<FluvieSpecError>()),
      reason: '$json',
    );

    test('an object with no values', () {
      refuses({
        'positions': ['0f'],
      });
    });

    test('one stop, which is a plain number wearing a list', () {
      refuses({
        'values': [1],
        'positions': ['0f'],
      });
    });

    test('a value that is not a number', () {
      refuses({
        'values': [0, 'lots'],
        'positions': ['0f', '30f'],
      });
    });

    test('the wrong number of positions', () {
      refuses({
        'values': [0, 1],
        'positions': ['0f'],
      });
    });

    test('the wrong number of easings', () {
      refuses({
        'values': [0, 1, 2],
        'positions': ['0f', '30f', '60f'],
        'easings': ['smooth'],
      });
    });

    test('an easing nobody has heard of', () {
      refuses({
        'values': [0, 1],
        'positions': ['0f', '30f'],
        'easings': ['wobbly'],
      });
    });

    test('positions that do not increase', () {
      // The same-clock rule the keyframes animation form applies: comparable
      // positions must strictly increase, and a reversed pair is refused at
      // parse rather than rendering an unauthored hard cut.
      refuses({
        'values': [0, 1],
        'positions': ['2s', '1s'],
      });
      refuses({
        'values': [0, 1, 2],
        'positions': ['0f', '30f', '30f'],
      });
    });

    test('mixed clocks defer ordering to the resolver, exactly like keyframes', () {
      expect(
        KeyframedNumber.maybeFromJson({
          'values': [0, 1],
          'positions': ['10f', '0.9r'],
        }),
        isA<KeyframedNumber>(),
      );
    });

    test('a key that is not part of the shape', () {
      refuses({
        'values': [0, 1],
        'positions': ['0f', '30f'],
        'wobble': 2,
      });
    });
  });

  group('the linear shorthand', () {
    test('is the full form with every segment linear', () {
      final ramp = KeyframedNumber.linear(
        values: const [0, 1],
        positions: const [Time.zero, Time.frames(60)],
      );

      expect(ramp.easings, hasLength(1));
      expect(ramp.at(_at(0.5)), closeTo(0.5, 1e-9));
      expect(ramp.toJson().containsKey('easings'), isFalse);
    });
  });

  group('writing it back', () {
    test('round-trips its stops and positions', () {
      final json = _ramp().toJson();

      expect(json['values'], [0.0, 1.0]);
      expect(json['positions'], ['0f', '60f']);
      expect(KeyframedNumber.maybeFromJson(json)!.at(_at(0.5)), closeTo(0.5, 1e-9));
    });

    test('leaves easings out when every segment is linear', () {
      // The default says the same thing with less to read.
      expect(_ramp().toJson().containsKey('easings'), isFalse);
    });

    test('writes easings when one segment says otherwise', () {
      expect(_ramp(easings: ['smooth']).toJson()['easings'], ['smooth']);
    });
  });
}
