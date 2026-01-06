import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/declarative/effects/effect_overlay.dart';
import '../../../helpers/test_helpers.dart';

void main() {
  group('EffectOverlay', () {
    group('EffectType enum', () {
      test('has all expected types', () {
        expect(EffectType.values, hasLength(6));
        expect(EffectType.values, contains(EffectType.scanlines));
        expect(EffectType.values, contains(EffectType.grain));
        expect(EffectType.values, contains(EffectType.vignette));
        expect(EffectType.values, contains(EffectType.grid));
        expect(EffectType.values, contains(EffectType.crt));
        expect(EffectType.values, contains(EffectType.chromaticAberration));
      });
    });

    group('construction', () {
      test('creates with required type', () {
        const overlay = EffectOverlay(type: EffectType.scanlines);

        expect(overlay.type, EffectType.scanlines);
      });

      test('has default values', () {
        const overlay = EffectOverlay(type: EffectType.vignette);

        expect(overlay.intensity, 0.5);
        expect(overlay.color, isNull);
        expect(overlay.randomSeed, isNull);
      });

      test('accepts custom values', () {
        const overlay = EffectOverlay(
          type: EffectType.grid,
          intensity: 0.8,
          color: Colors.red,
          randomSeed: 123,
        );

        expect(overlay.type, EffectType.grid);
        expect(overlay.intensity, 0.8);
        expect(overlay.color, Colors.red);
        expect(overlay.randomSeed, 123);
      });
    });

    group('factory constructors', () {
      test('scanlines creates correct type', () {
        const overlay = EffectOverlay.scanlines();

        expect(overlay.type, EffectType.scanlines);
        expect(overlay.intensity, 0.02);
      });

      test('scanlines accepts custom intensity', () {
        const overlay = EffectOverlay.scanlines(intensity: 0.05);

        expect(overlay.intensity, 0.05);
      });

      test('grain creates correct type', () {
        const overlay = EffectOverlay.grain();

        expect(overlay.type, EffectType.grain);
        expect(overlay.intensity, 0.06);
      });

      test('grain accepts custom parameters', () {
        const overlay = EffectOverlay.grain(intensity: 0.1, randomSeed: 42);

        expect(overlay.intensity, 0.1);
        expect(overlay.randomSeed, 42);
      });

      test('vignette creates correct type', () {
        const overlay = EffectOverlay.vignette();

        expect(overlay.type, EffectType.vignette);
        expect(overlay.intensity, 0.4);
      });

      test('vignette accepts custom intensity', () {
        const overlay = EffectOverlay.vignette(intensity: 0.6);

        expect(overlay.intensity, 0.6);
      });

      test('grid creates correct type', () {
        const overlay = EffectOverlay.grid();

        expect(overlay.type, EffectType.grid);
        expect(overlay.intensity, 0.05);
        expect(overlay.color, const Color(0xFFFFFFFF));
      });

      test('grid accepts custom parameters', () {
        const overlay = EffectOverlay.grid(
          intensity: 0.1,
          color: Colors.blue,
        );

        expect(overlay.intensity, 0.1);
        expect(overlay.color, Colors.blue);
      });

      test('crt creates correct type', () {
        const overlay = EffectOverlay.crt();

        expect(overlay.type, EffectType.crt);
        expect(overlay.intensity, 0.3);
      });

      test('crt accepts custom intensity', () {
        const overlay = EffectOverlay.crt(intensity: 0.5);

        expect(overlay.intensity, 0.5);
      });
    });

    group('widget rendering', () {
      testWidgets('scanlines renders CustomPaint', (tester) async {
        await tester.pumpWidget(wrapWithApp(
          const EffectOverlay.scanlines(),
        ));

        expect(find.byType(CustomPaint), findsWidgets);
      });

      testWidgets('grain renders with TimeConsumer', (tester) async {
        await tester.pumpWidget(wrapWithApp(
          const EffectOverlay.grain(),
        ));

        expect(find.byType(CustomPaint), findsWidgets);
      });

      testWidgets('vignette renders CustomPaint', (tester) async {
        await tester.pumpWidget(wrapWithApp(
          const EffectOverlay.vignette(),
        ));

        expect(find.byType(CustomPaint), findsWidgets);
      });

      testWidgets('grid renders CustomPaint', (tester) async {
        await tester.pumpWidget(wrapWithApp(
          const EffectOverlay.grid(),
        ));

        expect(find.byType(CustomPaint), findsWidgets);
      });

      testWidgets('crt renders CustomPaint', (tester) async {
        await tester.pumpWidget(wrapWithApp(
          const EffectOverlay.crt(),
        ));

        expect(find.byType(CustomPaint), findsWidgets);
      });

      testWidgets('chromatic aberration renders CustomPaint', (tester) async {
        await tester.pumpWidget(wrapWithApp(
          const EffectOverlay(type: EffectType.chromaticAberration),
        ));

        expect(find.byType(CustomPaint), findsWidgets);
      });

      testWidgets('renders with different intensities', (tester) async {
        for (final intensity in [0.0, 0.25, 0.5, 0.75, 1.0]) {
          await tester.pumpWidget(wrapWithApp(
            EffectOverlay.scanlines(intensity: intensity),
          ));

          expect(find.byType(CustomPaint), findsWidgets);
        }
      });

      testWidgets('grain animates based on frame', (tester) async {
        await tester.pumpWidget(wrapWithApp(
          const EffectOverlay.grain(randomSeed: 42),
          frame: 0,
        ));

        expect(find.byType(CustomPaint), findsWidgets);

        await tester.pumpWidget(wrapWithApp(
          const EffectOverlay.grain(randomSeed: 42),
          frame: 10,
        ));

        expect(find.byType(CustomPaint), findsWidgets);
      });
    });

    group('edge cases', () {
      testWidgets('handles zero intensity', (tester) async {
        await tester.pumpWidget(wrapWithApp(
          const EffectOverlay.vignette(intensity: 0.0),
        ));

        expect(find.byType(CustomPaint), findsWidgets);
      });

      testWidgets('handles full intensity', (tester) async {
        await tester.pumpWidget(wrapWithApp(
          const EffectOverlay.vignette(intensity: 1.0),
        ));

        expect(find.byType(CustomPaint), findsWidgets);
      });

      testWidgets('handles negative seed', (tester) async {
        await tester.pumpWidget(wrapWithApp(
          const EffectOverlay.grain(randomSeed: -100),
        ));

        expect(find.byType(CustomPaint), findsWidgets);
      });
    });

    group('all effect types render', () {
      for (final type in EffectType.values) {
        testWidgets('$type renders without error', (tester) async {
          await tester.pumpWidget(wrapWithApp(
            EffectOverlay(type: type, intensity: 0.5),
          ));

          expect(find.byType(CustomPaint), findsWidgets);
        });
      }
    });
  });
}
