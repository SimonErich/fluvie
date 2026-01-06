import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/templates/thematic/retro_postcard.dart';
import 'package:fluvie/src/templates/_base/template_base.dart';
import 'package:fluvie/src/templates/_base/template_config.dart';
import 'package:fluvie/src/templates/_base/template_data.dart';
import '../../helpers/test_helpers.dart';

void main() {
  group('RetroPostcard', () {
    const testData = ThematicData(
      text: 'New York',
      title: 'GREETINGS FROM',
      subtitle: 'New York',
      description: 'Your most played city',
      value: '456 plays',
      metadata: {'stamp': '2024'},
    );

    group('construction', () {
      test('creates with required data', () {
        const template = RetroPostcard(data: testData);

        expect(template.data, testData);
        expect(template.thematicData, testData);
      });

      test('has default values', () {
        const template = RetroPostcard(data: testData);

        expect(template.showStamp, isTrue);
        expect(template.showTexture, isTrue);
        expect(template.borderColor, isNull);
        expect(template.seed, 42);
      });

      test('accepts custom values', () {
        const template = RetroPostcard(
          data: testData,
          showStamp: false,
          showTexture: false,
          borderColor: Colors.brown,
          seed: 123,
        );

        expect(template.showStamp, isFalse);
        expect(template.showTexture, isFalse);
        expect(template.borderColor, Colors.brown);
        expect(template.seed, 123);
      });

      test('accepts theme', () {
        final template = RetroPostcard(
          data: testData,
          theme: TemplateTheme.pastel,
        );

        expect(template.theme, isNotNull);
      });

      test('accepts timing', () {
        const template = RetroPostcard(
          data: testData,
          timing: TemplateTiming.dramatic,
        );

        expect(template.timing, TemplateTiming.dramatic);
      });
    });

    group('template properties', () {
      test('recommendedLength is 180 frames', () {
        const template = RetroPostcard(data: testData);
        expect(template.recommendedLength, 180);
      });

      test('category is thematic', () {
        const template = RetroPostcard(data: testData);
        expect(template.category, TemplateCategory.thematic);
      });

      test('description is set', () {
        const template = RetroPostcard(data: testData);
        expect(template.description, isNotEmpty);
        expect(template.description, contains('postcard'));
      });

      test('defaultTheme is pastel', () {
        const template = RetroPostcard(data: testData);
        expect(template.defaultTheme, TemplateTheme.pastel);
      });
    });

    group('thematicData getter', () {
      test('returns data cast to ThematicData', () {
        const template = RetroPostcard(data: testData);
        expect(template.thematicData, testData);
        expect(template.thematicData.title, 'GREETINGS FROM');
        expect(template.thematicData.subtitle, 'New York');
        expect(template.thematicData.metadata, {'stamp': '2024'});
      });
    });

    group('widget rendering', () {
      testWidgets('renders without error', (tester) async {
        const template = RetroPostcard(data: testData);
        await tester.pumpWidget(wrapWithApp(template));

        expect(find.byType(RetroPostcard), findsOneWidget);
      });

      testWidgets('renders without stamp', (tester) async {
        const template = RetroPostcard(
          data: testData,
          showStamp: false,
        );
        await tester.pumpWidget(wrapWithApp(template, frame: 100));

        expect(find.byType(RetroPostcard), findsOneWidget);
      });

      testWidgets('renders without texture', (tester) async {
        const template = RetroPostcard(
          data: testData,
          showTexture: false,
        );
        await tester.pumpWidget(wrapWithApp(template, frame: 60));

        expect(find.byType(RetroPostcard), findsOneWidget);
      });

      testWidgets('renders with custom border color', (tester) async {
        const template = RetroPostcard(
          data: testData,
          borderColor: Colors.orange,
        );
        await tester.pumpWidget(wrapWithApp(template));

        expect(find.byType(RetroPostcard), findsOneWidget);
      });

      testWidgets('renders with different seed', (tester) async {
        const template = RetroPostcard(
          data: testData,
          seed: 999,
        );
        await tester.pumpWidget(wrapWithApp(template));

        expect(find.byType(RetroPostcard), findsOneWidget);
      });
    });

    group('toScene', () {
      test('creates scene with correct duration', () {
        const template = RetroPostcard(data: testData);
        final scene = template.toScene();

        expect(scene.durationInFrames, 180);
      });

      test('creates scene with custom duration', () {
        const template = RetroPostcard(data: testData);
        final scene = template.toScene(durationInFrames: 240);

        expect(scene.durationInFrames, 240);
      });

      test('creates scene with transitions', () {
        const template = RetroPostcard(data: testData);
        final scene = template.toSceneWithCrossFade();

        expect(scene.transitionIn, isNotNull);
        expect(scene.transitionOut, isNotNull);
      });
    });

    group('animation frames', () {
      testWidgets('renders correctly at frame 0', (tester) async {
        const template = RetroPostcard(data: testData);
        await tester.pumpWidget(wrapWithApp(template, frame: 0));

        expect(find.byType(RetroPostcard), findsOneWidget);
      });

      testWidgets('renders correctly during entry animation', (tester) async {
        const template = RetroPostcard(data: testData);
        await tester.pumpWidget(wrapWithApp(template, frame: 35));

        expect(find.byType(RetroPostcard), findsOneWidget);
      });

      testWidgets('renders correctly during header animation', (tester) async {
        const template = RetroPostcard(data: testData);
        await tester.pumpWidget(wrapWithApp(template, frame: 60));

        expect(find.byType(RetroPostcard), findsOneWidget);
      });

      testWidgets('renders correctly during location text animation', (tester) async {
        const template = RetroPostcard(data: testData);
        await tester.pumpWidget(wrapWithApp(template, frame: 90));

        expect(find.byType(RetroPostcard), findsOneWidget);
      });

      testWidgets('renders correctly during stamp animation', (tester) async {
        const template = RetroPostcard(data: testData);
        await tester.pumpWidget(wrapWithApp(template, frame: 100));

        expect(find.byType(RetroPostcard), findsOneWidget);
      });

      testWidgets('renders correctly at end frame', (tester) async {
        const template = RetroPostcard(data: testData);
        await tester.pumpWidget(wrapWithApp(template, frame: 180));

        expect(find.byType(RetroPostcard), findsOneWidget);
      });
    });

    group('theme variations', () {
      testWidgets('renders with pastel theme', (tester) async {
        final template = RetroPostcard(
          data: testData,
          theme: TemplateTheme.pastel,
        );
        await tester.pumpWidget(wrapWithApp(template));

        expect(find.byType(RetroPostcard), findsOneWidget);
      });

      testWidgets('renders with retro theme', (tester) async {
        final template = RetroPostcard(
          data: testData,
          theme: TemplateTheme.retro,
        );
        await tester.pumpWidget(wrapWithApp(template));

        expect(find.byType(RetroPostcard), findsOneWidget);
      });

      testWidgets('renders with minimal theme', (tester) async {
        final template = RetroPostcard(
          data: testData,
          theme: TemplateTheme.minimal,
        );
        await tester.pumpWidget(wrapWithApp(template));

        expect(find.byType(RetroPostcard), findsOneWidget);
      });
    });

    group('edge cases', () {
      testWidgets('handles data without title', (tester) async {
        const noTitleData = ThematicData(
          text: 'Location',
          subtitle: 'Location',
          description: 'Description',
        );
        const template = RetroPostcard(data: noTitleData);
        await tester.pumpWidget(wrapWithApp(template, frame: 60));

        expect(find.byType(RetroPostcard), findsOneWidget);
      });

      testWidgets('handles data without subtitle', (tester) async {
        const noSubtitleData = ThematicData(
          text: 'Greetings',
          title: 'GREETINGS FROM',
          description: 'Description',
        );
        const template = RetroPostcard(data: noSubtitleData);
        await tester.pumpWidget(wrapWithApp(template, frame: 90));

        expect(find.byType(RetroPostcard), findsOneWidget);
      });

      testWidgets('handles data without description', (tester) async {
        const noDescData = ThematicData(
          text: 'Paris',
          title: 'GREETINGS FROM',
          subtitle: 'Paris',
        );
        const template = RetroPostcard(data: noDescData);
        await tester.pumpWidget(wrapWithApp(template, frame: 120));

        expect(find.byType(RetroPostcard), findsOneWidget);
      });

      testWidgets('handles data without value', (tester) async {
        const noValueData = ThematicData(
          text: 'Tokyo',
          title: 'GREETINGS FROM',
          subtitle: 'Tokyo',
          description: 'Visited',
        );
        const template = RetroPostcard(data: noValueData);
        await tester.pumpWidget(wrapWithApp(template, frame: 90));

        expect(find.byType(RetroPostcard), findsOneWidget);
      });

      testWidgets('handles data without metadata', (tester) async {
        const noMetaData = ThematicData(
          text: 'London',
          title: 'GREETINGS FROM',
          subtitle: 'London',
        );
        const template = RetroPostcard(data: noMetaData);
        await tester.pumpWidget(wrapWithApp(template, frame: 100));

        expect(find.byType(RetroPostcard), findsOneWidget);
      });

      testWidgets('handles long location text', (tester) async {
        ignoreOverflowErrors();
        const longData = ThematicData(
          text: 'San Francisco',
          title: 'GREETINGS FROM',
          subtitle: 'San Francisco Bay Area, California',
          description: 'Your most played city with the longest name ever',
        );
        const template = RetroPostcard(data: longData);
        await tester.pumpWidget(wrapWithApp(template, frame: 120));

        expect(find.byType(RetroPostcard), findsOneWidget);
      });

      testWidgets('handles minimal data', (tester) async {
        const minimalData = ThematicData(text: 'Just text');
        const template = RetroPostcard(data: minimalData);
        await tester.pumpWidget(wrapWithApp(template));

        expect(find.byType(RetroPostcard), findsOneWidget);
      });
    });
  });
}
