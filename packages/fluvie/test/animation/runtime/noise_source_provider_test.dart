import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/animation/runtime/noise_source_provider.dart';
import 'package:fluvie/src/core/noise/noise_source.dart';
import 'package:fluvie/src/core/noise/value_noise.dart';
import 'package:riverpod/riverpod.dart';

class _FakeNoise implements NoiseSource {
  const _FakeNoise();

  @override
  double valueForSeed(String seed) => 0.42;

  @override
  double noise1(double x) => 0.42;

  @override
  double noise2(double x, double y) => 0.42;
}

void main() {
  group('noiseSourceProvider (WI-13, D-NoiseProvider)', () {
    test('a fresh container resolves the const ValueNoise default', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(noiseSourceProvider), isA<ValueNoise>());
      expect(container.read(noiseSourceProvider), const ValueNoise());
    });

    test('the default source produces the same scalar as a bare ValueNoise', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final resolved = container.read(noiseSourceProvider);
      expect(resolved.valueForSeed('leaf-7'), const ValueNoise().valueForSeed('leaf-7'));
    });

    test('is overridable with an injected fake', () {
      const fake = _FakeNoise();
      final container = ProviderContainer(
        overrides: [noiseSourceProvider.overrideWithValue(fake)],
      );
      addTearDown(container.dispose);

      expect(container.read(noiseSourceProvider), same(fake));
      expect(container.read(noiseSourceProvider).valueForSeed('anything'), 0.42);
    });

    test('a read container disposes cleanly', () {
      final container = ProviderContainer()..read(noiseSourceProvider);
      expect(container.dispose, returnsNormally);
    });
  });
}
