import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/declarative/text/animated_text.dart';
import 'package:fluvie/src/declarative/animations/core/prop_animation.dart';
import '../../../helpers/test_helpers.dart';

void main() {
  group('AnimatedText', () {
    group('construction', () {
      test('creates with required text', () {
        const widget = AnimatedText('Hello World');

        expect(widget.text, 'Hello World');
      });

      test('has default values', () {
        const widget = AnimatedText('Test');

        expect(widget.style, isNull);
        expect(widget.animation, isNull);
        expect(widget.startFrame, 0);
        expect(widget.duration, 30);
        expect(widget.curve, Curves.easeOut);
        expect(widget.textAlign, isNull);
        expect(widget.maxLines, isNull);
        expect(widget.overflow, isNull);
      });

      test('accepts custom values', () {
        const style = TextStyle(fontSize: 24);
        final animation = PropAnimation.slideUp();
        final widget = AnimatedText(
          'Custom',
          style: style,
          animation: animation,
          startFrame: 10,
          duration: 45,
          curve: Curves.bounceOut,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        );

        expect(widget.text, 'Custom');
        expect(widget.style, style);
        expect(widget.animation, animation);
        expect(widget.startFrame, 10);
        expect(widget.duration, 45);
        expect(widget.curve, Curves.bounceOut);
        expect(widget.textAlign, TextAlign.center);
        expect(widget.maxLines, 2);
        expect(widget.overflow, TextOverflow.ellipsis);
      });
    });

    group('factory constructors', () {
      test('fadeIn creates fade animation', () {
        const widget = AnimatedText.fadeIn('Fade In');

        expect(widget.text, 'Fade In');
        expect(widget.animation, isA<FadeAnimation>());
      });

      test('fadeIn accepts custom parameters', () {
        const widget = AnimatedText.fadeIn(
          'Custom Fade',
          startFrame: 15,
          duration: 45,
          curve: Curves.easeIn,
        );

        expect(widget.startFrame, 15);
        expect(widget.duration, 45);
        expect(widget.curve, Curves.easeIn);
      });

      test('slideUp creates translate animation', () {
        final widget = AnimatedText.slideUp('Slide Up');

        expect(widget.text, 'Slide Up');
        expect(widget.animation, isA<TranslateAnimation>());
      });

      test('slideUp accepts custom distance', () {
        final widget = AnimatedText.slideUp(
          'Custom Slide',
          distance: 50,
          startFrame: 10,
        );

        expect(widget.startFrame, 10);
        expect(widget.animation, isA<TranslateAnimation>());
      });

      test('slideUpFade creates combined animation', () {
        final widget = AnimatedText.slideUpFade('SlideUpFade');

        expect(widget.text, 'SlideUpFade');
        expect(widget.animation, isA<CombinedAnimation>());
      });

      test('slideUpFade accepts custom distance', () {
        final widget = AnimatedText.slideUpFade(
          'Custom',
          distance: 40,
        );

        expect(widget.animation, isA<CombinedAnimation>());
      });

      test('scale creates scale animation', () {
        final widget = AnimatedText.scale('Scale');

        expect(widget.text, 'Scale');
        expect(widget.animation, isA<ScaleAnimation>());
      });

      test('scale accepts custom start scale', () {
        final widget = AnimatedText.scale('Custom Scale', start: 0.3);

        expect(widget.animation, isA<ScaleAnimation>());
      });

      test('scaleFade creates combined animation', () {
        final widget = AnimatedText.scaleFade('ScaleFade');

        expect(widget.text, 'ScaleFade');
        expect(widget.animation, isA<CombinedAnimation>());
      });

      test('scaleFade accepts custom start scale', () {
        final widget = AnimatedText.scaleFade('Custom', startScale: 0.5);

        expect(widget.animation, isA<CombinedAnimation>());
      });
    });

    group('widget rendering', () {
      testWidgets('renders text without animation', (tester) async {
        await tester.pumpWidget(wrapWithApp(
          const AnimatedText('Plain Text'),
        ));

        expect(find.text('Plain Text'), findsOneWidget);
      });

      testWidgets('renders with slide animation at end', (tester) async {
        await tester.pumpWidget(wrapWithApp(
          AnimatedText.slideUp(
            'Slide Text',
            startFrame: 0,
            duration: 30,
          ),
          frame: 30,
        ));

        expect(find.text('Slide Text'), findsOneWidget);
      });

      testWidgets('renders with scale animation at end', (tester) async {
        await tester.pumpWidget(wrapWithApp(
          AnimatedText.scale(
            'Scale Text',
            startFrame: 0,
            duration: 30,
          ),
          frame: 30,
        ));

        expect(find.text('Scale Text'), findsOneWidget);
      });

      testWidgets('renders at different frames', (tester) async {
        await tester.pumpWidget(wrapWithApp(
          AnimatedText.slideUp(
            'Animated',
            startFrame: 0,
            duration: 30,
          ),
          frame: 15,
        ));

        expect(find.text('Animated'), findsOneWidget);
      });

      testWidgets('renders before animation starts', (tester) async {
        await tester.pumpWidget(wrapWithApp(
          AnimatedText.slideUp(
            'Before Start',
            startFrame: 30,
            duration: 30,
          ),
          frame: 0,
        ));

        expect(find.text('Before Start'), findsOneWidget);
      });

      testWidgets('renders after animation ends', (tester) async {
        await tester.pumpWidget(wrapWithApp(
          AnimatedText.slideUp(
            'After End',
            startFrame: 0,
            duration: 30,
          ),
          frame: 100,
        ));

        expect(find.text('After End'), findsOneWidget);
      });
    });

    group('text styling', () {
      testWidgets('applies text style', (tester) async {
        await tester.pumpWidget(wrapWithApp(
          const AnimatedText(
            'Styled',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
        ));

        expect(find.text('Styled'), findsOneWidget);
      });

      testWidgets('applies text alignment', (tester) async {
        await tester.pumpWidget(wrapWithApp(
          const AnimatedText(
            'Centered',
            textAlign: TextAlign.center,
          ),
        ));

        expect(find.text('Centered'), findsOneWidget);
      });

      testWidgets('applies max lines', (tester) async {
        await tester.pumpWidget(wrapWithApp(
          const AnimatedText(
            'Line 1\nLine 2\nLine 3',
            maxLines: 2,
          ),
        ));

        expect(find.text('Line 1\nLine 2\nLine 3'), findsOneWidget);
      });

      testWidgets('applies overflow', (tester) async {
        await tester.pumpWidget(wrapWithApp(
          const AnimatedText(
            'Very long text that might overflow',
            overflow: TextOverflow.ellipsis,
          ),
        ));

        expect(find.text('Very long text that might overflow'), findsOneWidget);
      });
    });

    group('edge cases', () {
      testWidgets('handles empty text', (tester) async {
        await tester.pumpWidget(wrapWithApp(
          const AnimatedText(''),
        ));

        expect(find.text(''), findsOneWidget);
      });

      testWidgets('handles long text', (tester) async {
        final longText = 'A' * 1000;
        await tester.pumpWidget(wrapWithApp(
          AnimatedText(longText),
        ));

        expect(find.text(longText), findsOneWidget);
      });

      testWidgets('handles special characters', (tester) async {
        await tester.pumpWidget(wrapWithApp(
          const AnimatedText('Hello! @#\$%^&*() 你好 🎉'),
        ));

        expect(find.text('Hello! @#\$%^&*() 你好 🎉'), findsOneWidget);
      });

      testWidgets('handles zero duration', (tester) async {
        await tester.pumpWidget(wrapWithApp(
          AnimatedText.slideUp(
            'Zero Duration',
            duration: 0,
          ),
        ));

        expect(find.text('Zero Duration'), findsOneWidget);
      });
    });

    group('curves', () {
      testWidgets('applies easeIn curve', (tester) async {
        await tester.pumpWidget(wrapWithApp(
          AnimatedText.slideUp(
            'EaseIn',
            curve: Curves.easeIn,
          ),
        ));

        expect(find.text('EaseIn'), findsOneWidget);
      });

      testWidgets('applies bounceOut curve', (tester) async {
        await tester.pumpWidget(wrapWithApp(
          AnimatedText.slideUp(
            'Bounce',
            curve: Curves.bounceOut,
          ),
        ));

        expect(find.text('Bounce'), findsOneWidget);
      });

      testWidgets('applies linear curve', (tester) async {
        await tester.pumpWidget(wrapWithApp(
          AnimatedText.slideUp(
            'Linear',
            curve: Curves.linear,
          ),
        ));

        expect(find.text('Linear'), findsOneWidget);
      });
    });
  });
}
