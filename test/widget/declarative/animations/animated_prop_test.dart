import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/declarative/animations/core/animated_prop.dart';
import 'package:fluvie/src/declarative/animations/core/prop_animation.dart';
import '../../../helpers/test_helpers.dart';

void main() {
  group('AnimatedProp', () {
    group('construction', () {
      test('creates with required parameters', () {
        const widget = AnimatedProp(
          animation: PropAnimation.fade(start: 0.0, end: 1.0),
          child: SizedBox(),
        );

        expect(widget.animation, isA<PropAnimation>());
        expect(widget.child, isA<SizedBox>());
      });

      test('has default values', () {
        const widget = AnimatedProp(
          animation: PropAnimation.fade(start: 0.0, end: 1.0),
          child: SizedBox(),
        );

        expect(widget.startFrame, isNull);
        expect(widget.offsetTime, 0);
        expect(widget.duration, 30);
        expect(widget.curve, Curves.easeOut);
        expect(widget.autoReverse, isFalse);
        expect(widget.loop, isFalse);
        expect(widget.heroKey, isNull);
      });

      test('accepts custom values', () {
        final heroKey = GlobalKey();
        final widget = AnimatedProp(
          animation: PropAnimation.fadeIn(),
          startFrame: 10,
          offsetTime: 5,
          duration: 60,
          curve: Curves.bounceOut,
          autoReverse: true,
          loop: true,
          heroKey: heroKey,
          child: const SizedBox(),
        );

        expect(widget.startFrame, 10);
        expect(widget.offsetTime, 5);
        expect(widget.duration, 60);
        expect(widget.curve, Curves.bounceOut);
        expect(widget.autoReverse, isTrue);
        expect(widget.loop, isTrue);
        expect(widget.heroKey, heroKey);
      });
    });

    group('factory constructors', () {
      test('fadeIn creates correct widget', () {
        final widget = AnimatedProp.fadeIn(
          startFrame: 10,
          duration: 45,
          child: const SizedBox(),
        );

        expect(widget.animation, isA<FadeAnimation>());
        expect(widget.startFrame, 10);
        expect(widget.duration, 45);
      });

      test('slideUp creates correct widget', () {
        final widget = AnimatedProp.slideUp(
          distance: 50,
          startFrame: 20,
          duration: 30,
          child: const SizedBox(),
        );

        expect(widget.animation, isA<TranslateAnimation>());
        expect(widget.startFrame, 20);
        expect(widget.duration, 30);
      });

      test('zoomIn creates correct widget', () {
        final widget = AnimatedProp.zoomIn(
          startScale: 0.3,
          startFrame: 5,
          duration: 25,
          child: const SizedBox(),
        );

        expect(widget.animation, isA<ScaleAnimation>());
        expect(widget.startFrame, 5);
        expect(widget.duration, 25);
      });

      test('slideUpFade creates correct widget', () {
        final widget = AnimatedProp.slideUpFade(
          distance: 40,
          startFrame: 15,
          duration: 35,
          child: const SizedBox(),
        );

        expect(widget.animation, isA<CombinedAnimation>());
        expect(widget.startFrame, 15);
        expect(widget.duration, 35);
      });

      test('fadeIn supports offsetTime', () {
        final widget = AnimatedProp.fadeIn(
          offsetTime: 10,
          child: const SizedBox(),
        );

        expect(widget.offsetTime, 10);
        expect(widget.startFrame, isNull);
      });
    });

    group('widget rendering', () {
      testWidgets('renders child widget', (tester) async {
        await tester.pumpWidget(wrapWithApp(
          AnimatedProp(
            animation: PropAnimation.slideUp(),
            duration: 30,
            child: const Text('TestChild'),
          ),
        ));

        expect(find.text('TestChild'), findsOneWidget);
      });

      testWidgets('renders at frame 0', (tester) async {
        await tester.pumpWidget(wrapWithApp(
          AnimatedProp(
            animation: PropAnimation.slideUp(),
            startFrame: 0,
            duration: 30,
            child: const Text('Frame0Test'),
          ),
          frame: 0,
        ));

        expect(find.text('Frame0Test'), findsOneWidget);
      });

      testWidgets('renders at mid animation', (tester) async {
        await tester.pumpWidget(wrapWithApp(
          AnimatedProp(
            animation: PropAnimation.slideUp(distance: 30),
            startFrame: 0,
            duration: 30,
            child: const Text('MidAnimTest'),
          ),
          frame: 15,
        ));

        expect(find.text('MidAnimTest'), findsOneWidget);
      });

      testWidgets('renders at end of animation', (tester) async {
        await tester.pumpWidget(wrapWithApp(
          AnimatedProp(
            animation: PropAnimation.zoomIn(),
            startFrame: 0,
            duration: 30,
            child: const Text('EndAnimTest'),
          ),
          frame: 30,
        ));

        expect(find.text('EndAnimTest'), findsOneWidget);
      });

      testWidgets('renders before animation starts', (tester) async {
        await tester.pumpWidget(wrapWithApp(
          AnimatedProp(
            animation: PropAnimation.slideUp(),
            startFrame: 30,
            duration: 30,
            child: const Text('BeforeAnimTest'),
          ),
          frame: 0,
        ));

        expect(find.text('BeforeAnimTest'), findsOneWidget);
      });

      testWidgets('renders after animation ends', (tester) async {
        await tester.pumpWidget(wrapWithApp(
          AnimatedProp(
            animation: PropAnimation.slideUp(),
            startFrame: 0,
            duration: 30,
            child: const Text('AfterAnimTest'),
          ),
          frame: 60,
        ));

        expect(find.text('AfterAnimTest'), findsOneWidget);
      });
    });

    group('heroKey', () {
      testWidgets('wraps with KeyedSubtree when heroKey provided',
          (tester) async {
        final heroKey = GlobalKey();
        await tester.pumpWidget(wrapWithApp(
          AnimatedProp(
            animation: PropAnimation.slideUp(),
            heroKey: heroKey,
            child: const Text('HeroTest'),
          ),
        ));

        expect(find.byKey(heroKey), findsOneWidget);
      });

      testWidgets('does not wrap when heroKey is null', (tester) async {
        await tester.pumpWidget(wrapWithApp(
          AnimatedProp(
            animation: PropAnimation.slideUp(),
            child: const Text('NoHeroTest'),
          ),
        ));

        expect(find.text('NoHeroTest'), findsOneWidget);
        // Should not find KeyedSubtree wrapping the content
        expect(find.byType(KeyedSubtree), findsNothing);
      });
    });

    group('combined animations', () {
      testWidgets('renders slideUpFade correctly', (tester) async {
        await tester.pumpWidget(wrapWithApp(
          AnimatedProp(
            animation: PropAnimation.slideUpFade(),
            startFrame: 0,
            duration: 30,
            child: const Text('SlideUpFade'),
          ),
          frame: 15,
        ));

        expect(find.text('SlideUpFade'), findsOneWidget);
      });

      testWidgets('renders custom combined animation', (tester) async {
        await tester.pumpWidget(wrapWithApp(
          AnimatedProp(
            animation: PropAnimation.combine([
              PropAnimation.slideUp(),
              PropAnimation.fadeIn(),
              PropAnimation.zoomIn(),
            ]),
            startFrame: 0,
            duration: 30,
            child: const Text('Combined'),
          ),
          frame: 15,
        ));

        expect(find.text('Combined'), findsOneWidget);
      });
    });

    group('edge cases', () {
      testWidgets('handles zero duration', (tester) async {
        // With zero duration, animation stays at initial state (progress 0.0)
        // For a fade from 0.0 to 1.0, this means opacity 0.0 (invisible)
        await tester.pumpWidget(wrapWithApp(
          const AnimatedProp(
            animation: PropAnimation.fade(start: 1.0, end: 0.0),
            startFrame: 0,
            duration: 0,
            child: Text('Zero Duration'),
          ),
        ));

        // Widget is visible because fade starts at 1.0 (initial state)
        expect(find.text('Zero Duration'), findsOneWidget);
      });

      testWidgets('handles very long duration', (tester) async {
        await tester.pumpWidget(wrapWithApp(
          const AnimatedProp(
            animation: PropAnimation.fade(start: 0.0, end: 1.0),
            startFrame: 0,
            duration: 10000,
            child: Text('Long Duration'),
          ),
          frame: 5000,
        ));

        expect(find.text('Long Duration'), findsOneWidget);
      });

      testWidgets('handles negative offsetTime', (tester) async {
        await tester.pumpWidget(wrapWithApp(
          const AnimatedProp(
            animation: PropAnimation.fade(start: 0.0, end: 1.0),
            offsetTime: -10,
            duration: 30,
            child: Text('Negative Offset'),
          ),
        ));

        expect(find.text('Negative Offset'), findsOneWidget);
      });
    });

    group('curves', () {
      testWidgets('applies easeIn curve', (tester) async {
        await tester.pumpWidget(wrapWithApp(
          AnimatedProp(
            animation: PropAnimation.slideUp(),
            curve: Curves.easeIn,
            duration: 30,
            child: const Text('EaseIn'),
          ),
        ));

        expect(find.byType(AnimatedProp), findsOneWidget);
        expect(find.text('EaseIn'), findsOneWidget);
      });

      testWidgets('applies bounceOut curve', (tester) async {
        await tester.pumpWidget(wrapWithApp(
          AnimatedProp(
            animation: PropAnimation.slideUp(),
            curve: Curves.bounceOut,
            duration: 30,
            child: const Text('Bounce'),
          ),
        ));

        expect(find.byType(AnimatedProp), findsOneWidget);
        expect(find.text('Bounce'), findsOneWidget);
      });

      testWidgets('applies elasticOut curve', (tester) async {
        await tester.pumpWidget(wrapWithApp(
          AnimatedProp(
            animation: PropAnimation.slideUp(),
            curve: Curves.elasticOut,
            duration: 30,
            child: const Text('Elastic'),
          ),
        ));

        expect(find.byType(AnimatedProp), findsOneWidget);
        expect(find.text('Elastic'), findsOneWidget);
      });

      testWidgets('applies linear curve', (tester) async {
        await tester.pumpWidget(wrapWithApp(
          AnimatedProp(
            animation: PropAnimation.slideUp(),
            curve: Curves.linear,
            duration: 30,
            child: const Text('Linear'),
          ),
        ));

        expect(find.byType(AnimatedProp), findsOneWidget);
        expect(find.text('Linear'), findsOneWidget);
      });
    });
  });
}
