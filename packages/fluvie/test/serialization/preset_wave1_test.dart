import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/fluvie.dart' show Animation, knownAnimationPresets;
import 'package:fluvie/src/core/errors/fluvie_spec_error.dart';
import 'package:fluvie/src/serialization/anchor_table.dart';
import 'package:fluvie/src/serialization/animation_builder.dart';
import 'package:fluvie/src/serialization/animation_spec.dart';

/// Parses one animation node, checks the round-trip, and builds it.
Animation _build(Map<String, Object?> json) {
  final table = AnchorTable();
  final spec = AnimationSpec.fromJson(json, table);
  expect(spec.toJson(), json, reason: 'the codec round-trip is identity');
  return buildAnimation(spec, table);
}

void main() {
  test('the wave-1 tranche joins the preset table', () {
    expect(
      knownAnimationPresets,
      containsAll(['maskWipeIn', 'maskWipeOut', 'glitchIn', 'glitchOut', 'float', 'pulse']),
    );
  });

  test('every tranche preset parses, round-trips, and builds', () {
    expect(_build({'preset': 'maskWipeIn'}), isA<Animation>());
    expect(
      _build({
        'preset': 'maskWipeIn',
        'shape': 'diagonal',
        'origin': 'topLeft',
        'duration': '12f',
      }),
      isA<Animation>(),
    );
    expect(_build({'preset': 'maskWipeOut', 'shape': 'rect'}), isA<Animation>());
    expect(_build({'preset': 'glitchIn', 'from': 'left'}), isA<Animation>());
    expect(_build({'preset': 'glitchOut', 'to': 'right'}), isA<Animation>());
    expect(
      _build({'preset': 'float', 'amplitude': 0.08, 'period': '2s', 'seed': 'bob'}),
      isA<Animation>(),
    );
    expect(
      _build({'preset': 'pulse', 'min': 0.9, 'max': 1.1, 'period': '1s'}),
      isA<Animation>(),
    );
  });

  test('bad tranche arguments fail at parse-adjacent build time', () {
    expect(
      () => _build({'preset': 'maskWipeIn', 'shape': 'pentagon'}),
      throwsA(isA<FluvieSpecError>()),
    );
    expect(
      () => _build({'preset': 'glitchIn', 'from': 'sideways'}),
      throwsA(isA<FluvieSpecError>()),
    );
  });
}
