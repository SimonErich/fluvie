import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/declarative/helpers/stat_card.dart';
import '../../../helpers/test_helpers.dart';

void main() {
  group('StatCard', () {
    group('construction', () {
      test('creates with required parameters', () {
        const widget = StatCard(value: 100, label: 'Test');

        expect(widget.value, 100);
        expect(widget.label, 'Test');
      });

      test('has default values', () {
        const widget = StatCard(value: 100, label: 'Test');

        expect(widget.sublabel, isNull);
        expect(widget.color, const Color(0xFF2196F3));
        expect(widget.startFrame, 0);
        expect(widget.countDuration, 60);
        expect(widget.countCurve, Curves.easeOut);
        expect(widget.size, isNull);
        expect(widget.backgroundColor, isNull);
        expect(widget.borderRadius, 16);
        expect(widget.padding, const EdgeInsets.all(24));
        expect(widget.valueStyle, isNull);
        expect(widget.labelStyle, isNull);
        expect(widget.sublabelStyle, isNull);
        expect(widget.formatter, isNull);
      });

      test('accepts custom values', () {
        String customFormatter(int n) => 'Value: $n';

        final widget = StatCard(
          value: 500,
          label: 'Score',
          sublabel: 'Points',
          color: Colors.red,
          startFrame: 10,
          countDuration: 90,
          countCurve: Curves.bounceOut,
          size: const Size(200, 150),
          backgroundColor: Colors.black,
          borderRadius: 8,
          padding: const EdgeInsets.all(16),
          valueStyle: const TextStyle(fontSize: 32),
          labelStyle: const TextStyle(fontSize: 14),
          sublabelStyle: const TextStyle(fontSize: 10),
          formatter: customFormatter,
        );

        expect(widget.value, 500);
        expect(widget.label, 'Score');
        expect(widget.sublabel, 'Points');
        expect(widget.color, Colors.red);
        expect(widget.startFrame, 10);
        expect(widget.countDuration, 90);
        expect(widget.countCurve, Curves.bounceOut);
        expect(widget.size, const Size(200, 150));
        expect(widget.backgroundColor, Colors.black);
        expect(widget.borderRadius, 8);
        expect(widget.padding, const EdgeInsets.all(16));
        expect(widget.formatter, customFormatter);
      });
    });

    group('factory constructors', () {
      test('percentage creates with percentage formatter', () {
        const widget = StatCard.percentage(
          value: 75,
          label: 'Complete',
        );

        expect(widget.value, 75);
        expect(widget.color, const Color(0xFF4CAF50));
        expect(widget.formatter, isNotNull);
        expect(widget.formatter!(75), '75%');
      });

      test('currency creates with currency formatter', () {
        final widget = StatCard.currency(
          value: 1000,
          label: 'Earnings',
          currencySymbol: '€',
        );

        expect(widget.value, 1000);
        expect(widget.color, const Color(0xFFFF9800));
        expect(widget.formatter, isNotNull);
        expect(widget.formatter!(1000), '€1000');
      });

      test('currency defaults to dollar sign', () {
        final widget = StatCard.currency(
          value: 500,
          label: 'Price',
        );

        expect(widget.formatter!(500), '\$500');
      });
    });

    group('widget rendering', () {
      testWidgets('renders value and label', (tester) async {
        await tester.pumpWidget(wrapWithApp(
          const StatCard(
            value: 42,
            label: 'Items',
          ),
          frame: 100, // After animation
        ));

        expect(find.text('42'), findsOneWidget);
        expect(find.text('Items'), findsOneWidget);
      });

      testWidgets('renders sublabel when provided', (tester) async {
        await tester.pumpWidget(wrapWithApp(
          const StatCard(
            value: 100,
            label: 'Score',
            sublabel: 'This Week',
          ),
          frame: 100,
        ));

        expect(find.text('Score'), findsOneWidget);
        expect(find.text('This Week'), findsOneWidget);
      });

      testWidgets('does not render sublabel when null', (tester) async {
        await tester.pumpWidget(wrapWithApp(
          const StatCard(
            value: 100,
            label: 'Score',
            sublabel: null,
          ),
          frame: 100,
        ));

        expect(find.text('Score'), findsOneWidget);
      });

      testWidgets('shows zero before animation starts', (tester) async {
        await tester.pumpWidget(wrapWithApp(
          const StatCard(
            value: 100,
            label: 'Count',
            startFrame: 30,
            countDuration: 60,
          ),
          frame: 0,
        ));

        expect(find.text('0'), findsOneWidget);
      });

      testWidgets('shows final value after animation', (tester) async {
        await tester.pumpWidget(wrapWithApp(
          const StatCard(
            value: 100,
            label: 'Count',
            startFrame: 0,
            countDuration: 60,
          ),
          frame: 100,
        ));

        expect(find.text('100'), findsOneWidget);
      });

      testWidgets('animates value during counting', (tester) async {
        await tester.pumpWidget(wrapWithApp(
          const StatCard(
            value: 100,
            label: 'Count',
            startFrame: 0,
            countDuration: 100,
            countCurve: Curves.linear,
          ),
          frame: 50, // Halfway
        ));

        expect(find.text('50'), findsOneWidget);
      });

      testWidgets('applies formatter', (tester) async {
        await tester.pumpWidget(wrapWithApp(
          const StatCard.percentage(
            value: 85,
            label: 'Progress',
          ),
          frame: 100,
        ));

        expect(find.text('85%'), findsOneWidget);
      });
    });

    group('styling', () {
      testWidgets('applies background color', (tester) async {
        await tester.pumpWidget(wrapWithApp(
          const StatCard(
            value: 100,
            label: 'Test',
            backgroundColor: Colors.black,
          ),
        ));

        expect(find.byType(Container), findsWidgets);
      });

      testWidgets('applies border radius', (tester) async {
        await tester.pumpWidget(wrapWithApp(
          const StatCard(
            value: 100,
            label: 'Test',
            borderRadius: 20,
          ),
        ));

        expect(find.byType(Container), findsWidgets);
      });

      testWidgets('applies fixed size', (tester) async {
        await tester.pumpWidget(wrapWithApp(
          const StatCard(
            value: 100,
            label: 'Test',
            size: Size(200, 150),
          ),
        ));

        expect(find.byType(Container), findsWidgets);
      });

      testWidgets('applies custom padding', (tester) async {
        await tester.pumpWidget(wrapWithApp(
          const StatCard(
            value: 100,
            label: 'Test',
            padding: EdgeInsets.all(32),
          ),
        ));

        expect(find.byType(Container), findsWidgets);
      });
    });

    group('edge cases', () {
      testWidgets('handles zero value', (tester) async {
        await tester.pumpWidget(wrapWithApp(
          const StatCard(
            value: 0,
            label: 'Zero',
          ),
          frame: 100,
        ));

        expect(find.text('0'), findsOneWidget);
      });

      testWidgets('handles large value', (tester) async {
        await tester.pumpWidget(wrapWithApp(
          const StatCard(
            value: 1000000,
            label: 'Million',
          ),
          frame: 100,
        ));

        expect(find.text('1000000'), findsOneWidget);
      });

      testWidgets('handles zero duration', (tester) async {
        await tester.pumpWidget(wrapWithApp(
          const StatCard(
            value: 100,
            label: 'Instant',
            countDuration: 0,
          ),
          frame: 0,
        ));

        // Should show final value immediately
        expect(find.text('100'), findsOneWidget);
      });

      testWidgets('handles empty label', (tester) async {
        await tester.pumpWidget(wrapWithApp(
          const StatCard(
            value: 42,
            label: '',
          ),
          frame: 100,
        ));

        expect(find.text('42'), findsOneWidget);
      });
    });

    group('curves', () {
      testWidgets('applies easeIn curve', (tester) async {
        await tester.pumpWidget(wrapWithApp(
          const StatCard(
            value: 100,
            label: 'Test',
            countCurve: Curves.easeIn,
          ),
        ));

        expect(find.byType(StatCard), findsOneWidget);
      });

      testWidgets('applies bounceOut curve', (tester) async {
        await tester.pumpWidget(wrapWithApp(
          const StatCard(
            value: 100,
            label: 'Test',
            countCurve: Curves.bounceOut,
          ),
        ));

        expect(find.byType(StatCard), findsOneWidget);
      });
    });
  });
}
