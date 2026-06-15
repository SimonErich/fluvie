import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/animation/runtime/noise_scope.dart';
import 'package:fluvie/src/core/noise/noise_source.dart';
import 'package:fluvie/src/core/noise/value_noise.dart';

class _FakeNoise implements NoiseSource {
  const _FakeNoise();

  @override
  double valueForSeed(String seed) => 0.123;

  @override
  double noise1(double x) => 0.123;

  @override
  double noise2(double x, double y) => 0.123;
}

/// Reads the resolved source through [NoiseScope.of] under [source] (or none).
Future<NoiseSource> _resolve(WidgetTester tester, {NoiseSource? source}) async {
  late NoiseSource resolved;
  Widget reader = Builder(
    builder: (context) {
      resolved = NoiseScope.of(context);
      return const SizedBox();
    },
  );
  if (source != null) {
    reader = NoiseScope(source: source, child: reader);
  }
  await tester.pumpWidget(reader);
  return resolved;
}

void main() {
  group('NoiseScope.of (WI-13, D-NoiseProvider)', () {
    testWidgets('defaults to const ValueNoise with no scope above', (tester) async {
      final resolved = await _resolve(tester);
      expect(resolved, isA<ValueNoise>());
      expect(resolved, const ValueNoise());
    });

    testWidgets('reads the scope source when one is mounted', (tester) async {
      const fake = _FakeNoise();
      final resolved = await _resolve(tester, source: fake);
      expect(resolved, same(fake));
      expect(resolved.valueForSeed('x'), 0.123);
    });

    testWidgets('the no-scope default resolves the same source ctx.noise will', (tester) async {
      final resolved = await _resolve(tester);
      // ctx.noise reads NoiseScope.of too, so the effects and ctx.noise agree.
      expect(resolved.valueForSeed('petal-3'), const ValueNoise().valueForSeed('petal-3'));
    });
  });

  group('NoiseScope.maybeOf', () {
    testWidgets('returns null with no scope above', (tester) async {
      late NoiseSource? resolved;
      await tester.pumpWidget(
        Builder(
          builder: (context) {
            resolved = NoiseScope.maybeOf(context);
            return const SizedBox();
          },
        ),
      );
      expect(resolved, isNull);
    });

    testWidgets('returns the scope source when one is mounted', (tester) async {
      const fake = _FakeNoise();
      late NoiseSource? resolved;
      await tester.pumpWidget(
        NoiseScope(
          source: fake,
          child: Builder(
            builder: (context) {
              resolved = NoiseScope.maybeOf(context);
              return const SizedBox();
            },
          ),
        ),
      );
      expect(resolved, same(fake));
    });
  });

  group('NoiseScope.updateShouldNotify', () {
    testWidgets('notifies only when the source changes', (tester) async {
      const a = ValueNoise();
      const b = _FakeNoise();
      const child = SizedBox();
      const same = NoiseScope(source: a, child: child);
      const changed = NoiseScope(source: b, child: child);
      expect(same.updateShouldNotify(const NoiseScope(source: a, child: child)), isFalse);
      expect(changed.updateShouldNotify(const NoiseScope(source: a, child: child)), isTrue);
    });
  });
}
