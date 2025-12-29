import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/declarative/effects/effects.dart';
import 'package:fluvie/src/presentation/video_composition.dart';
import 'package:fluvie/src/presentation/time_consumer.dart';

/// Helper function to wrap test widgets with necessary ancestors
Widget wrapWithApp(Widget child, {int frame = 0}) {
  return Directionality(
    textDirection: TextDirection.ltr,
    child: MediaQuery(
      data: const MediaQueryData(size: Size(1080, 1920)),
      child: VideoComposition(
        fps: 30,
        durationInFrames: 300,
        width: 1080,
        height: 1920,
        child: FrameProvider(frame: frame, child: child),
      ),
    ),
  );
}

void main() {
  group('ParticleEffect', () {
    testWidgets('renders CustomPaint', (tester) async {
      await tester.pumpWidget(
        wrapWithApp(const ParticleEffect(count: 10, color: Color(0xFFFFFFFF))),
      );

      expect(find.byType(CustomPaint), findsOneWidget);
    });

    testWidgets('sparkles constructor creates particle effect', (tester) async {
      await tester.pumpWidget(
        wrapWithApp(
          const ParticleEffect.sparkles(count: 15, color: Color(0xFFFFD700)),
        ),
      );

      expect(find.byType(CustomPaint), findsOneWidget);
    });

    testWidgets('confetti constructor creates particle effect', (tester) async {
      await tester.pumpWidget(wrapWithApp(ParticleEffect.confetti(count: 20)));

      expect(find.byType(CustomPaint), findsOneWidget);
    });

    testWidgets('snow constructor creates particle effect', (tester) async {
      await tester.pumpWidget(
        wrapWithApp(const ParticleEffect.snow(count: 30)),
      );

      expect(find.byType(CustomPaint), findsOneWidget);
    });

    testWidgets('bubbles constructor creates particle effect', (tester) async {
      await tester.pumpWidget(
        wrapWithApp(const ParticleEffect.bubbles(count: 25)),
      );

      expect(find.byType(CustomPaint), findsOneWidget);
    });

    testWidgets('renders differently at different frames', (tester) async {
      // Frame 0
      await tester.pumpWidget(
        wrapWithApp(const ParticleEffect(count: 5, randomSeed: 42), frame: 0),
      );

      final paint1 = tester.widget<CustomPaint>(find.byType(CustomPaint));

      // Frame 30
      await tester.pumpWidget(
        wrapWithApp(const ParticleEffect(count: 5, randomSeed: 42), frame: 30),
      );

      final paint2 = tester.widget<CustomPaint>(find.byType(CustomPaint));

      // Painters should be different due to frame change
      expect(paint1.painter, isNot(same(paint2.painter)));
    });
  });

  group('EffectOverlay', () {
    testWidgets('scanlines renders CustomPaint', (tester) async {
      await tester.pumpWidget(
        wrapWithApp(const EffectOverlay.scanlines(intensity: 0.02)),
      );

      expect(find.byType(CustomPaint), findsOneWidget);
    });

    testWidgets('grain renders CustomPaint', (tester) async {
      await tester.pumpWidget(
        wrapWithApp(const EffectOverlay.grain(intensity: 0.06)),
      );

      expect(find.byType(CustomPaint), findsOneWidget);
    });

    testWidgets('vignette renders CustomPaint', (tester) async {
      await tester.pumpWidget(
        wrapWithApp(const EffectOverlay.vignette(intensity: 0.4)),
      );

      expect(find.byType(CustomPaint), findsOneWidget);
    });

    testWidgets('grid renders CustomPaint', (tester) async {
      await tester.pumpWidget(
        wrapWithApp(
          const EffectOverlay.grid(intensity: 0.05, color: Color(0xFFFFFFFF)),
        ),
      );

      expect(find.byType(CustomPaint), findsOneWidget);
    });

    testWidgets('crt renders CustomPaint', (tester) async {
      await tester.pumpWidget(
        wrapWithApp(const EffectOverlay.crt(intensity: 0.3)),
      );

      expect(find.byType(CustomPaint), findsOneWidget);
    });

    testWidgets('grain changes with frame', (tester) async {
      await tester.pumpWidget(
        wrapWithApp(const EffectOverlay.grain(randomSeed: 42), frame: 0),
      );

      final paint1 = tester.widget<CustomPaint>(find.byType(CustomPaint));

      await tester.pumpWidget(
        wrapWithApp(const EffectOverlay.grain(randomSeed: 42), frame: 1),
      );

      final paint2 = tester.widget<CustomPaint>(find.byType(CustomPaint));

      // Grain should change each frame
      expect(paint1.painter, isNot(same(paint2.painter)));
    });
  });

  group('MaskedClip', () {
    testWidgets('circle mask clips child', (tester) async {
      await tester.pumpWidget(
        wrapWithApp(
          MaskedClip.circle(
            radius: 100,
            child: Container(
              key: const Key('child'),
              color: const Color(0xFFFF0000),
            ),
          ),
        ),
      );

      expect(find.byKey(const Key('child')), findsOneWidget);
      expect(find.byType(ClipPath), findsOneWidget);
    });

    testWidgets('rectangle mask clips child', (tester) async {
      await tester.pumpWidget(
        wrapWithApp(
          MaskedClip.rectangle(
            borderRadius: BorderRadius.circular(20),
            child: Container(
              key: const Key('child'),
              color: const Color(0xFF00FF00),
            ),
          ),
        ),
      );

      expect(find.byKey(const Key('child')), findsOneWidget);
      expect(find.byType(ClipPath), findsOneWidget);
    });

    testWidgets('star mask clips child', (tester) async {
      await tester.pumpWidget(
        wrapWithApp(
          MaskedClip.star(
            starPoints: 5,
            radius: 100,
            child: Container(
              key: const Key('child'),
              color: const Color(0xFF0000FF),
            ),
          ),
        ),
      );

      expect(find.byKey(const Key('child')), findsOneWidget);
      expect(find.byType(ClipPath), findsOneWidget);
    });

    testWidgets('heart mask clips child', (tester) async {
      await tester.pumpWidget(
        wrapWithApp(
          MaskedClip.heart(
            radius: 100,
            child: Container(
              key: const Key('child'),
              color: const Color(0xFFFFFF00),
            ),
          ),
        ),
      );

      expect(find.byKey(const Key('child')), findsOneWidget);
      expect(find.byType(ClipPath), findsOneWidget);
    });

    testWidgets('reveal animation works', (tester) async {
      await tester.pumpWidget(
        wrapWithApp(
          MaskedClip.circle(
            radius: 100,
            animation: const MaskAnimation.reveal(duration: 30),
            startFrame: 0,
            child: Container(key: const Key('child')),
          ),
          frame: 0,
        ),
      );

      expect(find.byKey(const Key('child')), findsOneWidget);
    });

    testWidgets('hide animation works', (tester) async {
      await tester.pumpWidget(
        wrapWithApp(
          MaskedClip.circle(
            radius: 100,
            animation: const MaskAnimation.hide(duration: 30),
            startFrame: 0,
            child: Container(key: const Key('child')),
          ),
          frame: 30,
        ),
      );

      expect(find.byKey(const Key('child')), findsOneWidget);
    });
  });

  group('MaskAnimation', () {
    test('reveal progressAt returns correct values', () {
      const animation = MaskAnimation.reveal(duration: 30);

      expect(animation.progressAt(-1), 0.0);
      expect(animation.progressAt(0), 0.0);
      expect(animation.progressAt(30), 1.0);
      expect(animation.progressAt(60), 1.0);
    });

    test('hide progressAt returns correct values', () {
      const animation = MaskAnimation.hide(duration: 30);

      expect(animation.progressAt(-1), 1.0);
      expect(animation.progressAt(0), 1.0);
      expect(animation.progressAt(30), 0.0);
      expect(animation.progressAt(60), 0.0);
    });

    test('reveal with curve applies transformation', () {
      const animation = MaskAnimation.reveal(
        duration: 100,
        curve: Curves.linear,
      );

      // At frame 50, linear progress should be 0.5
      final progress = animation.progressAt(50);
      expect(progress, closeTo(0.5, 0.01));
    });
  });
}
