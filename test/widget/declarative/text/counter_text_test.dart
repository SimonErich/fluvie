import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/declarative/text/counter_text.dart';
import '../../../helpers/test_helpers.dart';

void main() {
  group('CounterText', () {
    group('construction', () {
      test('creates with required value', () {
        const widget = CounterText(value: 100);

        expect(widget.value, 100);
      });

      test('has default values', () {
        const widget = CounterText(value: 100);

        expect(widget.startValue, 0);
        expect(widget.startFrame, 0);
        expect(widget.duration, 60);
        expect(widget.curve, Curves.easeOut);
        expect(widget.style, isNull);
        expect(widget.formatter, isNull);
        expect(widget.textAlign, isNull);
      });

      test('accepts custom values', () {
        String customFormatter(int n) => '\$$n';
        const style = TextStyle(fontSize: 24);

        final widget = CounterText(
          value: 500,
          startValue: 100,
          startFrame: 15,
          duration: 90,
          curve: Curves.bounceOut,
          style: style,
          formatter: customFormatter,
          textAlign: TextAlign.center,
        );

        expect(widget.value, 500);
        expect(widget.startValue, 100);
        expect(widget.startFrame, 15);
        expect(widget.duration, 90);
        expect(widget.curve, Curves.bounceOut);
        expect(widget.style, style);
        expect(widget.formatter, customFormatter);
        expect(widget.textAlign, TextAlign.center);
      });
    });

    group('factory constructors', () {
      test('countUp creates widget starting from zero', () {
        const widget = CounterText.countUp(value: 100);

        expect(widget.value, 100);
        expect(widget.startValue, 0);
      });

      test('countUp accepts custom parameters', () {
        const widget = CounterText.countUp(
          value: 200,
          startFrame: 10,
          duration: 45,
          curve: Curves.easeIn,
        );

        expect(widget.value, 200);
        expect(widget.startFrame, 10);
        expect(widget.duration, 45);
        expect(widget.curve, Curves.easeIn);
      });

      test('countDown creates widget ending at zero', () {
        const widget = CounterText.countDown(from: 100);

        expect(widget.value, 0);
        expect(widget.startValue, 100);
      });

      test('countDown accepts custom parameters', () {
        const widget = CounterText.countDown(
          from: 50,
          startFrame: 20,
          duration: 30,
        );

        expect(widget.startValue, 50);
        expect(widget.value, 0);
        expect(widget.startFrame, 20);
        expect(widget.duration, 30);
      });

      test('percentage creates widget with percentage formatter', () {
        const widget = CounterText.percentage(value: 75);

        expect(widget.value, 75);
        expect(widget.startValue, 0);
        expect(widget.formatter, isNotNull);
        // Test the formatter
        expect(widget.formatter!(75), '75%');
      });

      test('percentage accepts custom parameters', () {
        const widget = CounterText.percentage(
          value: 100,
          startFrame: 5,
          duration: 120,
        );

        expect(widget.value, 100);
        expect(widget.startFrame, 5);
        expect(widget.duration, 120);
      });
    });

    group('widget rendering', () {
      testWidgets('shows start value before animation', (tester) async {
        await tester.pumpWidget(wrapWithApp(
          const CounterText(
            value: 100,
            startValue: 0,
            startFrame: 30,
            duration: 60,
          ),
          frame: 0,
        ));

        expect(find.text('0'), findsOneWidget);
      });

      testWidgets('shows end value after animation', (tester) async {
        await tester.pumpWidget(wrapWithApp(
          const CounterText(
            value: 100,
            startFrame: 0,
            duration: 60,
          ),
          frame: 100,
        ));

        expect(find.text('100'), findsOneWidget);
      });

      testWidgets('interpolates value during animation', (tester) async {
        // At frame 30 (halfway through 60-frame duration)
        // With easeOut curve, progress will be > 50%
        await tester.pumpWidget(wrapWithApp(
          const CounterText(
            value: 100,
            startValue: 0,
            startFrame: 0,
            duration: 60,
            curve: Curves.linear, // Use linear for predictable test
          ),
          frame: 30,
        ));

        // Linear: 50% of 100 = 50
        expect(find.text('50'), findsOneWidget);
      });

      testWidgets('counts down correctly', (tester) async {
        await tester.pumpWidget(wrapWithApp(
          const CounterText.countDown(
            from: 10,
            startFrame: 0,
            duration: 10,
            curve: Curves.linear,
          ),
          frame: 5,
        ));

        // Halfway: 10 - (10 * 0.5) = 5
        expect(find.text('5'), findsOneWidget);
      });

      testWidgets('handles delayed start', (tester) async {
        await tester.pumpWidget(wrapWithApp(
          const CounterText(
            value: 50,
            startFrame: 30,
            duration: 60,
          ),
          frame: 60, // 30 frames into animation
        ));

        // Should be partway through
        expect(find.byType(CounterText), findsOneWidget);
      });
    });

    group('formatter', () {
      testWidgets('applies custom formatter', (tester) async {
        await tester.pumpWidget(wrapWithApp(
          CounterText(
            value: 1000,
            startFrame: 0,
            duration: 60,
            formatter: (n) => '\$$n',
          ),
          frame: 100, // After animation
        ));

        expect(find.text('\$1000'), findsOneWidget);
      });

      testWidgets('percentage formatter works', (tester) async {
        await tester.pumpWidget(wrapWithApp(
          const CounterText.percentage(
            value: 85,
            startFrame: 0,
            duration: 60,
          ),
          frame: 100, // After animation
        ));

        expect(find.text('85%'), findsOneWidget);
      });

      testWidgets('formatter applied during animation', (tester) async {
        await tester.pumpWidget(wrapWithApp(
          CounterText(
            value: 100,
            startFrame: 0,
            duration: 100,
            curve: Curves.linear,
            formatter: (n) => 'Score: $n',
          ),
          frame: 50, // Halfway
        ));

        expect(find.text('Score: 50'), findsOneWidget);
      });
    });

    group('text styling', () {
      testWidgets('applies text style', (tester) async {
        await tester.pumpWidget(wrapWithApp(
          const CounterText(
            value: 42,
            style: TextStyle(fontSize: 48, fontWeight: FontWeight.bold),
          ),
          frame: 100,
        ));

        expect(find.text('42'), findsOneWidget);
      });

      testWidgets('applies text alignment', (tester) async {
        await tester.pumpWidget(wrapWithApp(
          const CounterText(
            value: 100,
            textAlign: TextAlign.right,
          ),
          frame: 100,
        ));

        expect(find.text('100'), findsOneWidget);
      });
    });

    group('curves', () {
      testWidgets('applies easeIn curve', (tester) async {
        await tester.pumpWidget(wrapWithApp(
          const CounterText(
            value: 100,
            curve: Curves.easeIn,
          ),
          frame: 30,
        ));

        expect(find.byType(CounterText), findsOneWidget);
      });

      testWidgets('applies bounceOut curve', (tester) async {
        await tester.pumpWidget(wrapWithApp(
          const CounterText(
            value: 100,
            curve: Curves.bounceOut,
          ),
          frame: 30,
        ));

        expect(find.byType(CounterText), findsOneWidget);
      });

      testWidgets('applies elasticOut curve', (tester) async {
        await tester.pumpWidget(wrapWithApp(
          const CounterText(
            value: 100,
            curve: Curves.elasticOut,
          ),
          frame: 30,
        ));

        expect(find.byType(CounterText), findsOneWidget);
      });
    });

    group('edge cases', () {
      testWidgets('handles zero value', (tester) async {
        await tester.pumpWidget(wrapWithApp(
          const CounterText(value: 0),
          frame: 100,
        ));

        expect(find.text('0'), findsOneWidget);
      });

      testWidgets('handles negative values', (tester) async {
        await tester.pumpWidget(wrapWithApp(
          const CounterText(
            value: -50,
            startValue: 0,
          ),
          frame: 100,
        ));

        expect(find.text('-50'), findsOneWidget);
      });

      testWidgets('handles large values', (tester) async {
        await tester.pumpWidget(wrapWithApp(
          const CounterText(value: 1000000),
          frame: 100,
        ));

        expect(find.text('1000000'), findsOneWidget);
      });

      testWidgets('handles zero duration', (tester) async {
        await tester.pumpWidget(wrapWithApp(
          const CounterText(
            value: 100,
            duration: 0,
          ),
          frame: 0,
        ));

        // Should show end value immediately
        expect(find.text('100'), findsOneWidget);
      });

      testWidgets('handles same start and end value', (tester) async {
        await tester.pumpWidget(wrapWithApp(
          const CounterText(
            value: 50,
            startValue: 50,
          ),
          frame: 30,
        ));

        expect(find.text('50'), findsOneWidget);
      });
    });
  });
}
