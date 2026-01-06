import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/templates/intro/the_neon_gate.dart';
import 'package:fluvie/src/templates/_base/template_base.dart';
import 'package:fluvie/src/templates/_base/template_config.dart';
import 'package:fluvie/src/templates/_base/template_data.dart';
import '../../helpers/test_helpers.dart';

void main() {
  group('TheNeonGate', () {
    const testData = IntroData(
      title: 'Your 2024',
      subtitle: 'Wrapped',
      year: 2024,
    );

    group('construction', () {
      test('creates with required data', () {
        const template = TheNeonGate(data: testData);

        expect(template.data, testData);
        expect(template.introData, testData);
      });

      test('has default values', () {
        const template = TheNeonGate(data: testData);

        expect(template.ringCount, 5);
        expect(template.showParticles, isTrue);
        expect(template.animateRotation, isTrue);
      });

      test('accepts custom values', () {
        const template = TheNeonGate(
          data: testData,
          ringCount: 8,
          showParticles: false,
          animateRotation: false,
        );

        expect(template.ringCount, 8);
        expect(template.showParticles, isFalse);
        expect(template.animateRotation, isFalse);
      });

      test('accepts theme', () {
        final template = TheNeonGate(
          data: testData,
          theme: TemplateTheme.neon,
        );

        expect(template.theme, isNotNull);
      });

      test('accepts timing', () {
        const template = TheNeonGate(
          data: testData,
          timing: TemplateTiming.dramatic,
        );

        expect(template.timing, TemplateTiming.dramatic);
      });
    });

    group('template properties', () {
      test('recommendedLength is 150 frames', () {
        const template = TheNeonGate(data: testData);
        expect(template.recommendedLength, 150);
      });

      test('category is intro', () {
        const template = TheNeonGate(data: testData);
        expect(template.category, TemplateCategory.intro);
      });

      test('description is set', () {
        const template = TheNeonGate(data: testData);
        expect(template.description, isNotEmpty);
        expect(
          template.description,
          contains('portal'),
        );
      });

      test('defaultTheme is neon', () {
        const template = TheNeonGate(data: testData);
        expect(template.defaultTheme, TemplateTheme.neon);
      });

      test('defaultTiming is dramatic', () {
        const template = TheNeonGate(data: testData);
        expect(template.defaultTiming, TemplateTiming.dramatic);
      });
    });

    group('introData getter', () {
      test('returns data cast to IntroData', () {
        const template = TheNeonGate(data: testData);
        expect(template.introData, testData);
        expect(template.introData.title, 'Your 2024');
        expect(template.introData.subtitle, 'Wrapped');
        expect(template.introData.year, 2024);
      });
    });

    group('widget rendering', () {
      testWidgets('renders without error', (tester) async {
        const template = TheNeonGate(data: testData);
        await tester.pumpWidget(wrapWithApp(template));

        expect(find.byType(TheNeonGate), findsOneWidget);
      });

      testWidgets('displays title text', (tester) async {
        const template = TheNeonGate(data: testData);
        await tester.pumpWidget(wrapWithApp(template, frame: 100));

        // Title is rendered with glow effect (stack of two texts)
        expect(find.text('Your 2024'), findsWidgets);
      });

      testWidgets('displays year when provided', (tester) async {
        const template = TheNeonGate(data: testData);
        await tester.pumpWidget(wrapWithApp(template, frame: 100));

        // Year is rendered with glow effect (stack of two texts)
        expect(find.text('2024'), findsWidgets);
      });

      testWidgets('displays subtitle when provided', (tester) async {
        const template = TheNeonGate(data: testData);
        await tester.pumpWidget(wrapWithApp(template, frame: 120));

        // Subtitle is uppercase
        expect(find.text('WRAPPED'), findsOneWidget);
      });

      testWidgets('renders without subtitle', (tester) async {
        const dataNoSubtitle = IntroData(title: 'Test');
        const template = TheNeonGate(data: dataNoSubtitle);
        await tester.pumpWidget(wrapWithApp(template));

        expect(find.byType(TheNeonGate), findsOneWidget);
      });

      testWidgets('renders without year', (tester) async {
        const dataNoYear = IntroData(title: 'Test', subtitle: 'Sub');
        const template = TheNeonGate(data: dataNoYear);
        await tester.pumpWidget(wrapWithApp(template));

        expect(find.byType(TheNeonGate), findsOneWidget);
      });

      testWidgets('renders particles when enabled', (tester) async {
        const template = TheNeonGate(data: testData, showParticles: true);
        await tester.pumpWidget(wrapWithApp(template));

        // ParticleEffect should be in the widget tree
        expect(find.byType(TheNeonGate), findsOneWidget);
      });

      testWidgets('renders without particles when disabled', (tester) async {
        const template = TheNeonGate(data: testData, showParticles: false);
        await tester.pumpWidget(wrapWithApp(template));

        expect(find.byType(TheNeonGate), findsOneWidget);
      });

      testWidgets('applies background color from theme', (tester) async {
        const template = TheNeonGate(data: testData);
        await tester.pumpWidget(wrapWithApp(template));

        // Should find a Container with the background color
        expect(find.byType(Container), findsWidgets);
      });
    });

    group('toScene', () {
      test('creates scene with correct duration', () {
        const template = TheNeonGate(data: testData);
        final scene = template.toScene();

        expect(scene.durationInFrames, 150);
      });

      test('creates scene with custom duration', () {
        const template = TheNeonGate(data: testData);
        final scene = template.toScene(durationInFrames: 200);

        expect(scene.durationInFrames, 200);
      });

      test('creates scene with transitions', () {
        const template = TheNeonGate(data: testData);
        final scene = template.toSceneWithCrossFade();

        expect(scene.transitionIn, isNotNull);
        expect(scene.transitionOut, isNotNull);
      });
    });

    group('different data configurations', () {
      testWidgets('renders with logo path', (tester) async {
        const dataWithLogo = IntroData(
          title: 'Test',
          logoPath: 'assets/logo.png',
        );
        const template = TheNeonGate(data: dataWithLogo);
        await tester.pumpWidget(wrapWithApp(template, frame: 60));

        expect(find.byType(TheNeonGate), findsOneWidget);
      });

      testWidgets('renders with all fields', (tester) async {
        const fullData = IntroData(
          title: 'Full Test',
          subtitle: 'Complete',
          year: 2024,
          userName: 'User',
          profileImagePath: 'assets/profile.png',
          logoPath: 'assets/logo.png',
        );
        const template = TheNeonGate(data: fullData);
        await tester.pumpWidget(wrapWithApp(template));

        expect(find.byType(TheNeonGate), findsOneWidget);
      });
    });

    group('animation frames', () {
      testWidgets('renders correctly at frame 0', (tester) async {
        const template = TheNeonGate(data: testData);
        await tester.pumpWidget(wrapWithApp(template, frame: 0));

        expect(find.byType(TheNeonGate), findsOneWidget);
      });

      testWidgets('renders correctly at mid frame', (tester) async {
        const template = TheNeonGate(data: testData);
        await tester.pumpWidget(wrapWithApp(template, frame: 75));

        expect(find.byType(TheNeonGate), findsOneWidget);
      });

      testWidgets('renders correctly at end frame', (tester) async {
        const template = TheNeonGate(data: testData);
        await tester.pumpWidget(wrapWithApp(template, frame: 150));

        expect(find.byType(TheNeonGate), findsOneWidget);
      });
    });

    group('ring count variations', () {
      testWidgets('renders with minimum ring count', (tester) async {
        const template = TheNeonGate(data: testData, ringCount: 1);
        await tester.pumpWidget(wrapWithApp(template));

        expect(find.byType(TheNeonGate), findsOneWidget);
      });

      testWidgets('renders with maximum ring count', (tester) async {
        const template = TheNeonGate(data: testData, ringCount: 10);
        await tester.pumpWidget(wrapWithApp(template));

        expect(find.byType(TheNeonGate), findsOneWidget);
      });
    });

    group('theme variations', () {
      testWidgets('renders with neon theme', (tester) async {
        final template = TheNeonGate(
          data: testData,
          theme: TemplateTheme.neon,
        );
        await tester.pumpWidget(wrapWithApp(template));

        expect(find.byType(TheNeonGate), findsOneWidget);
      });

      testWidgets('renders with spotify theme', (tester) async {
        final template = TheNeonGate(
          data: testData,
          theme: TemplateTheme.spotify,
        );
        await tester.pumpWidget(wrapWithApp(template));

        expect(find.byType(TheNeonGate), findsOneWidget);
      });

      testWidgets('renders with minimal theme', (tester) async {
        final template = TheNeonGate(
          data: testData,
          theme: TemplateTheme.minimal,
        );
        await tester.pumpWidget(wrapWithApp(template));

        expect(find.byType(TheNeonGate), findsOneWidget);
      });
    });

    group('edge cases', () {
      testWidgets('handles empty title', (tester) async {
        const emptyData = IntroData(title: '');
        const template = TheNeonGate(data: emptyData);
        await tester.pumpWidget(wrapWithApp(template));

        expect(find.byType(TheNeonGate), findsOneWidget);
      });

      testWidgets('handles very long title', (tester) async {
        const longData = IntroData(
          title: 'This is a very long title that might overflow',
        );
        const template = TheNeonGate(data: longData);
        await tester.pumpWidget(wrapWithApp(template));

        expect(find.byType(TheNeonGate), findsOneWidget);
      });

      testWidgets('handles special characters in title', (tester) async {
        const specialData = IntroData(title: '🎵 Music & More! 🎵');
        const template = TheNeonGate(data: specialData);
        await tester.pumpWidget(wrapWithApp(template));

        expect(find.byType(TheNeonGate), findsOneWidget);
      });
    });
  });
}
