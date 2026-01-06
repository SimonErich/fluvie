import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/templates/data_viz/orbital_metrics.dart';
import 'package:fluvie/src/templates/_base/template_base.dart';
import 'package:fluvie/src/templates/_base/template_config.dart';
import 'package:fluvie/src/templates/_base/template_data.dart';
import '../../helpers/test_helpers.dart';

void main() {
  group('OrbitalMetrics', () {
    final testData = DataVizData(
      title: 'Your Music Universe',
      metrics: [
        const MetricData(label: 'Pop', value: 45, color: Colors.pink),
        const MetricData(label: 'Rock', value: 25, color: Colors.red),
        const MetricData(label: 'Hip Hop', value: 20, color: Colors.purple),
        const MetricData(label: 'Jazz', value: 10, color: Colors.blue),
      ],
    );

    group('construction', () {
      test('creates with required data', () {
        final template = OrbitalMetrics(data: testData);

        expect(template.data, testData);
        expect(template.dataVizData, testData);
      });

      test('has default values', () {
        final template = OrbitalMetrics(data: testData);

        expect(template.orbitRadius, 200);
        expect(template.orbitSpeed, 0.3);
        expect(template.centerLabel, isNull);
        expect(template.centerValue, isNull);
      });

      test('accepts custom values', () {
        final template = OrbitalMetrics(
          data: testData,
          orbitRadius: 300,
          orbitSpeed: 0.5,
          centerLabel: 'Total',
          centerValue: '100',
        );

        expect(template.orbitRadius, 300);
        expect(template.orbitSpeed, 0.5);
        expect(template.centerLabel, 'Total');
        expect(template.centerValue, '100');
      });

      test('accepts theme', () {
        final template = OrbitalMetrics(
          data: testData,
          theme: TemplateTheme.midnight,
        );

        expect(template.theme, isNotNull);
      });

      test('accepts timing', () {
        final template = OrbitalMetrics(
          data: testData,
          timing: TemplateTiming.dramatic,
        );

        expect(template.timing, TemplateTiming.dramatic);
      });
    });

    group('template properties', () {
      test('recommendedLength is 180 frames', () {
        final template = OrbitalMetrics(data: testData);
        expect(template.recommendedLength, 180);
      });

      test('category is dataViz', () {
        final template = OrbitalMetrics(data: testData);
        expect(template.category, TemplateCategory.dataViz);
      });

      test('description is set', () {
        final template = OrbitalMetrics(data: testData);
        expect(template.description, isNotEmpty);
        expect(template.description, contains('planet'));
      });

      test('defaultTheme is midnight', () {
        final template = OrbitalMetrics(data: testData);
        expect(template.defaultTheme, TemplateTheme.midnight);
      });
    });

    group('dataVizData getter', () {
      test('returns data cast to DataVizData', () {
        final template = OrbitalMetrics(data: testData);
        expect(template.dataVizData, testData);
        expect(template.dataVizData.metrics.length, 4);
        expect(template.dataVizData.title, 'Your Music Universe');
      });
    });

    group('widget rendering', () {
      testWidgets('renders without error', (tester) async {
        final template = OrbitalMetrics(data: testData);
        await tester.pumpWidget(wrapWithApp(template));

        expect(find.byType(OrbitalMetrics), findsOneWidget);
      });

      testWidgets('displays title', (tester) async {
        final template = OrbitalMetrics(data: testData);
        await tester.pumpWidget(wrapWithApp(template, frame: 50));

        expect(find.text('Your Music Universe'), findsWidgets);
      });

      testWidgets('renders with center label', (tester) async {
        final template = OrbitalMetrics(
          data: testData,
          centerLabel: 'Total',
          centerValue: '100',
        );
        await tester.pumpWidget(wrapWithApp(template, frame: 100));

        expect(find.byType(OrbitalMetrics), findsOneWidget);
      });

      testWidgets('renders with custom orbit radius', (tester) async {
        final template = OrbitalMetrics(
          data: testData,
          orbitRadius: 150,
        );
        await tester.pumpWidget(wrapWithApp(template));

        expect(find.byType(OrbitalMetrics), findsOneWidget);
      });

      testWidgets('renders with custom orbit speed', (tester) async {
        final template = OrbitalMetrics(
          data: testData,
          orbitSpeed: 0.8,
        );
        await tester.pumpWidget(wrapWithApp(template));

        expect(find.byType(OrbitalMetrics), findsOneWidget);
      });
    });

    group('toScene', () {
      test('creates scene with correct duration', () {
        final template = OrbitalMetrics(data: testData);
        final scene = template.toScene();

        expect(scene.durationInFrames, 180);
      });

      test('creates scene with custom duration', () {
        final template = OrbitalMetrics(data: testData);
        final scene = template.toScene(durationInFrames: 250);

        expect(scene.durationInFrames, 250);
      });

      test('creates scene with transitions', () {
        final template = OrbitalMetrics(data: testData);
        final scene = template.toSceneWithCrossFade();

        expect(scene.transitionIn, isNotNull);
        expect(scene.transitionOut, isNotNull);
      });
    });

    group('animation frames', () {
      testWidgets('renders correctly at frame 0', (tester) async {
        final template = OrbitalMetrics(data: testData);
        await tester.pumpWidget(wrapWithApp(template, frame: 0));

        expect(find.byType(OrbitalMetrics), findsOneWidget);
      });

      testWidgets('renders correctly at mid frame', (tester) async {
        final template = OrbitalMetrics(data: testData);
        await tester.pumpWidget(wrapWithApp(template, frame: 90));

        expect(find.byType(OrbitalMetrics), findsOneWidget);
      });

      testWidgets('renders correctly at end frame', (tester) async {
        final template = OrbitalMetrics(data: testData);
        await tester.pumpWidget(wrapWithApp(template, frame: 180));

        expect(find.byType(OrbitalMetrics), findsOneWidget);
      });
    });

    group('theme variations', () {
      testWidgets('renders with midnight theme', (tester) async {
        final template = OrbitalMetrics(
          data: testData,
          theme: TemplateTheme.midnight,
        );
        await tester.pumpWidget(wrapWithApp(template));

        expect(find.byType(OrbitalMetrics), findsOneWidget);
      });

      testWidgets('renders with neon theme', (tester) async {
        final template = OrbitalMetrics(
          data: testData,
          theme: TemplateTheme.neon,
        );
        await tester.pumpWidget(wrapWithApp(template));

        expect(find.byType(OrbitalMetrics), findsOneWidget);
      });

      testWidgets('renders with spotify theme', (tester) async {
        final template = OrbitalMetrics(
          data: testData,
          theme: TemplateTheme.spotify,
        );
        await tester.pumpWidget(wrapWithApp(template));

        expect(find.byType(OrbitalMetrics), findsOneWidget);
      });
    });

    group('edge cases', () {
      testWidgets('handles single metric', (tester) async {
        final singleData = DataVizData(
          title: 'Single Metric',
          metrics: const [MetricData(label: 'Only One', value: 100)],
        );
        final template = OrbitalMetrics(data: singleData);
        await tester.pumpWidget(wrapWithApp(template));

        expect(find.byType(OrbitalMetrics), findsOneWidget);
      });

      testWidgets('handles many metrics', (tester) async {
        final manyData = DataVizData(
          title: 'Many Metrics',
          metrics: List.generate(
            10,
            (i) => MetricData(label: 'Metric ${i + 1}', value: (i + 1) * 10),
          ),
        );
        final template = OrbitalMetrics(data: manyData);
        await tester.pumpWidget(wrapWithApp(template));

        expect(find.byType(OrbitalMetrics), findsOneWidget);
      });

      testWidgets('handles metrics without colors', (tester) async {
        final noColorData = DataVizData(
          title: 'No Colors',
          metrics: const [
            MetricData(label: 'A', value: 50),
            MetricData(label: 'B', value: 30),
            MetricData(label: 'C', value: 20),
          ],
        );
        final template = OrbitalMetrics(data: noColorData);
        await tester.pumpWidget(wrapWithApp(template));

        expect(find.byType(OrbitalMetrics), findsOneWidget);
      });

      testWidgets('handles long metric labels', (tester) async {
        final longLabelData = DataVizData(
          title: 'Long Labels',
          metrics: const [
            MetricData(
              label: 'This is a very long metric label',
              value: 100,
            ),
          ],
        );
        final template = OrbitalMetrics(data: longLabelData);
        await tester.pumpWidget(wrapWithApp(template));

        expect(find.byType(OrbitalMetrics), findsOneWidget);
      });

      testWidgets('handles data without title', (tester) async {
        final noTitleData = DataVizData(
          metrics: const [MetricData(label: 'Test', value: 100)],
        );
        final template = OrbitalMetrics(data: noTitleData);
        await tester.pumpWidget(wrapWithApp(template));

        expect(find.byType(OrbitalMetrics), findsOneWidget);
      });
    });
  });
}
