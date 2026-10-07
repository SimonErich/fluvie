import 'package:flutter/animation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/fluvie.dart'
    show FluvieSpecError, KeyframedNumber, decodeCurve, encodeCurve, namedEases;
import 'package:fluvie/src/serialization/anchor_table.dart';
import 'package:fluvie/src/serialization/animation_builder.dart';
import 'package:fluvie/src/serialization/animation_spec.dart';

void main() {
  test('named curves retain their canonical names and matching cubic shapes snap back', () {
    for (final entry in namedEases.entries) {
      final curve = decodeCurve(entry.key);
      expect(decodeCurve(encodeCurve(curve)), same(curve));
      if (curve is Cubic) {
        expect(encodeCurve(Cubic(curve.a, curve.b, curve.c, curve.d)), encodeCurve(curve));
      }
    }
    expect(encodeCurve(const Cubic(0, 0, 1, 1)), 'linear');
  });
  test('custom cubic curves round-trip and interpolate numeric keyframe segments', () {
    const json = {
      'cubic': [0.15, 0.7, 0.8, 0.2],
    };
    expect(encodeCurve(decodeCurve(json)), json);
    final ramp = KeyframedNumber.maybeFromJson({
      'values': [0, 1],
      'positions': ['0f', '20f'],
      'easings': [json],
    })!;
    expect(ramp.toJson()['easings'], [json]);
    expect(
      ramp.at((progress: 0.5, fps: 30, windowFrames: 20)),
      closeTo(decodeCurve(json).transform(0.5), 1e-8),
    );
  });
  test('ambient presets retain an authored progress curve', () {
    const json = {
      'cubic': [0.2, 0.9, 0.6, 1],
    };
    for (final preset in ['float', 'pulse', 'drift', 'spin', 'kenBurns']) {
      final spec = AnimationSpec.fromJson({'preset': preset, 'ease': json}, AnchorTable());
      final built = buildAnimation(spec, AnchorTable());
      expect(encodeCurve(built.ease!), json, reason: preset);
    }
  });
  test('malformed cubic shapes and x controls outside the time domain fail', () {
    for (final raw in [
      {
        'cubic': [0, 0, 1],
      },
      {
        'cubic': [-0.1, 0, 1, 1],
      },
      {
        'cubic': [0, double.nan, 1, 1],
      },
      {
        'cubic': [0, 0, 1, 1],
        'other': true,
      },
    ]) {
      expect(() => decodeCurve(raw), throwsA(isA<FluvieSpecError>()));
    }
  });
}
