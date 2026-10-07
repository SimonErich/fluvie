import 'package:fluvie/src/core/color/cube_lut.dart';
import 'package:fluvie/src/core/errors/fluvie_spec_error.dart';
import 'package:fluvie/src/serialization/codecs/particles_codec.dart';

/// Validates structured parameters at parse time, before an editor accepts
/// a command. A malformed edit never waits until preview paint to fail.
void validateEffectObjects(String kind, Map<String, Object?> params, List<String> path) {
  if (params['asset'] case final String asset) {
    if (asset.startsWith('/') ||
        asset.startsWith(r'\') ||
        asset.contains(':') ||
        asset.split(RegExp(r'[/\\]')).contains('..')) {
      throw FluvieSpecError(
        'A $kind asset must be a plain relative path',
        path: [...path, 'asset'],
      );
    }
  }
  if (params['cube'] case final String cube) CubeLut.parse(cube);
  if (params['uniforms'] case final Map<String, Object?> uniforms) {
    for (final entry in uniforms.entries) {
      if (entry.key.isEmpty || entry.value is! num || !(entry.value! as num).isFinite) {
        throw FluvieSpecError(
          'Shader uniforms must be named finite numbers',
          path: [...path, 'uniforms', entry.key],
        );
      }
    }
  }
  if (params['particles'] case final Map<String, Object?> particles) {
    decodeParticles(particles, path: [...path, 'particles']);
  }
  if (params['curves'] case final Map<String, Object?> curves) {
    for (final entry in curves.entries) {
      final location = [...path, 'curves', entry.key];
      if (!const {'master', 'red', 'green', 'blue'}.contains(entry.key)) {
        throw FluvieSpecError('Unknown curve channel', path: location);
      }
      final points = entry.value;
      if (points is! List || points.length < 2 || points.length > 64) {
        throw FluvieSpecError('A curve needs 2 to 64 points', path: location);
      }
      var previous = -1.0;
      for (final point in points) {
        if (point is! List ||
            point.length != 2 ||
            point.any((v) => v is! num || !v.isFinite || v < 0 || v > 1)) {
          throw FluvieSpecError('Curve points must be [x, y] pairs in [0, 1]', path: location);
        }
        final x = (point.first! as num).toDouble();
        if (x <= previous) {
          throw FluvieSpecError('Curve positions must strictly increase', path: location);
        }
        previous = x;
      }
    }
  }
}
