import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/templates/ranking/perspective_ladder.dart';
import 'package:fluvie/src/templates/_base/template_base.dart';
import 'package:fluvie/src/templates/_base/template_config.dart';
import 'package:fluvie/src/templates/_base/template_data.dart';
import '../../helpers/test_helpers.dart';

void main() {
  group('PerspectiveLadder', () {
    final testData = RankingData(
      title: 'Top Genres',
      items: [
        const RankingItem(
            rank: 1, label: 'Pop', value: '45%', subtitle: 'Genre'),
        const RankingItem(rank: 2, label: 'Hip-Hop', value: '28%'),
        const RankingItem(rank: 3, label: 'Rock', value: '15%'),
        const RankingItem(rank: 4, label: 'EDM', value: '8%'),
        const RankingItem(rank: 5, label: 'Jazz', value: '4%'),
      ],
    );

    group('construction', () {
      test('creates with required data', () {
        final template = PerspectiveLadder(data: testData);

        expect(template.data, testData);
        expect(template.rankingData, testData);
      });

      test('has default values', () {
        final template = PerspectiveLadder(data: testData);

        expect(template.perspectiveDepth, 0.004);
        expect(template.rungSpacing, 100);
        expect(template.showGlowTrails, isTrue);
        expect(template.staggerDelay, 12);
      });

      test('accepts custom values', () {
        final template = PerspectiveLadder(
          data: testData,
          perspectiveDepth: 0.008,
          rungSpacing: 120,
          showGlowTrails: false,
          staggerDelay: 20,
        );

        expect(template.perspectiveDepth, 0.008);
        expect(template.rungSpacing, 120);
        expect(template.showGlowTrails, isFalse);
        expect(template.staggerDelay, 20);
      });

      test('accepts theme', () {
        final template = PerspectiveLadder(
          data: testData,
          theme: TemplateTheme.midnight,
        );

        expect(template.theme, isNotNull);
      });

      test('accepts timing', () {
        final template = PerspectiveLadder(
          data: testData,
          timing: TemplateTiming.slowReveal,
        );

        expect(template.timing, TemplateTiming.slowReveal);
      });
    });

    group('template properties', () {
      test('recommendedLength is 180 frames', () {
        final template = PerspectiveLadder(data: testData);
        expect(template.recommendedLength, 180);
      });

      test('category is ranking', () {
        final template = PerspectiveLadder(data: testData);
        expect(template.category, TemplateCategory.ranking);
      });

      test('description is set', () {
        final template = PerspectiveLadder(data: testData);
        expect(template.description, isNotEmpty);
        expect(template.description, contains('perspective'));
      });

      test('defaultTheme is midnight', () {
        final template = PerspectiveLadder(data: testData);
        expect(template.defaultTheme, TemplateTheme.midnight);
      });
    });

    group('rankingData getter', () {
      test('returns data cast to RankingData', () {
        final template = PerspectiveLadder(data: testData);
        expect(template.rankingData, testData);
        expect(template.rankingData.items.length, 5);
        expect(template.rankingData.topItem.label, 'Pop');
      });
    });

    group('widget rendering', () {
      testWidgets('renders without error', (tester) async {
        final template = PerspectiveLadder(data: testData);
        await tester.pumpWidget(wrapWithApp(template));

        expect(find.byType(PerspectiveLadder), findsOneWidget);
      });

      testWidgets('displays title', (tester) async {
        final template = PerspectiveLadder(data: testData);
        await tester.pumpWidget(wrapWithApp(template, frame: 50));

        expect(find.text('Top Genres'), findsWidgets);
      });

      testWidgets('displays item labels', (tester) async {
        final template = PerspectiveLadder(data: testData);
        await tester.pumpWidget(wrapWithApp(template, frame: 120));

        expect(find.text('Pop'), findsWidgets);
      });

      testWidgets('displays item values', (tester) async {
        final template = PerspectiveLadder(data: testData);
        await tester.pumpWidget(wrapWithApp(template, frame: 120));

        expect(find.text('45%'), findsWidgets);
      });

      testWidgets('displays rank numbers', (tester) async {
        final template = PerspectiveLadder(data: testData);
        await tester.pumpWidget(wrapWithApp(template, frame: 100));

        expect(find.text('1'), findsWidgets);
      });

      testWidgets('renders without glow trails', (tester) async {
        final template = PerspectiveLadder(
          data: testData,
          showGlowTrails: false,
        );
        await tester.pumpWidget(wrapWithApp(template));

        expect(find.byType(PerspectiveLadder), findsOneWidget);
      });

      testWidgets('renders with default title when none provided',
          (tester) async {
        final noTitleData = RankingData(
          items: const [
            RankingItem(rank: 1, label: 'First'),
            RankingItem(rank: 2, label: 'Second'),
          ],
        );
        final template = PerspectiveLadder(data: noTitleData);
        await tester.pumpWidget(wrapWithApp(template, frame: 30));

        expect(find.textContaining('Rankings'), findsWidgets);
      });
    });

    group('toScene', () {
      test('creates scene with correct duration', () {
        final template = PerspectiveLadder(data: testData);
        final scene = template.toScene();

        expect(scene.durationInFrames, 180);
      });

      test('creates scene with custom duration', () {
        final template = PerspectiveLadder(data: testData);
        final scene = template.toScene(durationInFrames: 240);

        expect(scene.durationInFrames, 240);
      });

      test('creates scene with transitions', () {
        final template = PerspectiveLadder(data: testData);
        final scene = template.toSceneWithCrossFade();

        expect(scene.transitionIn, isNotNull);
        expect(scene.transitionOut, isNotNull);
      });
    });

    group('animation frames', () {
      testWidgets('renders correctly at frame 0', (tester) async {
        final template = PerspectiveLadder(data: testData);
        await tester.pumpWidget(wrapWithApp(template, frame: 0));

        expect(find.byType(PerspectiveLadder), findsOneWidget);
      });

      testWidgets('renders correctly during stagger animation', (tester) async {
        final template = PerspectiveLadder(data: testData);
        await tester.pumpWidget(wrapWithApp(template, frame: 60));

        expect(find.byType(PerspectiveLadder), findsOneWidget);
      });

      testWidgets('renders correctly at end frame', (tester) async {
        final template = PerspectiveLadder(data: testData);
        await tester.pumpWidget(wrapWithApp(template, frame: 180));

        expect(find.byType(PerspectiveLadder), findsOneWidget);
      });
    });

    group('perspective variations', () {
      testWidgets('renders with low perspective depth', (tester) async {
        final template = PerspectiveLadder(
          data: testData,
          perspectiveDepth: 0.001,
        );
        await tester.pumpWidget(wrapWithApp(template));

        expect(find.byType(PerspectiveLadder), findsOneWidget);
      });

      testWidgets('renders with high perspective depth', (tester) async {
        final template = PerspectiveLadder(
          data: testData,
          perspectiveDepth: 0.01,
        );
        await tester.pumpWidget(wrapWithApp(template));

        expect(find.byType(PerspectiveLadder), findsOneWidget);
      });

      testWidgets('renders with tight rung spacing', (tester) async {
        final template = PerspectiveLadder(
          data: testData,
          rungSpacing: 60,
        );
        await tester.pumpWidget(wrapWithApp(template));

        expect(find.byType(PerspectiveLadder), findsOneWidget);
      });

      testWidgets('renders with wide rung spacing', (tester) async {
        final template = PerspectiveLadder(
          data: testData,
          rungSpacing: 150,
        );
        await tester.pumpWidget(wrapWithApp(template));

        expect(find.byType(PerspectiveLadder), findsOneWidget);
      });
    });

    group('stagger variations', () {
      testWidgets('renders with short stagger delay', (tester) async {
        final template = PerspectiveLadder(data: testData, staggerDelay: 5);
        await tester.pumpWidget(wrapWithApp(template));

        expect(find.byType(PerspectiveLadder), findsOneWidget);
      });

      testWidgets('renders with long stagger delay', (tester) async {
        final template = PerspectiveLadder(data: testData, staggerDelay: 30);
        await tester.pumpWidget(wrapWithApp(template));

        expect(find.byType(PerspectiveLadder), findsOneWidget);
      });
    });

    group('theme variations', () {
      testWidgets('renders with midnight theme', (tester) async {
        final template = PerspectiveLadder(
          data: testData,
          theme: TemplateTheme.midnight,
        );
        await tester.pumpWidget(wrapWithApp(template));

        expect(find.byType(PerspectiveLadder), findsOneWidget);
      });

      testWidgets('renders with neon theme', (tester) async {
        final template = PerspectiveLadder(
          data: testData,
          theme: TemplateTheme.neon,
        );
        await tester.pumpWidget(wrapWithApp(template));

        expect(find.byType(PerspectiveLadder), findsOneWidget);
      });
    });

    group('edge cases', () {
      testWidgets('handles single item', (tester) async {
        final singleData = RankingData(
          items: const [RankingItem(rank: 1, label: 'Only One')],
        );
        final template = PerspectiveLadder(data: singleData);
        await tester.pumpWidget(wrapWithApp(template));

        expect(find.byType(PerspectiveLadder), findsOneWidget);
      });

      testWidgets('handles many items (limited to 10)', (tester) async {
        final manyData = RankingData(
          items: List.generate(
            15,
            (i) => RankingItem(rank: i + 1, label: 'Item ${i + 1}'),
          ),
        );
        final template = PerspectiveLadder(data: manyData);
        await tester.pumpWidget(wrapWithApp(template));

        expect(find.byType(PerspectiveLadder), findsOneWidget);
      });

      testWidgets('handles items with subtitles', (tester) async {
        final subtitleData = RankingData(
          items: const [
            RankingItem(rank: 1, label: 'First', subtitle: 'Subtitle here'),
            RankingItem(rank: 2, label: 'Second', subtitle: 'Another one'),
          ],
        );
        final template = PerspectiveLadder(data: subtitleData);
        await tester.pumpWidget(wrapWithApp(template, frame: 100));

        expect(find.byType(PerspectiveLadder), findsOneWidget);
      });

      testWidgets('handles long labels', (tester) async {
        final longData = RankingData(
          items: const [
            RankingItem(
              rank: 1,
              label: 'This Is A Very Long Genre Name That Might Overflow',
            ),
          ],
        );
        final template = PerspectiveLadder(data: longData);
        await tester.pumpWidget(wrapWithApp(template));

        expect(find.byType(PerspectiveLadder), findsOneWidget);
      });
    });
  });
}
