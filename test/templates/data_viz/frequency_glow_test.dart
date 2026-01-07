import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/templates/data_viz/frequency_glow.dart';
import 'package:fluvie/src/templates/_base/template_base.dart';
import 'package:fluvie/src/templates/_base/template_config.dart';
import 'package:fluvie/src/templates/_base/template_data.dart';
import '../../helpers/test_helpers.dart';

void main() {
  group('FrequencyGlow', () {
    const testData = DataVizData(
      title: 'Your Sound',
      metrics: [
        MetricData(label: 'Bass', value: 80, color: Colors.purple),
        MetricData(label: 'Mid', value: 60, color: Colors.blue),
        MetricData(label: 'Treble', value: 70, color: Colors.cyan),
      ],
    );

    group('construction', () {
      test('creates with required data', () {
        const template = FrequencyGlow(data: testData);

        expect(template.data, testData);
        expect(template.dataVizData, testData);
      });

      test('has default values', () {
        const template = FrequencyGlow(data: testData);

        expect(template.barCount, 64);
        expect(template.animate, isTrue);
        expect(template.mirrored, isTrue);
        expect(template.seed, 42);
      });

      test('accepts custom values', () {
        const template = FrequencyGlow(
          data: testData,
          barCount: 32,
          animate: false,
          mirrored: false,
          seed: 123,
        );

        expect(template.barCount, 32);
        expect(template.animate, isFalse);
        expect(template.mirrored, isFalse);
        expect(template.seed, 123);
      });

      test('accepts theme', () {
        const template = FrequencyGlow(
          data: testData,
          theme: TemplateTheme.neon,
        );

        expect(template.theme, isNotNull);
      });

      test('accepts timing', () {
        const template = FrequencyGlow(
          data: testData,
          timing: TemplateTiming.elastic,
        );

        expect(template.timing, TemplateTiming.elastic);
      });
    });

    group('template properties', () {
      test('recommendedLength is 150 frames', () {
        const template = FrequencyGlow(data: testData);
        expect(template.recommendedLength, 150);
      });

      test('category is dataViz', () {
        const template = FrequencyGlow(data: testData);
        expect(template.category, TemplateCategory.dataViz);
      });

      test('description is set', () {
        const template = FrequencyGlow(data: testData);
        expect(template.description, isNotEmpty);
        expect(template.description, contains('waveform'));
      });

      test('defaultTheme is neon', () {
        const template = FrequencyGlow(data: testData);
        expect(template.defaultTheme, TemplateTheme.neon);
      });
    });

    group('dataVizData getter', () {
      test('returns data cast to DataVizData', () {
        const template = FrequencyGlow(data: testData);
        expect(template.dataVizData, testData);
        expect(template.dataVizData.metrics.length, 3);
        expect(template.dataVizData.title, 'Your Sound');
      });
    });

    group('widget rendering', () {
      testWidgets('renders without error', (tester) async {
        const template = FrequencyGlow(data: testData);
        await tester.pumpWidget(wrapWithApp(template));

        expect(find.byType(FrequencyGlow), findsOneWidget);
      });

      testWidgets('displays title', (tester) async {
        const template = FrequencyGlow(data: testData);
        await tester.pumpWidget(wrapWithApp(template, frame: 30));

        expect(find.text('Your Sound'), findsWidgets);
      });

      testWidgets('renders without animation', (tester) async {
        const template = FrequencyGlow(
          data: testData,
          animate: false,
        );
        await tester.pumpWidget(wrapWithApp(template, frame: 100));

        expect(find.byType(FrequencyGlow), findsOneWidget);
      });

      testWidgets('renders without mirror', (tester) async {
        const template = FrequencyGlow(
          data: testData,
          mirrored: false,
        );
        await tester.pumpWidget(wrapWithApp(template));

        expect(find.byType(FrequencyGlow), findsOneWidget);
      });

      testWidgets('renders with different bar count', (tester) async {
        const template = FrequencyGlow(
          data: testData,
          barCount: 128,
        );
        await tester.pumpWidget(wrapWithApp(template));

        expect(find.byType(FrequencyGlow), findsOneWidget);
      });

      testWidgets('renders with different seed', (tester) async {
        const template = FrequencyGlow(
          data: testData,
          seed: 999,
        );
        await tester.pumpWidget(wrapWithApp(template));

        expect(find.byType(FrequencyGlow), findsOneWidget);
      });
    });

    group('toScene', () {
      test('creates scene with correct duration', () {
        const template = FrequencyGlow(data: testData);
        final scene = template.toScene();

        expect(scene.durationInFrames, 150);
      });

      test('creates scene with custom duration', () {
        const template = FrequencyGlow(data: testData);
        final scene = template.toScene(durationInFrames: 200);

        expect(scene.durationInFrames, 200);
      });

      test('creates scene with transitions', () {
        const template = FrequencyGlow(data: testData);
        final scene = template.toSceneWithCrossFade();

        expect(scene.transitionIn, isNotNull);
        expect(scene.transitionOut, isNotNull);
      });
    });

    group('animation frames', () {
      testWidgets('renders correctly at frame 0', (tester) async {
        const template = FrequencyGlow(data: testData);
        await tester.pumpWidget(wrapWithApp(template, frame: 0));

        expect(find.byType(FrequencyGlow), findsOneWidget);
      });

      testWidgets('renders correctly at mid frame', (tester) async {
        const template = FrequencyGlow(data: testData);
        await tester.pumpWidget(wrapWithApp(template, frame: 75));

        expect(find.byType(FrequencyGlow), findsOneWidget);
      });

      testWidgets('renders correctly at end frame', (tester) async {
        const template = FrequencyGlow(data: testData);
        await tester.pumpWidget(wrapWithApp(template, frame: 150));

        expect(find.byType(FrequencyGlow), findsOneWidget);
      });
    });

    group('theme variations', () {
      testWidgets('renders with neon theme', (tester) async {
        const template = FrequencyGlow(
          data: testData,
          theme: TemplateTheme.neon,
        );
        await tester.pumpWidget(wrapWithApp(template));

        expect(find.byType(FrequencyGlow), findsOneWidget);
      });

      testWidgets('renders with spotify theme', (tester) async {
        const template = FrequencyGlow(
          data: testData,
          theme: TemplateTheme.spotify,
        );
        await tester.pumpWidget(wrapWithApp(template));

        expect(find.byType(FrequencyGlow), findsOneWidget);
      });

      testWidgets('renders with retro theme', (tester) async {
        const template = FrequencyGlow(
          data: testData,
          theme: TemplateTheme.retro,
        );
        await tester.pumpWidget(wrapWithApp(template));

        expect(find.byType(FrequencyGlow), findsOneWidget);
      });
    });

    group('edge cases', () {
      testWidgets('handles empty metrics', (tester) async {
        const emptyData = DataVizData(
          title: 'Empty',
          metrics: [],
        );
        const template = FrequencyGlow(data: emptyData);
        await tester.pumpWidget(wrapWithApp(template));

        expect(find.byType(FrequencyGlow), findsOneWidget);
      });

      testWidgets('handles single metric', (tester) async {
        const singleData = DataVizData(
          title: 'Single',
          metrics: [MetricData(label: 'Only', value: 100)],
        );
        const template = FrequencyGlow(data: singleData);
        await tester.pumpWidget(wrapWithApp(template));

        expect(find.byType(FrequencyGlow), findsOneWidget);
      });

      testWidgets('handles metrics without colors', (tester) async {
        const noColorData = DataVizData(
          title: 'No Colors',
          metrics: [
            MetricData(label: 'A', value: 50),
            MetricData(label: 'B', value: 30),
            MetricData(label: 'C', value: 20),
          ],
        );
        const template = FrequencyGlow(data: noColorData);
        await tester.pumpWidget(wrapWithApp(template));

        expect(find.byType(FrequencyGlow), findsOneWidget);
      });

      testWidgets('handles minimum bar count', (tester) async {
        const template = FrequencyGlow(
          data: testData,
          barCount: 8,
        );
        await tester.pumpWidget(wrapWithApp(template));

        expect(find.byType(FrequencyGlow), findsOneWidget);
      });

      testWidgets('handles large bar count', (tester) async {
        const template = FrequencyGlow(
          data: testData,
          barCount: 256,
        );
        await tester.pumpWidget(wrapWithApp(template));

        expect(find.byType(FrequencyGlow), findsOneWidget);
      });

      testWidgets('handles data without title', (tester) async {
        const noTitleData = DataVizData(
          metrics: [MetricData(label: 'Test', value: 100)],
        );
        const template = FrequencyGlow(data: noTitleData);
        await tester.pumpWidget(wrapWithApp(template));

        expect(find.byType(FrequencyGlow), findsOneWidget);
      });
    });
  });
}
