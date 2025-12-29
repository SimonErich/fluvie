import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/declarative/text/text.dart';
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
  group('AnimatedText', () {
    testWidgets('renders text', (tester) async {
      await tester.pumpWidget(
        wrapWithApp(
          const AnimatedText('Hello World', style: TextStyle(fontSize: 24)),
        ),
      );

      expect(find.text('Hello World'), findsOneWidget);
    });

    testWidgets('renders with animation at frame 0', (tester) async {
      await tester.pumpWidget(
        wrapWithApp(
          AnimatedText.slideUp('Animated', distance: 50, duration: 30),
          frame: 0,
        ),
      );

      expect(find.text('Animated'), findsOneWidget);
      expect(find.byType(Transform), findsOneWidget);
    });

    testWidgets('renders with animation completed', (tester) async {
      await tester.pumpWidget(
        wrapWithApp(
          AnimatedText.slideUp('Animated', distance: 50, duration: 30),
          frame: 30, // Animation complete
        ),
      );

      expect(find.text('Animated'), findsOneWidget);
    });

    testWidgets('fadeIn constructor creates fade animation', (tester) async {
      await tester.pumpWidget(
        wrapWithApp(
          const AnimatedText.fadeIn('Fade In', duration: 30),
          frame: 30, // Animation complete
        ),
      );

      expect(find.text('Fade In'), findsOneWidget);
    });

    testWidgets('slideUpFade constructor creates combined animation', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrapWithApp(
          AnimatedText.slideUpFade('Slide Fade', distance: 30, duration: 30),
          frame: 30, // Animation complete
        ),
      );

      expect(find.text('Slide Fade'), findsOneWidget);
    });

    testWidgets('scale constructor creates scale animation', (tester) async {
      await tester.pumpWidget(
        wrapWithApp(
          AnimatedText.scale('Scale', start: 0.5, duration: 30),
          frame: 15, // Mid-animation
        ),
      );

      expect(find.text('Scale'), findsOneWidget);
      expect(find.byType(Transform), findsOneWidget);
    });

    testWidgets('scaleFade constructor creates combined animation', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrapWithApp(
          AnimatedText.scaleFade('Scale Fade', startScale: 0.8, duration: 30),
          frame: 30, // Animation complete
        ),
      );

      expect(find.text('Scale Fade'), findsOneWidget);
    });
  });

  group('TypewriterText', () {
    testWidgets('shows cursor before start', (tester) async {
      await tester.pumpWidget(
        wrapWithApp(
          const TypewriterText('Hello', startFrame: 30, charsPerSecond: 15),
          frame: 0, // Before start
        ),
      );

      expect(find.text('|'), findsOneWidget);
    });

    testWidgets('shows partial text during typing', (tester) async {
      await tester.pumpWidget(
        wrapWithApp(
          const TypewriterText(
            'Hello World',
            startFrame: 0,
            charsPerSecond: 30, // 1 char per frame at 30 fps
          ),
          frame: 5, // Should show ~5 characters
        ),
      );

      // Should show partial text plus cursor
      final textFinder = find.byType(Text);
      expect(textFinder, findsOneWidget);
      final Text textWidget = tester.widget(textFinder);
      expect(textWidget.data?.length, lessThan('Hello World|'.length));
    });

    testWidgets('shows full text after completion', (tester) async {
      await tester.pumpWidget(
        wrapWithApp(
          const TypewriterText(
            'Hi',
            startFrame: 0,
            charsPerSecond: 30, // 1 char per frame
            showCursor: false,
          ),
          frame: 60, // Way past completion
        ),
      );

      expect(find.text('Hi'), findsOneWidget);
    });

    testWidgets('cursor can be disabled', (tester) async {
      await tester.pumpWidget(
        wrapWithApp(
          const TypewriterText('Test', startFrame: 30, showCursor: false),
          frame: 0,
        ),
      );

      expect(find.text(''), findsOneWidget);
    });

    testWidgets('custom cursor character', (tester) async {
      await tester.pumpWidget(
        wrapWithApp(
          const TypewriterText('Test', startFrame: 30, cursorChar: '_'),
          frame: 0,
        ),
      );

      expect(find.text('_'), findsOneWidget);
    });

    test('totalDuration calculates correctly', () {
      const typewriter = TypewriterText(
        'Hello', // 5 chars
        charsPerSecond: 30, // 1 char per frame at 30fps
      );

      final duration = typewriter.totalDuration(30);
      expect(duration, 5); // 5 chars at 1 char/frame = 5 frames
    });
  });

  group('CounterText', () {
    testWidgets('shows start value at frame 0', (tester) async {
      await tester.pumpWidget(
        wrapWithApp(
          const CounterText(
            value: 100,
            startValue: 0,
            startFrame: 0,
            duration: 60,
          ),
          frame: 0,
        ),
      );

      expect(find.text('0'), findsOneWidget);
    });

    testWidgets('shows end value after animation', (tester) async {
      await tester.pumpWidget(
        wrapWithApp(
          const CounterText(value: 100, startFrame: 0, duration: 60),
          frame: 60,
        ),
      );

      expect(find.text('100'), findsOneWidget);
    });

    testWidgets('shows intermediate value during animation', (tester) async {
      await tester.pumpWidget(
        wrapWithApp(
          const CounterText(
            value: 100,
            startFrame: 0,
            duration: 100,
            curve: Curves.linear,
          ),
          frame: 50, // Halfway
        ),
      );

      // With linear curve, should be around 50
      final textFinder = find.byType(Text);
      final Text textWidget = tester.widget(textFinder);
      final value = int.parse(textWidget.data!);
      expect(value, greaterThanOrEqualTo(40));
      expect(value, lessThanOrEqualTo(60));
    });

    testWidgets('countUp constructor works', (tester) async {
      await tester.pumpWidget(
        wrapWithApp(
          const CounterText.countUp(value: 50, duration: 30),
          frame: 30,
        ),
      );

      expect(find.text('50'), findsOneWidget);
    });

    testWidgets('countDown constructor works', (tester) async {
      await tester.pumpWidget(
        wrapWithApp(
          const CounterText.countDown(from: 10, duration: 30),
          frame: 30,
        ),
      );

      expect(find.text('0'), findsOneWidget);
    });

    testWidgets('percentage constructor formats correctly', (tester) async {
      await tester.pumpWidget(
        wrapWithApp(
          const CounterText.percentage(value: 75, duration: 30),
          frame: 30,
        ),
      );

      expect(find.text('75%'), findsOneWidget);
    });

    testWidgets('custom formatter works', (tester) async {
      await tester.pumpWidget(
        wrapWithApp(
          CounterText(value: 1000, duration: 30, formatter: (n) => '\$$n'),
          frame: 30,
        ),
      );

      expect(find.text('\$1000'), findsOneWidget);
    });
  });

  group('DataDrivenText', () {
    testWidgets('substitutes single variable', (tester) async {
      await tester.pumpWidget(
        wrapWithApp(
          const DataDrivenText(
            template: 'Hello {name}!',
            data: {'name': 'World'},
          ),
        ),
      );

      expect(find.text('Hello World!'), findsOneWidget);
    });

    testWidgets('substitutes multiple variables', (tester) async {
      await tester.pumpWidget(
        wrapWithApp(
          const DataDrivenText(
            template: '{greeting} {name}!',
            data: {'greeting': 'Hi', 'name': 'User'},
          ),
        ),
      );

      expect(find.text('Hi User!'), findsOneWidget);
    });

    testWidgets('handles numeric values', (tester) async {
      await tester.pumpWidget(
        wrapWithApp(
          const DataDrivenText(template: 'Score: {score}', data: {'score': 42}),
        ),
      );

      expect(find.text('Score: 42'), findsOneWidget);
    });

    testWidgets('with countUp animation shows animated value', (tester) async {
      await tester.pumpWidget(
        wrapWithApp(
          const DataDrivenText(
            template: 'Count: {count}',
            data: {'count': 100},
            animations: {'count': DataAnimation.countUp(duration: 60)},
            startFrame: 0,
          ),
          frame: 60, // Animation complete
        ),
      );

      expect(find.text('Count: 100'), findsOneWidget);
    });

    testWidgets('with countUp animation shows start value at frame 0', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrapWithApp(
          const DataDrivenText(
            template: 'Count: {count}',
            data: {'count': 100},
            animations: {
              'count': DataAnimation.countUp(duration: 60, startValue: 0),
            },
            startFrame: 0,
          ),
          frame: 0,
        ),
      );

      expect(find.text('Count: 0'), findsOneWidget);
    });

    testWidgets('with reveal animation shows nothing at frame 0', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrapWithApp(
          const DataDrivenText(
            template: 'Secret: {secret}',
            data: {'secret': 'hidden'},
            animations: {'secret': DataAnimation.reveal(duration: 30)},
            startFrame: 0,
          ),
          frame: 0,
        ),
      );

      expect(find.text('Secret: '), findsOneWidget);
    });

    testWidgets('with reveal animation shows full value at end', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrapWithApp(
          const DataDrivenText(
            template: 'Secret: {secret}',
            data: {'secret': 'revealed'},
            animations: {'secret': DataAnimation.reveal(duration: 30)},
            startFrame: 0,
          ),
          frame: 30,
        ),
      );

      expect(find.text('Secret: revealed'), findsOneWidget);
    });

    testWidgets('with typewriter animation shows partial text', (tester) async {
      await tester.pumpWidget(
        wrapWithApp(
          const DataDrivenText(
            template: 'Msg: {message}',
            data: {'message': 'Hello'},
            animations: {'message': DataAnimation.typewriter(duration: 50)},
            startFrame: 0,
          ),
          frame: 0,
        ),
      );

      expect(find.text('Msg: '), findsOneWidget);
    });

    testWidgets('with typewriter animation shows full text at end', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrapWithApp(
          const DataDrivenText(
            template: 'Msg: {message}',
            data: {'message': 'Hello'},
            animations: {'message': DataAnimation.typewriter(duration: 50)},
            startFrame: 0,
          ),
          frame: 50,
        ),
      );

      expect(find.text('Msg: Hello'), findsOneWidget);
    });
  });

  group('DataAnimation', () {
    test('countUp animates numeric values', () {
      const animation = DataAnimation.countUp(duration: 100, startValue: 0);

      expect(animation.animate(100, -1), 0); // Before start
      expect(animation.animate(100, 0), 0); // At start
      expect(animation.animate(100, 100), 100); // At end
    });

    test('countUp with formatter', () {
      const animation = DataAnimation.countUp(
        duration: 100,
        formatter: _dollarFormatter,
      );

      expect(animation.animate(100, 100), '\$100');
    });

    test('reveal shows nothing until complete', () {
      const animation = DataAnimation.reveal(duration: 30);

      expect(animation.animate('secret', 0), '');
      expect(animation.animate('secret', 15), '');
      expect(animation.animate('secret', 30), 'secret');
    });

    test('typewriter reveals characters progressively', () {
      const animation = DataAnimation.typewriter(duration: 50);

      expect(animation.animate('Hello', 0), '');
      expect(animation.animate('Hello', 25), isA<String>());
      expect(animation.animate('Hello', 50), 'Hello');
    });
  });
}

String _dollarFormatter(dynamic n) => '\$$n';
