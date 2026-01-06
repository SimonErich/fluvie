import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/templates/data_viz/the_growth_tree.dart';
import 'package:fluvie/src/templates/_base/template_base.dart';
import 'package:fluvie/src/templates/_base/template_config.dart';
import 'package:fluvie/src/templates/_base/template_data.dart';
import '../../helpers/test_helpers.dart';

void main() {
  group('TheGrowthTree', () {
    final testData = DataVizData(
      title: 'Your Year in Music',
      metrics: [
        const MetricData(label: 'Jan', value: 20),
        const MetricData(label: 'Feb', value: 35),
        const MetricData(label: 'Mar', value: 45),
        const MetricData(label: 'Apr', value: 30),
        const MetricData(label: 'May', value: 55),
      ],
    );

    group('construction', () {
      test('creates with required data', () {
        final template = TheGrowthTree(data: testData);

        expect(template.data, testData);
        expect(template.dataVizData, testData);
      });

      test('has default values', () {
        final template = TheGrowthTree(data: testData);

        expect(template.maxVineHeight, 300);
        expect(template.vineColor, isNull);
        expect(template.showFlowers, isTrue);
        expect(template.seed, 42);
      });

      test('accepts custom values', () {
        final template = TheGrowthTree(
          data: testData,
          maxVineHeight: 400,
          vineColor: Colors.green,
          showFlowers: false,
          seed: 123,
        );

        expect(template.maxVineHeight, 400);
        expect(template.vineColor, Colors.green);
        expect(template.showFlowers, isFalse);
        expect(template.seed, 123);
      });

      test('accepts theme', () {
        final template = TheGrowthTree(
          data: testData,
          theme: TemplateTheme.pastel,
        );

        expect(template.theme, isNotNull);
      });

      test('accepts timing', () {
        final template = TheGrowthTree(
          data: testData,
          timing: TemplateTiming.elastic,
        );

        expect(template.timing, TemplateTiming.elastic);
      });
    });

    group('template properties', () {
      test('recommendedLength is 200 frames', () {
        final template = TheGrowthTree(data: testData);
        expect(template.recommendedLength, 200);
      });

      test('category is dataViz', () {
        final template = TheGrowthTree(data: testData);
        expect(template.category, TemplateCategory.dataViz);
      });

      test('description is set', () {
        final template = TheGrowthTree(data: testData);
        expect(template.description, isNotEmpty);
        expect(template.description.toLowerCase(), contains('vine'));
      });

      test('defaultTheme is pastel', () {
        final template = TheGrowthTree(data: testData);
        expect(template.defaultTheme, TemplateTheme.pastel);
      });
    });

    group('dataVizData getter', () {
      test('returns data cast to DataVizData', () {
        final template = TheGrowthTree(data: testData);
        expect(template.dataVizData, testData);
        expect(template.dataVizData.metrics.length, 5);
        expect(template.dataVizData.title, 'Your Year in Music');
      });
    });

    group('widget rendering', () {
      testWidgets('renders without error', (tester) async {
        final template = TheGrowthTree(data: testData);
        await tester.pumpWidget(wrapWithApp(template));

        expect(find.byType(TheGrowthTree), findsOneWidget);
      });

      testWidgets('displays title', (tester) async {
        final template = TheGrowthTree(data: testData);
        await tester.pumpWidget(wrapWithApp(template, frame: 30));

        expect(find.text('Your Year in Music'), findsWidgets);
      });

      testWidgets('renders without flowers', (tester) async {
        final template = TheGrowthTree(
          data: testData,
          showFlowers: false,
        );
        await tester.pumpWidget(wrapWithApp(template, frame: 100));

        expect(find.byType(TheGrowthTree), findsOneWidget);
      });

      testWidgets('renders with custom vine color', (tester) async {
        final template = TheGrowthTree(
          data: testData,
          vineColor: Colors.teal,
        );
        await tester.pumpWidget(wrapWithApp(template));

        expect(find.byType(TheGrowthTree), findsOneWidget);
      });

      testWidgets('renders with different seed', (tester) async {
        final template = TheGrowthTree(
          data: testData,
          seed: 999,
        );
        await tester.pumpWidget(wrapWithApp(template));

        expect(find.byType(TheGrowthTree), findsOneWidget);
      });
    });

    group('toScene', () {
      test('creates scene with correct duration', () {
        final template = TheGrowthTree(data: testData);
        final scene = template.toScene();

        expect(scene.durationInFrames, 200);
      });

      test('creates scene with custom duration', () {
        final template = TheGrowthTree(data: testData);
        final scene = template.toScene(durationInFrames: 300);

        expect(scene.durationInFrames, 300);
      });

      test('creates scene with transitions', () {
        final template = TheGrowthTree(data: testData);
        final scene = template.toSceneWithCrossFade();

        expect(scene.transitionIn, isNotNull);
        expect(scene.transitionOut, isNotNull);
      });
    });

    group('animation frames', () {
      testWidgets('renders correctly at frame 0', (tester) async {
        final template = TheGrowthTree(data: testData);
        await tester.pumpWidget(wrapWithApp(template, frame: 0));

        expect(find.byType(TheGrowthTree), findsOneWidget);
      });

      testWidgets('renders correctly at mid frame', (tester) async {
        final template = TheGrowthTree(data: testData);
        await tester.pumpWidget(wrapWithApp(template, frame: 100));

        expect(find.byType(TheGrowthTree), findsOneWidget);
      });

      testWidgets('renders correctly at end frame', (tester) async {
        final template = TheGrowthTree(data: testData);
        await tester.pumpWidget(wrapWithApp(template, frame: 200));

        expect(find.byType(TheGrowthTree), findsOneWidget);
      });
    });

    group('theme variations', () {
      testWidgets('renders with pastel theme', (tester) async {
        final template = TheGrowthTree(
          data: testData,
          theme: TemplateTheme.pastel,
        );
        await tester.pumpWidget(wrapWithApp(template));

        expect(find.byType(TheGrowthTree), findsOneWidget);
      });

      testWidgets('renders with ocean theme', (tester) async {
        final template = TheGrowthTree(
          data: testData,
          theme: TemplateTheme.ocean,
        );
        await tester.pumpWidget(wrapWithApp(template));

        expect(find.byType(TheGrowthTree), findsOneWidget);
      });

      testWidgets('renders with minimal theme', (tester) async {
        final template = TheGrowthTree(
          data: testData,
          theme: TemplateTheme.minimal,
        );
        await tester.pumpWidget(wrapWithApp(template));

        expect(find.byType(TheGrowthTree), findsOneWidget);
      });
    });

    group('edge cases', () {
      testWidgets('handles empty metrics', (tester) async {
        final emptyData = DataVizData(
          title: 'Empty',
          metrics: const [],
        );
        final template = TheGrowthTree(data: emptyData);
        await tester.pumpWidget(wrapWithApp(template));

        expect(find.byType(TheGrowthTree), findsOneWidget);
      });

      testWidgets('handles single metric', (tester) async {
        final singleData = DataVizData(
          title: 'Single',
          metrics: const [MetricData(label: 'Only', value: 100)],
        );
        final template = TheGrowthTree(data: singleData);
        await tester.pumpWidget(wrapWithApp(template));

        expect(find.byType(TheGrowthTree), findsOneWidget);
      });

      testWidgets('handles many metrics (12 months)', (tester) async {
        final yearData = DataVizData(
          title: 'Full Year',
          metrics: List.generate(
            12,
            (i) => MetricData(label: 'Month ${i + 1}', value: (i + 1) * 10),
          ),
        );
        final template = TheGrowthTree(data: yearData);
        await tester.pumpWidget(wrapWithApp(template));

        expect(find.byType(TheGrowthTree), findsOneWidget);
      });

      testWidgets('handles data with subtitle', (tester) async {
        final subtitleData = DataVizData(
          title: 'Growth',
          subtitle: 'Total: 500 hours',
          metrics: const [
            MetricData(label: 'A', value: 100),
            MetricData(label: 'B', value: 200),
          ],
        );
        final template = TheGrowthTree(data: subtitleData);
        await tester.pumpWidget(wrapWithApp(template, frame: 180));

        expect(find.byType(TheGrowthTree), findsOneWidget);
      });

      testWidgets('handles very small max vine height', (tester) async {
        final template = TheGrowthTree(
          data: testData,
          maxVineHeight: 50,
        );
        await tester.pumpWidget(wrapWithApp(template));

        expect(find.byType(TheGrowthTree), findsOneWidget);
      });
    });
  });
}
