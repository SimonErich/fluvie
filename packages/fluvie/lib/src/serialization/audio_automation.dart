import 'package:fluvie/src/animation/keyframed_number.dart';
import 'package:fluvie/src/core/audio/audio_automation.dart';
import 'package:fluvie/src/core/errors/fluvie_spec_error.dart';

export 'package:fluvie/src/core/audio/audio_automation.dart';

/// Parses audio automation with precisely the V5 numeric keyframe grammar.
AudioAutomation decodeAudioAutomation(Object? raw, {List<String> path = const []}) {
  if (raw == null) return const AudioAutomation();
  if (raw is! Map<String, Object?> || raw.keys.any((key) => key != 'volume')) {
    throw FluvieSpecError('Automation is an object containing only "volume"', path: path);
  }
  final volume = raw['volume'];
  if (volume == null) return const AudioAutomation();
  if (volume is num && volume.isFinite) {
    return AudioAutomation(values: [volume.toDouble().clamp(0.0, 1.0)]);
  }
  final keyframes = KeyframedNumber.maybeFromJson(volume, path: [...path, 'volume']);
  if (keyframes == null || keyframes.values.any((v) => !v.isFinite)) {
    throw FluvieSpecError(
      'Automation volume must be a finite number or keyframed value',
      path: [...path, 'volume'],
    );
  }
  return AudioAutomation(
    values: keyframes.values.map((v) => v.clamp(0.0, 1.0)).toList(),
    positions: keyframes.positions,
    easings: keyframes.easings,
  );
}

/// Canonical automation; absent envelopes have no document representation.
Map<String, Object?> encodeAudioAutomation(AudioAutomation automation) => {
  if (automation.values.length == 1) 'volume': automation.values.single,
  if (automation.values.length > 1)
    'volume': KeyframedNumber(
      values: automation.values,
      positions: automation.positions,
      easings: automation.easings,
    ).toJson(),
};
