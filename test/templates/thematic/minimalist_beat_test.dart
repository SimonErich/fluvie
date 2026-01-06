import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/templates/thematic/minimalist_beat.dart';
import 'package:fluvie/src/templates/_base/template_base.dart';
import 'package:fluvie/src/templates/_base/template_config.dart';
import 'package:fluvie/src/templates/_base/template_data.dart';
import '../../helpers/test_helpers.dart';

void main() {
  group('MinimalistBeat', () {
    const testData = ThematicData(
      text: '1,234 hours',
      title: '1,234',
      subtitle: 'hours listened',
      description: 'Your dedication is impressive',
    );

    group('construction', () {
      test('creates with required data', () {
        const template = MinimalistBeat(data: testData);

        expect(template.data, testData);
        expect(template.thematicData, testData);
      });

      test('has default values', () {
        const template = MinimalistBeat(data: testData);

        expect(template.bpm, 120);
        expect(template.primaryColor, isNull);
        expect(template.secondaryColor, isNull);
        expect(template.pulseOnBeat, isTrue);
        expect(template.invertOnBeat, isFalse);
      });

      test('accepts custom values', () {
        const template = MinimalistBeat(
          data: testData,
          bpm: 90,
          primaryColor: Colors.black,
          secondaryColor: Colors.white,
          pulseOnBeat: false,
          invertOnBeat: true,
        );

        expect(template.bpm, 90);
        expect(template.primaryColor, Colors.black);
        expect(template.secondaryColor, Colors.white);
        expect(template.pulseOnBeat, isFalse);
        expect(template.invertOnBeat, isTrue);
      });

      test('accepts theme', () {
        final template = MinimalistBeat(
          data: testData,
          theme: TemplateTheme.minimal,
        );

        expect(template.theme, isNotNull);
      });

      test('accepts timing', () {
        const template = MinimalistBeat(
          data: testData,
          timing: TemplateTiming.elastic,
        );

        expect(template.timing, TemplateTiming.elastic);
      });
    });

    group('template properties', () {
      test('recommendedLength is 150 frames', () {
        const template = MinimalistBeat(data: testData);
        expect(template.recommendedLength, 150);
      });

      test('category is thematic', () {
        const template = MinimalistBeat(data: testData);
        expect(template.category, TemplateCategory.thematic);
      });

      test('description is set', () {
        const template = MinimalistBeat(data: testData);
        expect(template.description, isNotEmpty);
        expect(template.description, contains('typography'));
      });

      test('defaultTheme is minimal', () {
        const template = MinimalistBeat(data: testData);
        expect(template.defaultTheme, TemplateTheme.minimal);
      });
    });

    group('thematicData getter', () {
      test('returns data cast to ThematicData', () {
        const template = MinimalistBeat(data: testData);
        expect(template.thematicData, testData);
        expect(template.thematicData.title, '1,234');
        expect(template.thematicData.subtitle, 'hours listened');
      });
    });

    group('widget rendering', () {
      testWidgets('renders without error', (tester) async {
        const template = MinimalistBeat(data: testData);
        await tester.pumpWidget(wrapWithApp(template));

        expect(find.byType(MinimalistBeat), findsOneWidget);
      });

      testWidgets('displays title', (tester) async {
        const template = MinimalistBeat(data: testData);
        await tester.pumpWidget(wrapWithApp(template, frame: 50));

        expect(find.text('1,234'), findsWidgets);
      });

      testWidgets('renders with pulse disabled', (tester) async {
        const template = MinimalistBeat(
          data: testData,
          pulseOnBeat: false,
        );
        await tester.pumpWidget(wrapWithApp(template, frame: 15));

        expect(find.byType(MinimalistBeat), findsOneWidget);
      });

      testWidgets('renders with invert enabled', (tester) async {
        const template = MinimalistBeat(
          data: testData,
          invertOnBeat: true,
        );
        await tester.pumpWidget(wrapWithApp(template, frame: 15));

        expect(find.byType(MinimalistBeat), findsOneWidget);
      });

      testWidgets('renders with custom colors', (tester) async {
        const template = MinimalistBeat(
          data: testData,
          primaryColor: Colors.red,
          secondaryColor: Colors.yellow,
        );
        await tester.pumpWidget(wrapWithApp(template));

        expect(find.byType(MinimalistBeat), findsOneWidget);
      });
    });

    group('bpm variations', () {
      testWidgets('renders with slow bpm (60)', (tester) async {
        const template = MinimalistBeat(
          data: testData,
          bpm: 60,
        );
        await tester.pumpWidget(wrapWithApp(template, frame: 30));

        expect(find.byType(MinimalistBeat), findsOneWidget);
      });

      testWidgets('renders with fast bpm (180)', (tester) async {
        const template = MinimalistBeat(
          data: testData,
          bpm: 180,
        );
        await tester.pumpWidget(wrapWithApp(template, frame: 30));

        expect(find.byType(MinimalistBeat), findsOneWidget);
      });

      testWidgets('renders with very fast bpm (240)', (tester) async {
        const template = MinimalistBeat(
          data: testData,
          bpm: 240,
        );
        await tester.pumpWidget(wrapWithApp(template, frame: 30));

        expect(find.byType(MinimalistBeat), findsOneWidget);
      });
    });

    group('toScene', () {
      test('creates scene with correct duration', () {
        const template = MinimalistBeat(data: testData);
        final scene = template.toScene();

        expect(scene.durationInFrames, 150);
      });

      test('creates scene with custom duration', () {
        const template = MinimalistBeat(data: testData);
        final scene = template.toScene(durationInFrames: 200);

        expect(scene.durationInFrames, 200);
      });

      test('creates scene with transitions', () {
        const template = MinimalistBeat(data: testData);
        final scene = template.toSceneWithCrossFade();

        expect(scene.transitionIn, isNotNull);
        expect(scene.transitionOut, isNotNull);
      });
    });

    group('animation frames', () {
      testWidgets('renders correctly at frame 0', (tester) async {
        const template = MinimalistBeat(data: testData);
        await tester.pumpWidget(wrapWithApp(template, frame: 0));

        expect(find.byType(MinimalistBeat), findsOneWidget);
      });

      testWidgets('renders correctly during title animation', (tester) async {
        const template = MinimalistBeat(data: testData);
        await tester.pumpWidget(wrapWithApp(template, frame: 40));

        expect(find.byType(MinimalistBeat), findsOneWidget);
      });

      testWidgets('renders correctly during subtitle animation', (tester) async {
        const template = MinimalistBeat(data: testData);
        await tester.pumpWidget(wrapWithApp(template, frame: 60));

        expect(find.byType(MinimalistBeat), findsOneWidget);
      });

      testWidgets('renders correctly at mid frame', (tester) async {
        const template = MinimalistBeat(data: testData);
        await tester.pumpWidget(wrapWithApp(template, frame: 75));

        expect(find.byType(MinimalistBeat), findsOneWidget);
      });

      testWidgets('renders correctly during description animation', (tester) async {
        const template = MinimalistBeat(data: testData);
        await tester.pumpWidget(wrapWithApp(template, frame: 95));

        expect(find.byType(MinimalistBeat), findsOneWidget);
      });

      testWidgets('renders correctly at end frame', (tester) async {
        const template = MinimalistBeat(data: testData);
        await tester.pumpWidget(wrapWithApp(template, frame: 150));

        expect(find.byType(MinimalistBeat), findsOneWidget);
      });
    });

    group('theme variations', () {
      testWidgets('renders with minimal theme', (tester) async {
        final template = MinimalistBeat(
          data: testData,
          theme: TemplateTheme.minimal,
        );
        await tester.pumpWidget(wrapWithApp(template));

        expect(find.byType(MinimalistBeat), findsOneWidget);
      });

      testWidgets('renders with midnight theme', (tester) async {
        final template = MinimalistBeat(
          data: testData,
          theme: TemplateTheme.midnight,
        );
        await tester.pumpWidget(wrapWithApp(template));

        expect(find.byType(MinimalistBeat), findsOneWidget);
      });

      testWidgets('renders with neon theme', (tester) async {
        final template = MinimalistBeat(
          data: testData,
          theme: TemplateTheme.neon,
        );
        await tester.pumpWidget(wrapWithApp(template));

        expect(find.byType(MinimalistBeat), findsOneWidget);
      });
    });

    group('edge cases', () {
      testWidgets('handles data without title', (tester) async {
        const noTitleData = ThematicData(
          text: 'Hours',
          subtitle: 'hours',
          description: 'Description',
        );
        const template = MinimalistBeat(data: noTitleData);
        await tester.pumpWidget(wrapWithApp(template, frame: 40));

        expect(find.byType(MinimalistBeat), findsOneWidget);
      });

      testWidgets('handles data without subtitle', (tester) async {
        const noSubtitleData = ThematicData(
          text: '999',
          title: '999',
          description: 'Description',
        );
        const template = MinimalistBeat(data: noSubtitleData);
        await tester.pumpWidget(wrapWithApp(template, frame: 60));

        expect(find.byType(MinimalistBeat), findsOneWidget);
      });

      testWidgets('handles data without description', (tester) async {
        const noDescData = ThematicData(
          text: '5,000 songs',
          title: '5,000',
          subtitle: 'songs',
        );
        const template = MinimalistBeat(data: noDescData);
        await tester.pumpWidget(wrapWithApp(template, frame: 90));

        expect(find.byType(MinimalistBeat), findsOneWidget);
      });

      testWidgets('handles very low bpm', (tester) async {
        const template = MinimalistBeat(
          data: testData,
          bpm: 30,
        );
        await tester.pumpWidget(wrapWithApp(template, frame: 60));

        expect(find.byType(MinimalistBeat), findsOneWidget);
      });

      testWidgets('handles both pulse and invert enabled', (tester) async {
        const template = MinimalistBeat(
          data: testData,
          pulseOnBeat: true,
          invertOnBeat: true,
        );
        await tester.pumpWidget(wrapWithApp(template, frame: 15));

        expect(find.byType(MinimalistBeat), findsOneWidget);
      });

      testWidgets('handles both pulse and invert disabled', (tester) async {
        const template = MinimalistBeat(
          data: testData,
          pulseOnBeat: false,
          invertOnBeat: false,
        );
        await tester.pumpWidget(wrapWithApp(template, frame: 15));

        expect(find.byType(MinimalistBeat), findsOneWidget);
      });

      testWidgets('handles minimal data', (tester) async {
        const minimalData = ThematicData(text: 'Text');
        const template = MinimalistBeat(data: minimalData);
        await tester.pumpWidget(wrapWithApp(template));

        expect(find.byType(MinimalistBeat), findsOneWidget);
      });

      testWidgets('handles long number text', (tester) async {
        const longData = ThematicData(
          text: 'A lot of time',
          title: '1,234,567,890',
          subtitle: 'milliseconds',
        );
        const template = MinimalistBeat(data: longData);
        await tester.pumpWidget(wrapWithApp(template, frame: 50));

        expect(find.byType(MinimalistBeat), findsOneWidget);
      });
    });
  });
}
