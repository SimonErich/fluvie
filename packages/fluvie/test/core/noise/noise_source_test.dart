import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/core/noise/noise_source.dart';

/// A trivial conforming implementation proving the contract is pure (no widget
/// or IO deps) and a non-`ValueNoise` impl can satisfy it.
final class _ConstantNoise implements NoiseSource {
  const _ConstantNoise(this.value);

  final double value;

  @override
  double valueForSeed(String seed) => value;

  @override
  double noise1(double x) => value;

  @override
  double noise2(double x, double y) => value;
}

void main() {
  group('NoiseSource — contract (WI-8, D2/D7)', () {
    test('a trivial impl satisfies the three-member interface', () {
      const NoiseSource noise = _ConstantNoise(0.5);
      expect(noise.valueForSeed('any'), 0.5);
      expect(noise.noise1(3.14), 0.5);
      expect(noise.noise2(1, 2), 0.5);
    });

    test('the contract is a NoiseSource regardless of the concrete type', () {
      expect(const _ConstantNoise(0.1), isA<NoiseSource>());
    });
  });
}
