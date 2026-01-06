import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/templates/intro/the_mixtape.dart';
import 'package:fluvie/src/templates/_base/template_base.dart';
import 'package:fluvie/src/templates/_base/template_config.dart';
import 'package:fluvie/src/templates/_base/template_data.dart';
import '../../helpers/test_helpers.dart';

void main() {
  group('TheMixtape', () {
    const testData = IntroData(
      title: 'Your Mixtape',
      subtitle: 'Best of 2024',
      year: 2024,
    );

    group('construction', () {
      test('creates with required data', () {
        const template = TheMixtape(data: testData);

        expect(template.data, testData);
        expect(template.introData, testData);
      });

      test('has default values', () {
        const template = TheMixtape(data: testData);

        expect(template.reelSpeed, 1.0);
        expect(template.stopMotion, isTrue);
        expect(template.labelColor, isNull);
      });

      test('accepts custom values', () {
        const template = TheMixtape(
          data: testData,
          reelSpeed: 2.0,
          stopMotion: false,
          labelColor: Colors.orange,
        );

        expect(template.reelSpeed, 2.0);
        expect(template.stopMotion, isFalse);
        expect(template.labelColor, Colors.orange);
      });

      test('accepts theme', () {
        final template = TheMixtape(
          data: testData,
          theme: TemplateTheme.retro,
        );

        expect(template.theme, isNotNull);
      });

      test('accepts timing', () {
        const template = TheMixtape(
          data: testData,
          timing: TemplateTiming.standard,
        );

        expect(template.timing, TemplateTiming.standard);
      });
    });

    group('template properties', () {
      test('recommendedLength is 150 frames', () {
        const template = TheMixtape(data: testData);
        expect(template.recommendedLength, 150);
      });

      test('category is intro', () {
        const template = TheMixtape(data: testData);
        expect(template.category, TemplateCategory.intro);
      });

      test('description is set', () {
        const template = TheMixtape(data: testData);
        expect(template.description, isNotEmpty);
        expect(template.description, contains('cassette'));
      });

      test('defaultTheme is retro', () {
        const template = TheMixtape(data: testData);
        expect(template.defaultTheme, TemplateTheme.retro);
      });
    });

    group('introData getter', () {
      test('returns data cast to IntroData', () {
        const template = TheMixtape(data: testData);
        expect(template.introData, testData);
        expect(template.introData.title, 'Your Mixtape');
        expect(template.introData.subtitle, 'Best of 2024');
        expect(template.introData.year, 2024);
      });
    });

    group('widget rendering', () {
      testWidgets('renders without error', (tester) async {
        const template = TheMixtape(data: testData);
        await tester.pumpWidget(wrapWithApp(template));

        expect(find.byType(TheMixtape), findsOneWidget);
      });

      testWidgets('displays title text uppercase', (tester) async {
        const template = TheMixtape(data: testData);
        await tester.pumpWidget(wrapWithApp(template, frame: 80));

        expect(find.text('YOUR MIXTAPE'), findsWidgets);
      });

      testWidgets('displays subtitle when provided', (tester) async {
        const template = TheMixtape(data: testData);
        await tester.pumpWidget(wrapWithApp(template, frame: 80));

        expect(find.text('Best of 2024'), findsWidgets);
      });

      testWidgets('displays year when provided', (tester) async {
        const template = TheMixtape(data: testData);
        await tester.pumpWidget(wrapWithApp(template, frame: 120));

        expect(find.text('2024'), findsWidgets);
      });

      testWidgets('renders without subtitle', (tester) async {
        const dataNoSubtitle = IntroData(title: 'Test');
        const template = TheMixtape(data: dataNoSubtitle);
        await tester.pumpWidget(wrapWithApp(template));

        expect(find.byType(TheMixtape), findsOneWidget);
      });

      testWidgets('renders without year', (tester) async {
        const dataNoYear = IntroData(title: 'Test', subtitle: 'Sub');
        const template = TheMixtape(data: dataNoYear);
        await tester.pumpWidget(wrapWithApp(template));

        expect(find.byType(TheMixtape), findsOneWidget);
      });

      testWidgets('renders with stop motion disabled', (tester) async {
        const template = TheMixtape(data: testData, stopMotion: false);
        await tester.pumpWidget(wrapWithApp(template));

        expect(find.byType(TheMixtape), findsOneWidget);
      });

      testWidgets('renders with custom label color', (tester) async {
        const template = TheMixtape(
          data: testData,
          labelColor: Colors.purple,
        );
        await tester.pumpWidget(wrapWithApp(template));

        expect(find.byType(TheMixtape), findsOneWidget);
      });
    });

    group('toScene', () {
      test('creates scene with correct duration', () {
        const template = TheMixtape(data: testData);
        final scene = template.toScene();

        expect(scene.durationInFrames, 150);
      });

      test('creates scene with custom duration', () {
        const template = TheMixtape(data: testData);
        final scene = template.toScene(durationInFrames: 200);

        expect(scene.durationInFrames, 200);
      });

      test('creates scene with transitions', () {
        const template = TheMixtape(data: testData);
        final scene = template.toSceneWithCrossFade();

        expect(scene.transitionIn, isNotNull);
        expect(scene.transitionOut, isNotNull);
      });
    });

    group('animation frames', () {
      testWidgets('renders correctly at frame 0', (tester) async {
        const template = TheMixtape(data: testData);
        await tester.pumpWidget(wrapWithApp(template, frame: 0));

        expect(find.byType(TheMixtape), findsOneWidget);
      });

      testWidgets('renders correctly at mid frame', (tester) async {
        const template = TheMixtape(data: testData);
        await tester.pumpWidget(wrapWithApp(template, frame: 75));

        expect(find.byType(TheMixtape), findsOneWidget);
      });

      testWidgets('renders correctly at end frame', (tester) async {
        const template = TheMixtape(data: testData);
        await tester.pumpWidget(wrapWithApp(template, frame: 150));

        expect(find.byType(TheMixtape), findsOneWidget);
      });
    });

    group('reel speed variations', () {
      testWidgets('renders with slow reel speed', (tester) async {
        const template = TheMixtape(data: testData, reelSpeed: 0.5);
        await tester.pumpWidget(wrapWithApp(template));

        expect(find.byType(TheMixtape), findsOneWidget);
      });

      testWidgets('renders with fast reel speed', (tester) async {
        const template = TheMixtape(data: testData, reelSpeed: 3.0);
        await tester.pumpWidget(wrapWithApp(template));

        expect(find.byType(TheMixtape), findsOneWidget);
      });
    });

    group('theme variations', () {
      testWidgets('renders with retro theme', (tester) async {
        final template = TheMixtape(
          data: testData,
          theme: TemplateTheme.retro,
        );
        await tester.pumpWidget(wrapWithApp(template));

        expect(find.byType(TheMixtape), findsOneWidget);
      });

      testWidgets('renders with neon theme', (tester) async {
        final template = TheMixtape(
          data: testData,
          theme: TemplateTheme.neon,
        );
        await tester.pumpWidget(wrapWithApp(template));

        expect(find.byType(TheMixtape), findsOneWidget);
      });

      testWidgets('renders with minimal theme', (tester) async {
        final template = TheMixtape(
          data: testData,
          theme: TemplateTheme.minimal,
        );
        await tester.pumpWidget(wrapWithApp(template));

        expect(find.byType(TheMixtape), findsOneWidget);
      });
    });

    group('edge cases', () {
      testWidgets('handles empty title', (tester) async {
        const emptyData = IntroData(title: '');
        const template = TheMixtape(data: emptyData);
        await tester.pumpWidget(wrapWithApp(template));

        expect(find.byType(TheMixtape), findsOneWidget);
      });

      testWidgets('handles very long title', (tester) async {
        const longData = IntroData(
          title: 'This is a very long mixtape title',
        );
        const template = TheMixtape(data: longData);
        await tester.pumpWidget(wrapWithApp(template));

        expect(find.byType(TheMixtape), findsOneWidget);
      });

      testWidgets('handles special characters', (tester) async {
        const specialData = IntroData(title: '90s & 2000s Hits!');
        const template = TheMixtape(data: specialData);
        await tester.pumpWidget(wrapWithApp(template));

        expect(find.byType(TheMixtape), findsOneWidget);
      });
    });
  });
}
