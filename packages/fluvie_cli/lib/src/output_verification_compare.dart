part of 'output_verification.dart';

const _intentKeys = [
  'width',
  'height',
  'fps',
  'frameCount',
  'durationSeconds',
  'codec',
  'container',
  'pixelFormat',
  'hasAudio',
  'hasAlpha',
];

void _validateIntent(Map<String, Object?> expected) {
  for (final entry in expected.entries) {
    final key = entry.key;
    final value = entry.value;
    if (!_intentKeys.contains(key)) throw FormatException('Unknown output intent key: $key');
    final valid = switch (key) {
      'width' || 'height' => value is int && value > 0,
      'frameCount' => value is int && value >= 0,
      'fps' => value is num && value.isFinite && value > 0,
      'durationSeconds' => value is num && value.isFinite && value >= 0,
      'hasAudio' || 'hasAlpha' => value is bool,
      _ => value is String && value.isNotEmpty,
    };
    if (!valid) throw FormatException('Invalid output intent $key: $value');
  }
}

List<Map<String, Object?>> _compareIntent(
  Map<String, Object?> expected,
  Map<String, Object?> actual,
) => [
  for (final key in _intentKeys)
    if (expected.containsKey(key) && !_matches(key, expected[key], actual[key], actual))
      {'code': key, 'expected': expected[key], 'actual': actual[key]},
];

bool _matches(String key, Object? expected, Object? actual, Map<String, Object?> facts) {
  if (key == 'container' && expected is String && actual is String) {
    // ffprobe reports demuxer families, e.g. mov,mp4,m4a,3gp,3g2,mj2.
    return actual.split(',').contains(expected);
  }
  if (expected is num && actual is num) {
    if (key == 'fps') return (expected - actual).abs() <= expected.abs() * .001;
    if (key == 'durationSeconds') {
      final fps = facts['fps'];
      final tolerance = fps is num && fps > 0 && 1 / fps > .05 ? 1 / fps : .05;
      return (expected - actual).abs() <= tolerance + .000001;
    }
  }
  return expected == actual;
}
