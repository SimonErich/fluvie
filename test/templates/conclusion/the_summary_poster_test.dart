import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/templates/conclusion/the_summary_poster.dart';
import 'package:fluvie/src/templates/_base/template_base.dart';
import 'package:fluvie/src/templates/_base/template_config.dart';
import 'package:fluvie/src/templates/_base/template_data.dart';
import '../../helpers/test_helpers.dart';

void main() {
  group('TheSummaryPoster', () {
    const testData = SummaryData(
      title: 'Your 2024 Wrapped',
      name: 'John Doe',
      subtitle: 'A year of music',
      year: 2024,
      stats: {
        'Hours': '1,234',
        'Songs': '5,678',
        'Artists': '456',
        'Genres': '23'
      },
    );

    group('construction', () {
      test('creates with required data', () {
        const template = TheSummaryPoster(data: testData);

        expect(template.data, testData);
        expect(template.summaryData, testData);
      });

      test('has default values', () {
        const template = TheSummaryPoster(data: testData);

        expect(template.showQR, isTrue);
        expect(template.showDecorations, isTrue);
        expect(template.layout, PosterLayout.centered);
      });

      test('accepts custom values', () {
        const template = TheSummaryPoster(
          data: testData,
          showQR: false,
          showDecorations: false,
          layout: PosterLayout.leftAligned,
        );

        expect(template.showQR, isFalse);
        expect(template.showDecorations, isFalse);
        expect(template.layout, PosterLayout.leftAligned);
      });

      test('accepts theme', () {
        const template = TheSummaryPoster(
          data: testData,
          theme: TemplateTheme.spotify,
        );

        expect(template.theme, isNotNull);
      });

      test('accepts timing', () {
        const template = TheSummaryPoster(
          data: testData,
          timing: TemplateTiming.elastic,
        );

        expect(template.timing, TemplateTiming.elastic);
      });
    });

    group('template properties', () {
      test('recommendedLength is 180 frames', () {
        const template = TheSummaryPoster(data: testData);
        expect(template.recommendedLength, 180);
      });

      test('category is conclusion', () {
        const template = TheSummaryPoster(data: testData);
        expect(template.category, TemplateCategory.conclusion);
      });

      test('description is set', () {
        const template = TheSummaryPoster(data: testData);
        expect(template.description, isNotEmpty);
        expect(template.description, contains('poster'));
      });

      test('defaultTheme is spotify', () {
        const template = TheSummaryPoster(data: testData);
        expect(template.defaultTheme, TemplateTheme.spotify);
      });
    });

    group('summaryData getter', () {
      test('returns data cast to SummaryData', () {
        const template = TheSummaryPoster(data: testData);
        expect(template.summaryData, testData);
        expect(template.summaryData.stats.length, 4);
        expect(template.summaryData.title, 'Your 2024 Wrapped');
      });
    });

    group('widget rendering', () {
      testWidgets('renders without error', (tester) async {
        const template = TheSummaryPoster(data: testData);
        await tester.pumpWidget(wrapWithApp(template));

        expect(find.byType(TheSummaryPoster), findsOneWidget);
      });

      testWidgets('displays title', (tester) async {
        const template = TheSummaryPoster(data: testData);
        await tester.pumpWidget(wrapWithApp(template, frame: 30));

        expect(find.text('Your 2024 Wrapped'), findsWidgets);
      });

      testWidgets('renders without QR', (tester) async {
        const template = TheSummaryPoster(
          data: testData,
          showQR: false,
        );
        await tester.pumpWidget(wrapWithApp(template, frame: 150));

        expect(find.byType(TheSummaryPoster), findsOneWidget);
      });

      testWidgets('renders without decorations', (tester) async {
        const template = TheSummaryPoster(
          data: testData,
          showDecorations: false,
        );
        await tester.pumpWidget(wrapWithApp(template));

        expect(find.byType(TheSummaryPoster), findsOneWidget);
      });
    });

    group('layout variations', () {
      testWidgets('renders with centered layout', (tester) async {
        const template = TheSummaryPoster(
          data: testData,
          layout: PosterLayout.centered,
        );
        await tester.pumpWidget(wrapWithApp(template));

        expect(find.byType(TheSummaryPoster), findsOneWidget);
      });

      testWidgets('renders with left aligned layout', (tester) async {
        const template = TheSummaryPoster(
          data: testData,
          layout: PosterLayout.leftAligned,
        );
        await tester.pumpWidget(wrapWithApp(template));

        expect(find.byType(TheSummaryPoster), findsOneWidget);
      });

      testWidgets('renders with grid layout', (tester) async {
        const template = TheSummaryPoster(
          data: testData,
          layout: PosterLayout.grid,
        );
        await tester.pumpWidget(wrapWithApp(template));

        expect(find.byType(TheSummaryPoster), findsOneWidget);
      });
    });

    group('toScene', () {
      test('creates scene with correct duration', () {
        const template = TheSummaryPoster(data: testData);
        final scene = template.toScene();

        expect(scene.durationInFrames, 180);
      });

      test('creates scene with custom duration', () {
        const template = TheSummaryPoster(data: testData);
        final scene = template.toScene(durationInFrames: 240);

        expect(scene.durationInFrames, 240);
      });

      test('creates scene with transitions', () {
        const template = TheSummaryPoster(data: testData);
        final scene = template.toSceneWithCrossFade();

        expect(scene.transitionIn, isNotNull);
        expect(scene.transitionOut, isNotNull);
      });
    });

    group('animation frames', () {
      testWidgets('renders correctly at frame 0', (tester) async {
        const template = TheSummaryPoster(data: testData);
        await tester.pumpWidget(wrapWithApp(template, frame: 0));

        expect(find.byType(TheSummaryPoster), findsOneWidget);
      });

      testWidgets('renders correctly during header entry', (tester) async {
        const template = TheSummaryPoster(data: testData);
        await tester.pumpWidget(wrapWithApp(template, frame: 25));

        expect(find.byType(TheSummaryPoster), findsOneWidget);
      });

      testWidgets('renders correctly during name entry', (tester) async {
        const template = TheSummaryPoster(data: testData);
        await tester.pumpWidget(wrapWithApp(template, frame: 45));

        expect(find.byType(TheSummaryPoster), findsOneWidget);
      });

      testWidgets('renders correctly during stats entry', (tester) async {
        const template = TheSummaryPoster(data: testData);
        await tester.pumpWidget(wrapWithApp(template, frame: 70));

        expect(find.byType(TheSummaryPoster), findsOneWidget);
      });

      testWidgets('renders correctly at mid frame', (tester) async {
        const template = TheSummaryPoster(data: testData);
        await tester.pumpWidget(wrapWithApp(template, frame: 90));

        expect(find.byType(TheSummaryPoster), findsOneWidget);
      });

      testWidgets('renders correctly during footer entry', (tester) async {
        const template = TheSummaryPoster(data: testData);
        await tester.pumpWidget(wrapWithApp(template, frame: 150));

        expect(find.byType(TheSummaryPoster), findsOneWidget);
      });

      testWidgets('renders correctly at end frame', (tester) async {
        const template = TheSummaryPoster(data: testData);
        await tester.pumpWidget(wrapWithApp(template, frame: 180));

        expect(find.byType(TheSummaryPoster), findsOneWidget);
      });
    });

    group('theme variations', () {
      testWidgets('renders with spotify theme', (tester) async {
        const template = TheSummaryPoster(
          data: testData,
          theme: TemplateTheme.spotify,
        );
        await tester.pumpWidget(wrapWithApp(template));

        expect(find.byType(TheSummaryPoster), findsOneWidget);
      });

      testWidgets('renders with neon theme', (tester) async {
        const template = TheSummaryPoster(
          data: testData,
          theme: TemplateTheme.neon,
        );
        await tester.pumpWidget(wrapWithApp(template));

        expect(find.byType(TheSummaryPoster), findsOneWidget);
      });

      testWidgets('renders with minimal theme', (tester) async {
        const template = TheSummaryPoster(
          data: testData,
          theme: TemplateTheme.minimal,
        );
        await tester.pumpWidget(wrapWithApp(template));

        expect(find.byType(TheSummaryPoster), findsOneWidget);
      });
    });

    group('edge cases', () {
      testWidgets('handles data without title', (tester) async {
        const noTitleData = SummaryData(
          name: 'User',
          year: 2024,
          stats: {'Hours': '100'},
        );
        const template = TheSummaryPoster(data: noTitleData);
        await tester.pumpWidget(wrapWithApp(template, frame: 25));

        expect(find.byType(TheSummaryPoster), findsOneWidget);
      });

      testWidgets('handles data without name', (tester) async {
        const noNameData = SummaryData(
          title: 'Wrapped',
          year: 2024,
          stats: {'Hours': '100'},
        );
        const template = TheSummaryPoster(data: noNameData);
        await tester.pumpWidget(wrapWithApp(template, frame: 45));

        expect(find.byType(TheSummaryPoster), findsOneWidget);
      });

      testWidgets('handles empty stats', (tester) async {
        const emptyStatsData = SummaryData(
          title: 'Wrapped',
          name: 'User',
          stats: {},
        );
        const template = TheSummaryPoster(data: emptyStatsData);
        await tester.pumpWidget(wrapWithApp(template));

        expect(find.byType(TheSummaryPoster), findsOneWidget);
      });

      testWidgets('handles single stat', (tester) async {
        const singleStatData = SummaryData(
          title: 'Wrapped',
          name: 'User',
          stats: {'Hours': '1,234'},
        );
        const template = TheSummaryPoster(data: singleStatData);
        await tester.pumpWidget(wrapWithApp(template));

        expect(find.byType(TheSummaryPoster), findsOneWidget);
      });

      testWidgets('handles many stats', (tester) async {
        const manyStatsData = SummaryData(
          title: 'Wrapped',
          stats: {
            'Hours': '1,234',
            'Songs': '5,678',
            'Artists': '456',
            'Genres': '23',
            'Albums': '234',
            'Playlists': '45',
          },
        );
        const template = TheSummaryPoster(data: manyStatsData);
        await tester.pumpWidget(wrapWithApp(template));

        expect(find.byType(TheSummaryPoster), findsOneWidget);
      });

      testWidgets('handles data without subtitle', (tester) async {
        const noSubtitleData = SummaryData(
          title: 'Wrapped',
          name: 'User',
          year: 2024,
          stats: {'Hours': '100'},
        );
        const template = TheSummaryPoster(data: noSubtitleData);
        await tester.pumpWidget(wrapWithApp(template, frame: 160));

        expect(find.byType(TheSummaryPoster), findsOneWidget);
      });

      testWidgets('handles minimal data', (tester) async {
        const minimalData = SummaryData(stats: {});
        const template = TheSummaryPoster(data: minimalData);
        await tester.pumpWidget(wrapWithApp(template));

        expect(find.byType(TheSummaryPoster), findsOneWidget);
      });
    });
  });

  group('PosterLayout', () {
    test('has all expected layouts', () {
      expect(PosterLayout.values, hasLength(3));
      expect(PosterLayout.values, contains(PosterLayout.centered));
      expect(PosterLayout.values, contains(PosterLayout.leftAligned));
      expect(PosterLayout.values, contains(PosterLayout.grid));
    });
  });
}
