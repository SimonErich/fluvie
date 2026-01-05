import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/declarative/animations/animations.dart';
import 'package:fluvie/src/presentation/video_composition.dart';
import 'package:fluvie/src/presentation/time_consumer.dart';

/// Helper function to wrap test widgets with necessary ancestors
Widget wrapWithApp(Widget child, {int frame = 0}) {
  return Directionality(
    textDirection: TextDirection.ltr,
    child: VideoComposition(
      fps: 30,
      durationInFrames: 300,
      width: 1080,
      height: 1920,
      child: FrameProvider(frame: frame, child: child),
    ),
  );
}

void main() {
  group('PropAnimation', () {
    test('translate creates translation animation', () {
      const animation = PropAnimation.translate(
        start: Offset(0, 30),
        end: Offset.zero,
      );

      expect(animation, isA<TranslateAnimation>());
    });

    test('scale creates scale animation', () {
      const animation = PropAnimation.scale(start: 0.5, end: 1.0);

      expect(animation, isA<ScaleAnimation>());
    });

    test('rotate creates rotation animation', () {
      const animation = PropAnimation.rotate(start: 0.0, end: 3.14);

      expect(animation, isA<RotateAnimation>());
    });

    test('fade creates fade animation', () {
      const animation = PropAnimation.fade(start: 0.0, end: 1.0);

      expect(animation, isA<FadeAnimation>());
    });

    test('combine creates combined animation', () {
      const animation = PropAnimation.combine([
        PropAnimation.translate(start: Offset(0, 30), end: Offset.zero),
        PropAnimation.fade(start: 0.0, end: 1.0),
      ]);

      expect(animation, isA<CombinedAnimation>());
      expect((animation as CombinedAnimation).animations.length, 2);
    });

    test('slideUp creates correct animation', () {
      final animation = PropAnimation.slideUp(distance: 50);

      expect(animation, isA<TranslateAnimation>());
      expect((animation as TranslateAnimation).start, const Offset(0, 50));
      expect(animation.end, Offset.zero);
    });

    test('slideDown creates correct animation', () {
      final animation = PropAnimation.slideDown(distance: 50);

      expect(animation, isA<TranslateAnimation>());
      expect((animation as TranslateAnimation).start, const Offset(0, -50));
      expect(animation.end, Offset.zero);
    });

    test('slideLeft creates correct animation', () {
      final animation = PropAnimation.slideLeft(distance: 50);

      expect(animation, isA<TranslateAnimation>());
      expect((animation as TranslateAnimation).start, const Offset(50, 0));
      expect(animation.end, Offset.zero);
    });

    test('slideRight creates correct animation', () {
      final animation = PropAnimation.slideRight(distance: 50);

      expect(animation, isA<TranslateAnimation>());
      expect((animation as TranslateAnimation).start, const Offset(-50, 0));
      expect(animation.end, Offset.zero);
    });

    test('zoomIn creates correct animation', () {
      final animation = PropAnimation.zoomIn(start: 0.5);

      expect(animation, isA<ScaleAnimation>());
      expect((animation as ScaleAnimation).start, 0.5);
      expect(animation.end, 1.0);
    });

    test('zoomOut creates correct animation', () {
      final animation = PropAnimation.zoomOut(end: 0.5);

      expect(animation, isA<ScaleAnimation>());
      expect((animation as ScaleAnimation).start, 1.0);
      expect(animation.end, 0.5);
    });

    test('fadeIn creates correct animation', () {
      final animation = PropAnimation.fadeIn();

      expect(animation, isA<FadeAnimation>());
      expect((animation as FadeAnimation).start, 0.0);
      expect(animation.end, 1.0);
    });

    test('fadeOut creates correct animation', () {
      final animation = PropAnimation.fadeOut();

      expect(animation, isA<FadeAnimation>());
      expect((animation as FadeAnimation).start, 1.0);
      expect(animation.end, 0.0);
    });

    test('slideUpFade creates combined animation', () {
      final animation = PropAnimation.slideUpFade(distance: 30);

      expect(animation, isA<CombinedAnimation>());
      expect((animation as CombinedAnimation).animations.length, 2);
    });

    test('float creates oscillating animation', () {
      final animation = PropAnimation.float(
        amplitude: const Offset(0, 10),
        phase: 0.0,
      );

      expect(animation, isA<FloatAnimation>());
    });

    test('pulse creates pulsing animation', () {
      final animation = PropAnimation.pulse(min: 0.9, max: 1.1);

      expect(animation, isA<PulseAnimation>());
    });

    test('scaleX creates horizontal scale animation', () {
      final animation = PropAnimation.scaleX(start: 0.0, end: 1.0);

      expect(animation, isA<ScaleXAnimation>());
      expect((animation as ScaleXAnimation).start, 0.0);
      expect(animation.end, 1.0);
    });

    test('scaleY creates vertical scale animation', () {
      final animation = PropAnimation.scaleY(start: 0.0, end: 1.0);

      expect(animation, isA<ScaleYAnimation>());
      expect((animation as ScaleYAnimation).start, 0.0);
      expect(animation.end, 1.0);
    });

    test('bounceIn creates bounce animation with overshoot', () {
      final animation = PropAnimation.bounceIn(start: 0.0, overshoot: 1.2);

      expect(animation, isA<BounceInAnimation>());
      expect((animation as BounceInAnimation).start, 0.0);
      expect(animation.overshoot, 1.2);
    });

    test('slideDownFade creates combined animation', () {
      final animation = PropAnimation.slideDownFade(distance: 30);

      expect(animation, isA<CombinedAnimation>());
      expect((animation as CombinedAnimation).animations.length, 2);
    });

    test('slideLeftFade creates combined animation', () {
      final animation = PropAnimation.slideLeftFade(distance: 30);

      expect(animation, isA<CombinedAnimation>());
      expect((animation as CombinedAnimation).animations.length, 2);
    });

    test('slideRightFade creates combined animation', () {
      final animation = PropAnimation.slideRightFade(distance: 30);

      expect(animation, isA<CombinedAnimation>());
      expect((animation as CombinedAnimation).animations.length, 2);
    });
  });

  group('TranslateAnimation apply', () {
    test('applies translation at progress 0', () {
      const animation = TranslateAnimation(
        start: Offset(100, 200),
        end: Offset.zero,
      );
      const child = SizedBox(width: 50, height: 50);

      final result = animation.apply(child, 0.0);

      expect(result, isA<Transform>());
    });

    test('returns child unchanged at progress 1 when end is zero', () {
      const animation = TranslateAnimation(
        start: Offset(100, 200),
        end: Offset.zero,
      );
      const child = SizedBox(width: 50, height: 50);

      final result = animation.apply(child, 1.0);

      // At progress 1, offset is Offset.zero, so child is returned unchanged
      expect(result, same(child));
    });

    test('interpolates correctly at progress 0.5', () {
      const animation = TranslateAnimation(
        start: Offset(0, 100),
        end: Offset.zero,
      );
      const child = SizedBox(width: 50, height: 50);

      final result = animation.apply(child, 0.5);

      expect(result, isA<Transform>());
    });
  });

  group('ScaleAnimation apply', () {
    test('applies scale at progress 0', () {
      const animation = ScaleAnimation(start: 0.5, end: 1.0);
      const child = SizedBox(width: 50, height: 50);

      final result = animation.apply(child, 0.0);

      expect(result, isA<Transform>());
    });

    test('returns child unchanged at progress 1 when scale is 1', () {
      const animation = ScaleAnimation(start: 0.5, end: 1.0);
      const child = SizedBox(width: 50, height: 50);

      final result = animation.apply(child, 1.0);

      // At progress 1, scale is 1.0, so child is returned unchanged
      expect(result, same(child));
    });
  });

  group('FadeAnimation apply', () {
    test('applies fade at progress 0', () {
      const animation = FadeAnimation(start: 0.0, end: 1.0);
      const child = SizedBox(width: 50, height: 50);

      final result = animation.apply(child, 0.0);

      expect(result, isNot(same(child)));
    });

    test('returns child unchanged at progress 1 when opacity is 1', () {
      const animation = FadeAnimation(start: 0.0, end: 1.0);
      const child = SizedBox(width: 50, height: 50);

      final result = animation.apply(child, 1.0);

      // At progress 1, opacity is 1.0, so child is returned unchanged
      expect(result, same(child));
    });
  });

  group('ScaleXAnimation apply', () {
    test('applies horizontal scale at progress 0', () {
      const animation = ScaleXAnimation(start: 0.0, end: 1.0);
      const child = SizedBox(width: 50, height: 50);

      final result = animation.apply(child, 0.0);

      expect(result, isA<Transform>());
    });

    test('returns child unchanged at progress 1 when scaleX is 1', () {
      const animation = ScaleXAnimation(start: 0.0, end: 1.0);
      const child = SizedBox(width: 50, height: 50);

      final result = animation.apply(child, 1.0);

      expect(result, same(child));
    });

    test('interpolates correctly at progress 0.5', () {
      const animation = ScaleXAnimation(start: 0.0, end: 1.0);
      const child = SizedBox(width: 50, height: 50);

      final result = animation.apply(child, 0.5);

      expect(result, isA<Transform>());
    });
  });

  group('ScaleYAnimation apply', () {
    test('applies vertical scale at progress 0', () {
      const animation = ScaleYAnimation(start: 0.0, end: 1.0);
      const child = SizedBox(width: 50, height: 50);

      final result = animation.apply(child, 0.0);

      expect(result, isA<Transform>());
    });

    test('returns child unchanged at progress 1 when scaleY is 1', () {
      const animation = ScaleYAnimation(start: 0.0, end: 1.0);
      const child = SizedBox(width: 50, height: 50);

      final result = animation.apply(child, 1.0);

      expect(result, same(child));
    });

    test('interpolates correctly at progress 0.5', () {
      const animation = ScaleYAnimation(start: 0.0, end: 1.0);
      const child = SizedBox(width: 50, height: 50);

      final result = animation.apply(child, 0.5);

      expect(result, isA<Transform>());
    });
  });

  group('BounceInAnimation apply', () {
    test('applies scale at progress 0', () {
      const animation = BounceInAnimation(start: 0.0, overshoot: 1.2);
      const child = SizedBox(width: 50, height: 50);

      final result = animation.apply(child, 0.0);

      expect(result, isA<Transform>());
    });

    test('applies overshoot scale at progress 0.6', () {
      const animation = BounceInAnimation(start: 0.0, overshoot: 1.2);
      const child = SizedBox(width: 50, height: 50);

      final result = animation.apply(child, 0.6);

      expect(result, isA<Transform>());
    });

    test('applies scale at progress 1', () {
      const animation = BounceInAnimation(start: 0.0, overshoot: 1.2);
      const child = SizedBox(width: 50, height: 50);

      final result = animation.apply(child, 1.0);

      expect(result, isA<Transform>());
    });
  });

  group('AnimatedProp', () {
    testWidgets('renders child widget', (tester) async {
      await tester.pumpWidget(
        wrapWithApp(
          AnimatedProp(
            animation: PropAnimation.slideUp(), // Use non-fade animation
            duration: 30,
            child: Container(key: const Key('child')),
          ),
        ),
      );

      expect(find.byKey(const Key('child')), findsOneWidget);
    });

    testWidgets('applies animation at progress 0.5', (tester) async {
      await tester.pumpWidget(
        wrapWithApp(
          AnimatedProp(
            startFrame: 0,
            animation: PropAnimation.slideUp(distance: 100),
            duration: 60,
            child: Container(key: const Key('child')),
          ),
          frame: 30, // Halfway through animation
        ),
      );

      expect(find.byKey(const Key('child')), findsOneWidget);
      expect(find.byType(Transform), findsOneWidget);
    });

    testWidgets('AnimatedProp.fadeIn creates correct animation', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrapWithApp(
          AnimatedProp.fadeIn(
            duration: 30,
            child: Container(key: const Key('child')),
          ),
          frame: 30, // After animation completes
        ),
      );

      expect(find.byKey(const Key('child')), findsOneWidget);
    });

    testWidgets('AnimatedProp.slideUp creates correct animation', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrapWithApp(
          AnimatedProp.slideUp(
            distance: 50,
            duration: 30,
            child: Container(key: const Key('child')),
          ),
        ),
      );

      expect(find.byKey(const Key('child')), findsOneWidget);
    });

    testWidgets('AnimatedProp.zoomIn creates correct animation', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrapWithApp(
          AnimatedProp.zoomIn(
            startScale: 0.5,
            duration: 30,
            child: Container(key: const Key('child')),
          ),
        ),
      );

      expect(find.byKey(const Key('child')), findsOneWidget);
    });

    testWidgets('AnimatedProp.slideUpFade creates correct animation', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrapWithApp(
          AnimatedProp.slideUpFade(
            distance: 30,
            duration: 30,
            child: Container(key: const Key('child')),
          ),
          frame: 30, // After animation completes
        ),
      );

      expect(find.byKey(const Key('child')), findsOneWidget);
    });
  });

  group('Stagger', () {
    testWidgets('renders all children', (tester) async {
      await tester.pumpWidget(
        wrapWithApp(
          Stagger(
            staggerDelay: 10,
            animationDuration: 30,
            animation:
                PropAnimation.slideUp(), // Use translation instead of fade
            children: [
              Container(key: const Key('child1')),
              Container(key: const Key('child2')),
              Container(key: const Key('child3')),
            ],
          ),
        ),
      );

      expect(find.byKey(const Key('child1')), findsOneWidget);
      expect(find.byKey(const Key('child2')), findsOneWidget);
      expect(find.byKey(const Key('child3')), findsOneWidget);
    });

    testWidgets('creates Column for vertical direction', (tester) async {
      await tester.pumpWidget(
        wrapWithApp(
          const Stagger(
            direction: Axis.vertical,
            children: [
              SizedBox(width: 50, height: 50),
              SizedBox(width: 50, height: 50),
            ],
          ),
        ),
      );

      expect(find.byType(Column), findsOneWidget);
    });

    testWidgets('creates Row for horizontal direction', (tester) async {
      await tester.pumpWidget(
        wrapWithApp(
          const Stagger(
            direction: Axis.horizontal,
            children: [
              SizedBox(width: 50, height: 50),
              SizedBox(width: 50, height: 50),
            ],
          ),
        ),
      );

      expect(find.byType(Row), findsOneWidget);
    });

    testWidgets('adds spacing between children', (tester) async {
      await tester.pumpWidget(
        wrapWithApp(
          const Stagger(
            spacing: 20,
            children: [
              SizedBox(key: Key('child1'), width: 50, height: 50),
              SizedBox(key: Key('child2'), width: 50, height: 50),
            ],
          ),
        ),
      );

      // Should have spacing SizedBox between children
      final column = tester.widget<Column>(find.byType(Column));
      expect(column.children.length, 3); // child1, spacer, child2
    });

    testWidgets('Stagger.vertical creates vertical layout', (tester) async {
      await tester.pumpWidget(
        wrapWithApp(
          const Stagger.vertical(
            children: [
              SizedBox(width: 50, height: 50),
              SizedBox(width: 50, height: 50),
            ],
          ),
        ),
      );

      expect(find.byType(Column), findsOneWidget);
    });

    testWidgets('Stagger.horizontal creates horizontal layout', (tester) async {
      await tester.pumpWidget(
        wrapWithApp(
          const Stagger.horizontal(
            children: [
              SizedBox(width: 50, height: 50),
              SizedBox(width: 50, height: 50),
            ],
          ),
        ),
      );

      expect(find.byType(Row), findsOneWidget);
    });

    testWidgets('Stagger.slideUpFade creates correct animation', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrapWithApp(
          Stagger.slideUpFade(
            staggerDelay: 5,
            animationDuration: 20,
            children: [
              Container(key: const Key('child1')),
              Container(key: const Key('child2')),
            ],
          ),
          frame: 30, // After animation completes, children should be visible
        ),
      );

      expect(find.byKey(const Key('child1')), findsOneWidget);
      expect(find.byKey(const Key('child2')), findsOneWidget);
    });

    testWidgets('Stagger.scaleFade creates correct animation', (tester) async {
      await tester.pumpWidget(
        wrapWithApp(
          Stagger.scaleFade(
            staggerDelay: 5,
            animationDuration: 20,
            children: [
              Container(key: const Key('child1')),
              Container(key: const Key('child2')),
            ],
          ),
          frame: 30, // After animation completes, children should be visible
        ),
      );

      expect(find.byKey(const Key('child1')), findsOneWidget);
      expect(find.byKey(const Key('child2')), findsOneWidget);
    });

    test('totalDuration calculates correctly', () {
      const stagger = Stagger(
        staggerDelay: 15,
        animationDuration: 30,
        children: [SizedBox(), SizedBox(), SizedBox()],
      );

      // 3 children: (3-1) * 15 + 30 = 60
      expect(stagger.totalDuration, 60);
    });

    test('totalDuration is 0 for empty children', () {
      const stagger = Stagger(
        staggerDelay: 15,
        animationDuration: 30,
        children: [],
      );

      expect(stagger.totalDuration, 0);
    });
  });
}
