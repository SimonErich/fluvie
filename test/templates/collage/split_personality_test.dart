import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/templates/collage/split_personality.dart';
import 'package:fluvie/src/templates/_base/template_base.dart';
import 'package:fluvie/src/templates/_base/template_config.dart';
import 'package:fluvie/src/templates/_base/template_data.dart';
import '../../helpers/test_helpers.dart';

void main() {
  group('SplitPersonality', () {
    final testData = CollageData(
      title: 'Top Artist',
      subtitle: 'Taylor Swift',
      images: ['taylor.jpg'],
      description: '1,234 hours listened',
    );

    group('construction', () {
      test('creates with required data', () {
        final template = SplitPersonality(data: testData);

        expect(template.data, testData);
        expect(template.collageData, testData);
      });

      test('has default values', () {
        final template = SplitPersonality(data: testData);

        expect(template.splitAngle, 15);
        expect(template.imageOnLeft, isTrue);
        expect(template.textAnimation, TextAnimationStyle.typewriter);
      });

      test('accepts custom values', () {
        final template = SplitPersonality(
          data: testData,
          splitAngle: 30,
          imageOnLeft: false,
          textAnimation: TextAnimationStyle.wordByWord,
        );

        expect(template.splitAngle, 30);
        expect(template.imageOnLeft, isFalse);
        expect(template.textAnimation, TextAnimationStyle.wordByWord);
      });

      test('accepts theme', () {
        final template = SplitPersonality(
          data: testData,
          theme: TemplateTheme.midnight,
        );

        expect(template.theme, isNotNull);
      });

      test('accepts timing', () {
        final template = SplitPersonality(
          data: testData,
          timing: TemplateTiming.dramatic,
        );

        expect(template.timing, TemplateTiming.dramatic);
      });
    });

    group('template properties', () {
      test('recommendedLength is 180 frames', () {
        final template = SplitPersonality(data: testData);
        expect(template.recommendedLength, 180);
      });

      test('category is collage', () {
        final template = SplitPersonality(data: testData);
        expect(template.category, TemplateCategory.collage);
      });

      test('description is set', () {
        final template = SplitPersonality(data: testData);
        expect(template.description, isNotEmpty);
        expect(template.description, contains('split'));
      });

      test('defaultTheme is midnight', () {
        final template = SplitPersonality(data: testData);
        expect(template.defaultTheme, TemplateTheme.midnight);
      });
    });

    group('collageData getter', () {
      test('returns data cast to CollageData', () {
        final template = SplitPersonality(data: testData);
        expect(template.collageData, testData);
        expect(template.collageData.title, 'Top Artist');
        expect(template.collageData.subtitle, 'Taylor Swift');
      });
    });

    group('widget rendering', () {
      testWidgets('renders without error', (tester) async {
        final template = SplitPersonality(data: testData);
        await tester.pumpWidget(wrapWithApp(template));

        expect(find.byType(SplitPersonality), findsOneWidget);
      });

      testWidgets('displays title', (tester) async {
        final template = SplitPersonality(data: testData);
        await tester.pumpWidget(wrapWithApp(template, frame: 70));

        expect(find.text('Top Artist'), findsWidgets);
      });

      testWidgets('renders with image on right', (tester) async {
        final template = SplitPersonality(
          data: testData,
          imageOnLeft: false,
        );
        await tester.pumpWidget(wrapWithApp(template, frame: 50));

        expect(find.byType(SplitPersonality), findsOneWidget);
      });

      testWidgets('renders with zero split angle', (tester) async {
        final template = SplitPersonality(
          data: testData,
          splitAngle: 0,
        );
        await tester.pumpWidget(wrapWithApp(template));

        expect(find.byType(SplitPersonality), findsOneWidget);
      });
    });

    group('text animation styles', () {
      testWidgets('renders with typewriter animation', (tester) async {
        final template = SplitPersonality(
          data: testData,
          textAnimation: TextAnimationStyle.typewriter,
        );
        await tester.pumpWidget(wrapWithApp(template, frame: 80));

        expect(find.byType(SplitPersonality), findsOneWidget);
      });

      testWidgets('renders with word by word animation', (tester) async {
        final template = SplitPersonality(
          data: testData,
          textAnimation: TextAnimationStyle.wordByWord,
        );
        await tester.pumpWidget(wrapWithApp(template, frame: 80));

        expect(find.byType(SplitPersonality), findsOneWidget);
      });

      testWidgets('renders with fade in animation', (tester) async {
        final template = SplitPersonality(
          data: testData,
          textAnimation: TextAnimationStyle.fadeIn,
        );
        await tester.pumpWidget(wrapWithApp(template, frame: 80));

        expect(find.byType(SplitPersonality), findsOneWidget);
      });
    });

    group('toScene', () {
      test('creates scene with correct duration', () {
        final template = SplitPersonality(data: testData);
        final scene = template.toScene();

        expect(scene.durationInFrames, 180);
      });

      test('creates scene with custom duration', () {
        final template = SplitPersonality(data: testData);
        final scene = template.toScene(durationInFrames: 240);

        expect(scene.durationInFrames, 240);
      });

      test('creates scene with transitions', () {
        final template = SplitPersonality(data: testData);
        final scene = template.toSceneWithCrossFade();

        expect(scene.transitionIn, isNotNull);
        expect(scene.transitionOut, isNotNull);
      });
    });

    group('animation frames', () {
      testWidgets('renders correctly at frame 0', (tester) async {
        final template = SplitPersonality(data: testData);
        await tester.pumpWidget(wrapWithApp(template, frame: 0));

        expect(find.byType(SplitPersonality), findsOneWidget);
      });

      testWidgets('renders correctly at mid frame', (tester) async {
        final template = SplitPersonality(data: testData);
        await tester.pumpWidget(wrapWithApp(template, frame: 90));

        expect(find.byType(SplitPersonality), findsOneWidget);
      });

      testWidgets('renders correctly at end frame', (tester) async {
        final template = SplitPersonality(data: testData);
        await tester.pumpWidget(wrapWithApp(template, frame: 180));

        expect(find.byType(SplitPersonality), findsOneWidget);
      });
    });

    group('theme variations', () {
      testWidgets('renders with midnight theme', (tester) async {
        final template = SplitPersonality(
          data: testData,
          theme: TemplateTheme.midnight,
        );
        await tester.pumpWidget(wrapWithApp(template));

        expect(find.byType(SplitPersonality), findsOneWidget);
      });

      testWidgets('renders with neon theme', (tester) async {
        final template = SplitPersonality(
          data: testData,
          theme: TemplateTheme.neon,
        );
        await tester.pumpWidget(wrapWithApp(template));

        expect(find.byType(SplitPersonality), findsOneWidget);
      });

      testWidgets('renders with spotify theme', (tester) async {
        final template = SplitPersonality(
          data: testData,
          theme: TemplateTheme.spotify,
        );
        await tester.pumpWidget(wrapWithApp(template));

        expect(find.byType(SplitPersonality), findsOneWidget);
      });
    });

    group('edge cases', () {
      test('CollageData requires at least one image', () {
        expect(
          () => CollageData(title: 'Empty', images: []),
          throwsA(isA<AssertionError>()),
        );
      });

      testWidgets('handles data without subtitle', (tester) async {
        final noSubtitleData = CollageData(
          title: 'Artist',
          images: ['image.jpg'],
        );
        final template = SplitPersonality(data: noSubtitleData);
        await tester.pumpWidget(wrapWithApp(template, frame: 80));

        expect(find.byType(SplitPersonality), findsOneWidget);
      });

      testWidgets('handles data without description', (tester) async {
        final noDescData = CollageData(
          title: 'Artist',
          subtitle: 'Name',
          images: ['image.jpg'],
        );
        final template = SplitPersonality(data: noDescData);
        await tester.pumpWidget(wrapWithApp(template, frame: 120));

        expect(find.byType(SplitPersonality), findsOneWidget);
      });

      testWidgets('handles long subtitle (multi-word)', (tester) async {
        ignoreOverflowErrors();
        final longSubtitleData = CollageData(
          title: 'Artist',
          subtitle: 'This is a very long artist name that spans multiple words',
          images: ['image.jpg'],
        );
        final template = SplitPersonality(
          data: longSubtitleData,
          textAnimation: TextAnimationStyle.wordByWord,
        );
        await tester.pumpWidget(wrapWithApp(template, frame: 100));

        expect(find.byType(SplitPersonality), findsOneWidget);
      });

      testWidgets('handles large split angle', (tester) async {
        final template = SplitPersonality(
          data: testData,
          splitAngle: 45,
        );
        await tester.pumpWidget(wrapWithApp(template));

        expect(find.byType(SplitPersonality), findsOneWidget);
      });

      testWidgets('handles negative split angle', (tester) async {
        final template = SplitPersonality(
          data: testData,
          splitAngle: -15,
        );
        await tester.pumpWidget(wrapWithApp(template));

        expect(find.byType(SplitPersonality), findsOneWidget);
      });
    });
  });

  group('TextAnimationStyle', () {
    test('has all expected styles', () {
      expect(TextAnimationStyle.values, hasLength(3));
      expect(TextAnimationStyle.values, contains(TextAnimationStyle.typewriter));
      expect(TextAnimationStyle.values, contains(TextAnimationStyle.wordByWord));
      expect(TextAnimationStyle.values, contains(TextAnimationStyle.fadeIn));
    });
  });
}
