import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/templates/data_viz/liquid_minutes.dart';
import 'package:fluvie/src/templates/_base/template_base.dart';
import 'package:fluvie/src/templates/_base/template_config.dart';
import 'package:fluvie/src/templates/_base/template_data.dart';
import '../../helpers/test_helpers.dart';

void main() {
  group('LiquidMinutes', () {
    const testData = DataVizData(
      title: 'Minutes Listened',
      metrics: [
        MetricData(label: 'This Year', value: 45000),
      ],
    );

    group('construction', () {
      test('creates with required data', () {
        const template = LiquidMinutes(data: testData);

        expect(template.data, testData);
        expect(template.dataVizData, testData);
      });

      test('has default values', () {
        const template = LiquidMinutes(data: testData);

        expect(template.containerShape, ContainerShape.glass);
        expect(template.liquidColor, isNull);
        expect(template.showBubbles, isTrue);
        expect(template.fillTarget, 0.85);
      });

      test('accepts custom values', () {
        const template = LiquidMinutes(
          data: testData,
          containerShape: ContainerShape.jar,
          liquidColor: Colors.blue,
          showBubbles: false,
          fillTarget: 0.5,
        );

        expect(template.containerShape, ContainerShape.jar);
        expect(template.liquidColor, Colors.blue);
        expect(template.showBubbles, isFalse);
        expect(template.fillTarget, 0.5);
      });

      test('accepts theme', () {
        const template = LiquidMinutes(
          data: testData,
          theme: TemplateTheme.ocean,
        );

        expect(template.theme, isNotNull);
      });

      test('accepts timing', () {
        const template = LiquidMinutes(
          data: testData,
          timing: TemplateTiming.dramatic,
        );

        expect(template.timing, TemplateTiming.dramatic);
      });
    });

    group('template properties', () {
      test('recommendedLength is 180 frames', () {
        const template = LiquidMinutes(data: testData);
        expect(template.recommendedLength, 180);
      });

      test('category is dataViz', () {
        const template = LiquidMinutes(data: testData);
        expect(template.category, TemplateCategory.dataViz);
      });

      test('description is set', () {
        const template = LiquidMinutes(data: testData);
        expect(template.description, isNotEmpty);
        expect(template.description, contains('liquid'));
      });

      test('defaultTheme is ocean', () {
        const template = LiquidMinutes(data: testData);
        expect(template.defaultTheme, TemplateTheme.ocean);
      });
    });

    group('dataVizData getter', () {
      test('returns data cast to DataVizData', () {
        const template = LiquidMinutes(data: testData);
        expect(template.dataVizData, testData);
        expect(template.dataVizData.total, 45000); // Computed from metrics
        expect(template.dataVizData.title, 'Minutes Listened');
      });
    });

    group('widget rendering', () {
      testWidgets('renders without error', (tester) async {
        const template = LiquidMinutes(data: testData);
        await tester.pumpWidget(wrapWithApp(template));

        expect(find.byType(LiquidMinutes), findsOneWidget);
      });

      testWidgets('displays title', (tester) async {
        const template = LiquidMinutes(data: testData);
        await tester.pumpWidget(wrapWithApp(template, frame: 30));

        expect(find.text('Minutes Listened'), findsWidgets);
      });

      testWidgets('renders without bubbles', (tester) async {
        const template = LiquidMinutes(
          data: testData,
          showBubbles: false,
        );
        await tester.pumpWidget(wrapWithApp(template, frame: 100));

        expect(find.byType(LiquidMinutes), findsOneWidget);
      });

      testWidgets('renders with custom liquid color', (tester) async {
        const template = LiquidMinutes(
          data: testData,
          liquidColor: Colors.purple,
        );
        await tester.pumpWidget(wrapWithApp(template));

        expect(find.byType(LiquidMinutes), findsOneWidget);
      });
    });

    group('container shapes', () {
      testWidgets('renders with glass shape', (tester) async {
        const template = LiquidMinutes(
          data: testData,
          containerShape: ContainerShape.glass,
        );
        await tester.pumpWidget(wrapWithApp(template));

        expect(find.byType(LiquidMinutes), findsOneWidget);
      });

      testWidgets('renders with jar shape', (tester) async {
        const template = LiquidMinutes(
          data: testData,
          containerShape: ContainerShape.jar,
        );
        await tester.pumpWidget(wrapWithApp(template));

        expect(find.byType(LiquidMinutes), findsOneWidget);
      });

      testWidgets('renders with bottle shape', (tester) async {
        const template = LiquidMinutes(
          data: testData,
          containerShape: ContainerShape.bottle,
        );
        await tester.pumpWidget(wrapWithApp(template));

        expect(find.byType(LiquidMinutes), findsOneWidget);
      });

      testWidgets('renders with beaker shape', (tester) async {
        const template = LiquidMinutes(
          data: testData,
          containerShape: ContainerShape.beaker,
        );
        await tester.pumpWidget(wrapWithApp(template));

        expect(find.byType(LiquidMinutes), findsOneWidget);
      });
    });

    group('toScene', () {
      test('creates scene with correct duration', () {
        const template = LiquidMinutes(data: testData);
        final scene = template.toScene();

        expect(scene.durationInFrames, 180);
      });

      test('creates scene with custom duration', () {
        const template = LiquidMinutes(data: testData);
        final scene = template.toScene(durationInFrames: 240);

        expect(scene.durationInFrames, 240);
      });

      test('creates scene with transitions', () {
        const template = LiquidMinutes(data: testData);
        final scene = template.toSceneWithCrossFade();

        expect(scene.transitionIn, isNotNull);
        expect(scene.transitionOut, isNotNull);
      });
    });

    group('animation frames', () {
      testWidgets('renders correctly at frame 0', (tester) async {
        const template = LiquidMinutes(data: testData);
        await tester.pumpWidget(wrapWithApp(template, frame: 0));

        expect(find.byType(LiquidMinutes), findsOneWidget);
      });

      testWidgets('renders correctly at mid frame', (tester) async {
        const template = LiquidMinutes(data: testData);
        await tester.pumpWidget(wrapWithApp(template, frame: 90));

        expect(find.byType(LiquidMinutes), findsOneWidget);
      });

      testWidgets('renders correctly at end frame', (tester) async {
        const template = LiquidMinutes(data: testData);
        await tester.pumpWidget(wrapWithApp(template, frame: 180));

        expect(find.byType(LiquidMinutes), findsOneWidget);
      });
    });

    group('theme variations', () {
      testWidgets('renders with ocean theme', (tester) async {
        const template = LiquidMinutes(
          data: testData,
          theme: TemplateTheme.ocean,
        );
        await tester.pumpWidget(wrapWithApp(template));

        expect(find.byType(LiquidMinutes), findsOneWidget);
      });

      testWidgets('renders with neon theme', (tester) async {
        const template = LiquidMinutes(
          data: testData,
          theme: TemplateTheme.neon,
        );
        await tester.pumpWidget(wrapWithApp(template));

        expect(find.byType(LiquidMinutes), findsOneWidget);
      });

      testWidgets('renders with midnight theme', (tester) async {
        const template = LiquidMinutes(
          data: testData,
          theme: TemplateTheme.midnight,
        );
        await tester.pumpWidget(wrapWithApp(template));

        expect(find.byType(LiquidMinutes), findsOneWidget);
      });
    });

    group('edge cases', () {
      testWidgets('handles zero total', (tester) async {
        const zeroData = DataVizData(
          title: 'No Minutes',
          metrics: [MetricData(label: 'None', value: 0)],
        );
        const template = LiquidMinutes(data: zeroData);
        await tester.pumpWidget(wrapWithApp(template));

        expect(find.byType(LiquidMinutes), findsOneWidget);
      });

      testWidgets('handles large total (hours formatting)', (tester) async {
        const largeData = DataVizData(
          title: 'Many Hours',
          metrics: [MetricData(label: 'Total', value: 100000)],
        );
        const template = LiquidMinutes(data: largeData);
        await tester.pumpWidget(wrapWithApp(template, frame: 120));

        expect(find.byType(LiquidMinutes), findsOneWidget);
      });

      testWidgets('handles fill target of 0', (tester) async {
        const template = LiquidMinutes(
          data: testData,
          fillTarget: 0.0,
        );
        await tester.pumpWidget(wrapWithApp(template));

        expect(find.byType(LiquidMinutes), findsOneWidget);
      });

      testWidgets('handles fill target of 1', (tester) async {
        const template = LiquidMinutes(
          data: testData,
          fillTarget: 1.0,
        );
        await tester.pumpWidget(wrapWithApp(template));

        expect(find.byType(LiquidMinutes), findsOneWidget);
      });

      testWidgets('handles data with subtitle', (tester) async {
        const subtitleData = DataVizData(
          title: 'Minutes',
          subtitle: 'More than last year!',
          metrics: [MetricData(label: 'Total', value: 5000)],
        );
        const template = LiquidMinutes(data: subtitleData);
        await tester.pumpWidget(wrapWithApp(template, frame: 120));

        expect(find.byType(LiquidMinutes), findsOneWidget);
      });
    });
  });

  group('ContainerShape', () {
    test('has all expected shapes', () {
      expect(ContainerShape.values, hasLength(4));
      expect(ContainerShape.values, contains(ContainerShape.glass));
      expect(ContainerShape.values, contains(ContainerShape.jar));
      expect(ContainerShape.values, contains(ContainerShape.bottle));
      expect(ContainerShape.values, contains(ContainerShape.beaker));
    });
  });
}
