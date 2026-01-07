import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/templates/intro/noise_id.dart';
import 'package:fluvie/src/templates/_base/template_base.dart';
import 'package:fluvie/src/templates/_base/template_config.dart';
import 'package:fluvie/src/templates/_base/template_data.dart';
import '../../helpers/test_helpers.dart';

void main() {
  group('NoiseID', () {
    const testData = IntroData(
      title: 'UNDERGROUND',
      subtitle: '2024 Sounds',
      year: 2024,
    );

    group('construction', () {
      test('creates with required data', () {
        const template = NoiseID(data: testData);

        expect(template.data, testData);
        expect(template.introData, testData);
      });

      test('has default values', () {
        const template = NoiseID(data: testData);

        expect(template.noiseIntensity, 0.3);
        expect(template.animateInkBleed, isTrue);
        expect(template.stampColor, isNull);
      });

      test('accepts custom values', () {
        const template = NoiseID(
          data: testData,
          noiseIntensity: 0.5,
          animateInkBleed: false,
          stampColor: Colors.red,
        );

        expect(template.noiseIntensity, 0.5);
        expect(template.animateInkBleed, isFalse);
        expect(template.stampColor, Colors.red);
      });

      test('accepts theme', () {
        const template = NoiseID(
          data: testData,
          theme: TemplateTheme.minimal,
        );

        expect(template.theme, isNotNull);
      });

      test('accepts timing', () {
        const template = NoiseID(
          data: testData,
          timing: TemplateTiming.quick,
        );

        expect(template.timing, TemplateTiming.quick);
      });
    });

    group('template properties', () {
      test('recommendedLength is 120 frames', () {
        const template = NoiseID(data: testData);
        expect(template.recommendedLength, 120);
      });

      test('category is intro', () {
        const template = NoiseID(data: testData);
        expect(template.category, TemplateCategory.intro);
      });

      test('description is set', () {
        const template = NoiseID(data: testData);
        expect(template.description, isNotEmpty);
        expect(template.description, contains('ink'));
      });

      test('defaultTheme is minimal', () {
        const template = NoiseID(data: testData);
        expect(template.defaultTheme, TemplateTheme.minimal);
      });
    });

    group('introData getter', () {
      test('returns data cast to IntroData', () {
        const template = NoiseID(data: testData);
        expect(template.introData, testData);
        expect(template.introData.title, 'UNDERGROUND');
        expect(template.introData.subtitle, '2024 Sounds');
        expect(template.introData.year, 2024);
      });
    });

    group('widget rendering', () {
      testWidgets('renders without error', (tester) async {
        const template = NoiseID(data: testData);
        await tester.pumpWidget(wrapWithApp(template));

        expect(find.byType(NoiseID), findsOneWidget);
      });

      testWidgets('displays title text uppercase', (tester) async {
        const template = NoiseID(data: testData);
        await tester.pumpWidget(wrapWithApp(template, frame: 60));

        expect(find.text('UNDERGROUND'), findsWidgets);
      });

      testWidgets('displays subtitle uppercase when provided', (tester) async {
        const template = NoiseID(data: testData);
        await tester.pumpWidget(wrapWithApp(template, frame: 80));

        expect(find.text('2024 SOUNDS'), findsWidgets);
      });

      testWidgets('displays year when provided', (tester) async {
        const template = NoiseID(data: testData);
        await tester.pumpWidget(wrapWithApp(template, frame: 100));

        expect(find.text('2024'), findsWidgets);
      });

      testWidgets('renders without subtitle', (tester) async {
        const dataNoSubtitle = IntroData(title: 'Test');
        const template = NoiseID(data: dataNoSubtitle);
        await tester.pumpWidget(wrapWithApp(template));

        expect(find.byType(NoiseID), findsOneWidget);
      });

      testWidgets('renders without year', (tester) async {
        const dataNoYear = IntroData(title: 'Test', subtitle: 'Sub');
        const template = NoiseID(data: dataNoYear);
        await tester.pumpWidget(wrapWithApp(template));

        expect(find.byType(NoiseID), findsOneWidget);
      });

      testWidgets('renders with ink bleed disabled', (tester) async {
        const template = NoiseID(data: testData, animateInkBleed: false);
        await tester.pumpWidget(wrapWithApp(template));

        expect(find.byType(NoiseID), findsOneWidget);
      });

      testWidgets('renders with custom stamp color', (tester) async {
        const template = NoiseID(
          data: testData,
          stampColor: Colors.purple,
        );
        await tester.pumpWidget(wrapWithApp(template));

        expect(find.byType(NoiseID), findsOneWidget);
      });
    });

    group('toScene', () {
      test('creates scene with correct duration', () {
        const template = NoiseID(data: testData);
        final scene = template.toScene();

        expect(scene.durationInFrames, 120);
      });

      test('creates scene with custom duration', () {
        const template = NoiseID(data: testData);
        final scene = template.toScene(durationInFrames: 180);

        expect(scene.durationInFrames, 180);
      });

      test('creates scene with transitions', () {
        const template = NoiseID(data: testData);
        final scene = template.toSceneWithCrossFade();

        expect(scene.transitionIn, isNotNull);
        expect(scene.transitionOut, isNotNull);
      });
    });

    group('animation frames', () {
      testWidgets('renders correctly at frame 0', (tester) async {
        const template = NoiseID(data: testData);
        await tester.pumpWidget(wrapWithApp(template, frame: 0));

        expect(find.byType(NoiseID), findsOneWidget);
      });

      testWidgets('renders correctly at mid frame', (tester) async {
        const template = NoiseID(data: testData);
        await tester.pumpWidget(wrapWithApp(template, frame: 60));

        expect(find.byType(NoiseID), findsOneWidget);
      });

      testWidgets('renders correctly at end frame', (tester) async {
        const template = NoiseID(data: testData);
        await tester.pumpWidget(wrapWithApp(template, frame: 120));

        expect(find.byType(NoiseID), findsOneWidget);
      });
    });

    group('noise intensity variations', () {
      testWidgets('renders with low noise', (tester) async {
        const template = NoiseID(data: testData, noiseIntensity: 0.1);
        await tester.pumpWidget(wrapWithApp(template));

        expect(find.byType(NoiseID), findsOneWidget);
      });

      testWidgets('renders with high noise', (tester) async {
        const template = NoiseID(data: testData, noiseIntensity: 0.8);
        await tester.pumpWidget(wrapWithApp(template));

        expect(find.byType(NoiseID), findsOneWidget);
      });

      testWidgets('renders with zero noise', (tester) async {
        const template = NoiseID(data: testData, noiseIntensity: 0.0);
        await tester.pumpWidget(wrapWithApp(template));

        expect(find.byType(NoiseID), findsOneWidget);
      });

      testWidgets('renders with max noise', (tester) async {
        const template = NoiseID(data: testData, noiseIntensity: 1.0);
        await tester.pumpWidget(wrapWithApp(template));

        expect(find.byType(NoiseID), findsOneWidget);
      });
    });

    group('theme variations', () {
      testWidgets('renders with minimal theme', (tester) async {
        const template = NoiseID(
          data: testData,
          theme: TemplateTheme.minimal,
        );
        await tester.pumpWidget(wrapWithApp(template));

        expect(find.byType(NoiseID), findsOneWidget);
      });

      testWidgets('renders with neon theme', (tester) async {
        const template = NoiseID(
          data: testData,
          theme: TemplateTheme.neon,
        );
        await tester.pumpWidget(wrapWithApp(template));

        expect(find.byType(NoiseID), findsOneWidget);
      });

      testWidgets('renders with retro theme', (tester) async {
        const template = NoiseID(
          data: testData,
          theme: TemplateTheme.retro,
        );
        await tester.pumpWidget(wrapWithApp(template));

        expect(find.byType(NoiseID), findsOneWidget);
      });
    });

    group('edge cases', () {
      testWidgets('handles empty title', (tester) async {
        const emptyData = IntroData(title: '');
        const template = NoiseID(data: emptyData);
        await tester.pumpWidget(wrapWithApp(template));

        expect(find.byType(NoiseID), findsOneWidget);
      });

      testWidgets('handles very long title', (tester) async {
        const longData = IntroData(
          title: 'THIS IS A VERY LONG GRUNGE TITLE',
        );
        const template = NoiseID(data: longData);
        await tester.pumpWidget(wrapWithApp(template));

        expect(find.byType(NoiseID), findsOneWidget);
      });

      testWidgets('handles special characters', (tester) async {
        const specialData = IntroData(title: '!@#\$%^&*');
        const template = NoiseID(data: specialData);
        await tester.pumpWidget(wrapWithApp(template));

        expect(find.byType(NoiseID), findsOneWidget);
      });

      testWidgets('handles lowercase title (converted to uppercase)',
          (tester) async {
        const lowerData = IntroData(title: 'underground');
        const template = NoiseID(data: lowerData);
        await tester.pumpWidget(wrapWithApp(template, frame: 60));

        expect(find.text('UNDERGROUND'), findsWidgets);
      });
    });
  });
}
