import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/templates/conclusion/the_infinity_loop.dart';
import 'package:fluvie/src/templates/_base/template_base.dart';
import 'package:fluvie/src/templates/_base/template_config.dart';
import 'package:fluvie/src/templates/_base/template_data.dart';
import '../../helpers/test_helpers.dart';

void main() {
  group('TheInfinityLoop', () {
    final testData = SummaryData(
      title: 'See You Next Year',
      subtitle: 'Play Again?',
      name: 'John',
      year: 2024,
      stats: {'Hours': '1,234'},
    );

    group('construction', () {
      test('creates with required data', () {
        final template = TheInfinityLoop(data: testData);

        expect(template.data, testData);
        expect(template.summaryData, testData);
      });

      test('has default values', () {
        final template = TheInfinityLoop(data: testData);

        expect(template.loopStyle, LoopStyle.zoom);
        expect(template.transitionColor, isNull);
        expect(template.showReplayIcon, isTrue);
      });

      test('accepts custom values', () {
        final template = TheInfinityLoop(
          data: testData,
          loopStyle: LoopStyle.spiral,
          transitionColor: Colors.black,
          showReplayIcon: false,
        );

        expect(template.loopStyle, LoopStyle.spiral);
        expect(template.transitionColor, Colors.black);
        expect(template.showReplayIcon, isFalse);
      });

      test('accepts theme', () {
        final template = TheInfinityLoop(
          data: testData,
          theme: TemplateTheme.spotify,
        );

        expect(template.theme, isNotNull);
      });

      test('accepts timing', () {
        final template = TheInfinityLoop(
          data: testData,
          timing: TemplateTiming.smooth,
        );

        expect(template.timing, TemplateTiming.smooth);
      });
    });

    group('template properties', () {
      test('recommendedLength is 180 frames', () {
        final template = TheInfinityLoop(data: testData);
        expect(template.recommendedLength, 180);
      });

      test('category is conclusion', () {
        final template = TheInfinityLoop(data: testData);
        expect(template.category, TemplateCategory.conclusion);
      });

      test('description is set', () {
        final template = TheInfinityLoop(data: testData);
        expect(template.description, isNotEmpty);
        expect(template.description, contains('loop'));
      });

      test('defaultTheme is spotify', () {
        final template = TheInfinityLoop(data: testData);
        expect(template.defaultTheme, TemplateTheme.spotify);
      });
    });

    group('summaryData getter', () {
      test('returns data cast to SummaryData', () {
        final template = TheInfinityLoop(data: testData);
        expect(template.summaryData, testData);
        expect(template.summaryData.title, 'See You Next Year');
        expect(template.summaryData.subtitle, 'Play Again?');
      });
    });

    group('widget rendering', () {
      testWidgets('renders without error', (tester) async {
        final template = TheInfinityLoop(data: testData);
        await tester.pumpWidget(wrapWithApp(template));

        expect(find.byType(TheInfinityLoop), findsOneWidget);
      });

      testWidgets('displays title', (tester) async {
        final template = TheInfinityLoop(data: testData);
        await tester.pumpWidget(wrapWithApp(template, frame: 50));

        expect(find.text('See You Next Year'), findsWidgets);
      });

      testWidgets('renders without replay icon', (tester) async {
        final template = TheInfinityLoop(
          data: testData,
          showReplayIcon: false,
        );
        await tester.pumpWidget(wrapWithApp(template, frame: 160));

        expect(find.byType(TheInfinityLoop), findsOneWidget);
      });

      testWidgets('renders with custom transition color', (tester) async {
        final template = TheInfinityLoop(
          data: testData,
          transitionColor: Colors.purple,
        );
        await tester.pumpWidget(wrapWithApp(template, frame: 140));

        expect(find.byType(TheInfinityLoop), findsOneWidget);
      });
    });

    group('loop styles', () {
      testWidgets('renders with zoom style', (tester) async {
        final template = TheInfinityLoop(
          data: testData,
          loopStyle: LoopStyle.zoom,
        );
        await tester.pumpWidget(wrapWithApp(template, frame: 140));

        expect(find.byType(TheInfinityLoop), findsOneWidget);
      });

      testWidgets('renders with fade style', (tester) async {
        final template = TheInfinityLoop(
          data: testData,
          loopStyle: LoopStyle.fade,
        );
        await tester.pumpWidget(wrapWithApp(template, frame: 140));

        expect(find.byType(TheInfinityLoop), findsOneWidget);
      });

      testWidgets('renders with spiral style', (tester) async {
        final template = TheInfinityLoop(
          data: testData,
          loopStyle: LoopStyle.spiral,
        );
        await tester.pumpWidget(wrapWithApp(template, frame: 140));

        expect(find.byType(TheInfinityLoop), findsOneWidget);
      });

      testWidgets('renders with wipe style', (tester) async {
        final template = TheInfinityLoop(
          data: testData,
          loopStyle: LoopStyle.wipe,
        );
        await tester.pumpWidget(wrapWithApp(template, frame: 140));

        expect(find.byType(TheInfinityLoop), findsOneWidget);
      });
    });

    group('toScene', () {
      test('creates scene with correct duration', () {
        final template = TheInfinityLoop(data: testData);
        final scene = template.toScene();

        expect(scene.durationInFrames, 180);
      });

      test('creates scene with custom duration', () {
        final template = TheInfinityLoop(data: testData);
        final scene = template.toScene(durationInFrames: 240);

        expect(scene.durationInFrames, 240);
      });

      test('creates scene with transitions', () {
        final template = TheInfinityLoop(data: testData);
        final scene = template.toSceneWithCrossFade();

        expect(scene.transitionIn, isNotNull);
        expect(scene.transitionOut, isNotNull);
      });
    });

    group('animation frames', () {
      testWidgets('renders correctly at frame 0', (tester) async {
        final template = TheInfinityLoop(data: testData);
        await tester.pumpWidget(wrapWithApp(template, frame: 0));

        expect(find.byType(TheInfinityLoop), findsOneWidget);
      });

      testWidgets('renders correctly during title entry', (tester) async {
        final template = TheInfinityLoop(data: testData);
        await tester.pumpWidget(wrapWithApp(template, frame: 40));

        expect(find.byType(TheInfinityLoop), findsOneWidget);
      });

      testWidgets('renders correctly during subtitle entry', (tester) async {
        final template = TheInfinityLoop(data: testData);
        await tester.pumpWidget(wrapWithApp(template, frame: 65));

        expect(find.byType(TheInfinityLoop), findsOneWidget);
      });

      testWidgets('renders correctly during content display', (tester) async {
        final template = TheInfinityLoop(data: testData);
        await tester.pumpWidget(wrapWithApp(template, frame: 100));

        expect(find.byType(TheInfinityLoop), findsOneWidget);
      });

      testWidgets('renders correctly during loop transition start', (tester) async {
        final template = TheInfinityLoop(data: testData);
        await tester.pumpWidget(wrapWithApp(template, frame: 125));

        expect(find.byType(TheInfinityLoop), findsOneWidget);
      });

      testWidgets('renders correctly during replay icon appearance', (tester) async {
        final template = TheInfinityLoop(data: testData);
        await tester.pumpWidget(wrapWithApp(template, frame: 160));

        expect(find.byType(TheInfinityLoop), findsOneWidget);
      });

      testWidgets('renders correctly at end frame', (tester) async {
        final template = TheInfinityLoop(data: testData);
        await tester.pumpWidget(wrapWithApp(template, frame: 180));

        expect(find.byType(TheInfinityLoop), findsOneWidget);
      });
    });

    group('theme variations', () {
      testWidgets('renders with spotify theme', (tester) async {
        final template = TheInfinityLoop(
          data: testData,
          theme: TemplateTheme.spotify,
        );
        await tester.pumpWidget(wrapWithApp(template));

        expect(find.byType(TheInfinityLoop), findsOneWidget);
      });

      testWidgets('renders with neon theme', (tester) async {
        final template = TheInfinityLoop(
          data: testData,
          theme: TemplateTheme.neon,
        );
        await tester.pumpWidget(wrapWithApp(template));

        expect(find.byType(TheInfinityLoop), findsOneWidget);
      });

      testWidgets('renders with midnight theme', (tester) async {
        final template = TheInfinityLoop(
          data: testData,
          theme: TemplateTheme.midnight,
        );
        await tester.pumpWidget(wrapWithApp(template));

        expect(find.byType(TheInfinityLoop), findsOneWidget);
      });
    });

    group('edge cases', () {
      testWidgets('handles data without title', (tester) async {
        final noTitleData = SummaryData(
          subtitle: 'Again?',
          name: 'User',
          year: 2024,
          stats: {},
        );
        final template = TheInfinityLoop(data: noTitleData);
        await tester.pumpWidget(wrapWithApp(template, frame: 40));

        expect(find.byType(TheInfinityLoop), findsOneWidget);
      });

      testWidgets('handles data without subtitle', (tester) async {
        final noSubtitleData = SummaryData(
          title: 'Goodbye',
          name: 'User',
          year: 2024,
          stats: {},
        );
        final template = TheInfinityLoop(data: noSubtitleData);
        await tester.pumpWidget(wrapWithApp(template, frame: 65));

        expect(find.byType(TheInfinityLoop), findsOneWidget);
      });

      testWidgets('handles data without name', (tester) async {
        final noNameData = SummaryData(
          title: 'Goodbye',
          subtitle: 'Again?',
          year: 2024,
          stats: {},
        );
        final template = TheInfinityLoop(data: noNameData);
        await tester.pumpWidget(wrapWithApp(template, frame: 90));

        expect(find.byType(TheInfinityLoop), findsOneWidget);
      });

      testWidgets('handles data without year', (tester) async {
        final noYearData = SummaryData(
          title: 'Goodbye',
          name: 'User',
          stats: {},
        );
        final template = TheInfinityLoop(data: noYearData);
        await tester.pumpWidget(wrapWithApp(template, frame: 90));

        expect(find.byType(TheInfinityLoop), findsOneWidget);
      });

      testWidgets('handles minimal data', (tester) async {
        final minimalData = SummaryData(stats: {});
        final template = TheInfinityLoop(data: minimalData);
        await tester.pumpWidget(wrapWithApp(template));

        expect(find.byType(TheInfinityLoop), findsOneWidget);
      });

      testWidgets('handles long text content', (tester) async {
        ignoreOverflowErrors();
        final longData = SummaryData(
          title: 'This Is A Very Long Farewell Title That Might Wrap',
          subtitle: 'Would You Like To Watch This Very Long Video Again?',
          name: 'Dr. Alexander Bartholomew Fitzgerald III',
          year: 2024,
          stats: {},
        );
        final template = TheInfinityLoop(data: longData);
        await tester.pumpWidget(wrapWithApp(template, frame: 90));

        expect(find.byType(TheInfinityLoop), findsOneWidget);
      });
    });
  });

  group('LoopStyle', () {
    test('has all expected styles', () {
      expect(LoopStyle.values, hasLength(4));
      expect(LoopStyle.values, contains(LoopStyle.zoom));
      expect(LoopStyle.values, contains(LoopStyle.fade));
      expect(LoopStyle.values, contains(LoopStyle.spiral));
      expect(LoopStyle.values, contains(LoopStyle.wipe));
    });
  });
}
