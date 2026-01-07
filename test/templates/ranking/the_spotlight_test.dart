import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/templates/ranking/the_spotlight.dart';
import 'package:fluvie/src/templates/_base/template_base.dart';
import 'package:fluvie/src/templates/_base/template_config.dart';
import 'package:fluvie/src/templates/_base/template_data.dart';
import '../../helpers/test_helpers.dart';

void main() {
  group('TheSpotlight', () {
    final testData = RankingData(
      title: 'Your Top 5',
      items: [
        const RankingItem(
            rank: 1, label: 'First Place', imagePath: 'assets/1.jpg'),
        const RankingItem(rank: 2, label: 'Second Place'),
        const RankingItem(rank: 3, label: 'Third Place'),
        const RankingItem(rank: 4, label: 'Fourth Place'),
        const RankingItem(rank: 5, label: 'Fifth Place'),
      ],
    );

    group('construction', () {
      test('creates with required data', () {
        final template = TheSpotlight(data: testData);

        expect(template.data, testData);
        expect(template.rankingData, testData);
      });

      test('has default values', () {
        final template = TheSpotlight(data: testData);

        expect(template.framesPerItem, 25);
        expect(template.spotlightRadius, 150);
        expect(template.showLabels, isTrue);
      });

      test('accepts custom values', () {
        final template = TheSpotlight(
          data: testData,
          framesPerItem: 30,
          spotlightRadius: 200,
          showLabels: false,
        );

        expect(template.framesPerItem, 30);
        expect(template.spotlightRadius, 200);
        expect(template.showLabels, isFalse);
      });

      test('accepts theme', () {
        final template = TheSpotlight(
          data: testData,
          theme: TemplateTheme.neon,
        );

        expect(template.theme, isNotNull);
      });

      test('accepts timing', () {
        final template = TheSpotlight(
          data: testData,
          timing: TemplateTiming.dramatic,
        );

        expect(template.timing, TemplateTiming.dramatic);
      });
    });

    group('template properties', () {
      test('recommendedLength is calculated from framesPerItem', () {
        final template = TheSpotlight(data: testData, framesPerItem: 25);
        // 30 + (5 * 25) + 50 = 205
        expect(template.recommendedLength, 205);
      });

      test('recommendedLength scales with item count', () {
        final smallData = RankingData(
          items: const [
            RankingItem(rank: 1, label: 'First'),
            RankingItem(rank: 2, label: 'Second'),
          ],
        );
        final template = TheSpotlight(data: smallData, framesPerItem: 25);
        // 30 + (2 * 25) + 50 = 130
        expect(template.recommendedLength, 130);
      });

      test('category is ranking', () {
        final template = TheSpotlight(data: testData);
        expect(template.category, TemplateCategory.ranking);
      });

      test('description is set', () {
        final template = TheSpotlight(data: testData);
        expect(template.description, isNotEmpty);
        expect(template.description.toLowerCase(), contains('spotlight'));
      });
    });

    group('rankingData getter', () {
      test('returns data cast to RankingData', () {
        final template = TheSpotlight(data: testData);
        expect(template.rankingData, testData);
        expect(template.rankingData.items.length, 5);
        expect(template.rankingData.topItem.label, 'First Place');
      });
    });

    group('widget rendering', () {
      testWidgets('renders without error', (tester) async {
        final template = TheSpotlight(data: testData);
        await tester.pumpWidget(wrapWithApp(template));

        expect(find.byType(TheSpotlight), findsOneWidget);
      });

      testWidgets('displays title', (tester) async {
        final template = TheSpotlight(data: testData);
        await tester.pumpWidget(wrapWithApp(template, frame: 20));

        expect(find.text('Your Top 5'), findsWidgets);
      });

      testWidgets('displays rank badges', (tester) async {
        final template = TheSpotlight(data: testData);
        await tester.pumpWidget(wrapWithApp(template, frame: 100));

        expect(find.text('#1'), findsWidgets);
      });

      testWidgets('renders with labels disabled', (tester) async {
        final template = TheSpotlight(data: testData, showLabels: false);
        await tester.pumpWidget(wrapWithApp(template));

        expect(find.byType(TheSpotlight), findsOneWidget);
      });

      testWidgets('renders with default title when none provided',
          (tester) async {
        final noTitleData = RankingData(
          items: const [
            RankingItem(rank: 1, label: 'Winner'),
            RankingItem(rank: 2, label: 'Second'),
          ],
        );
        final template = TheSpotlight(data: noTitleData);
        await tester.pumpWidget(wrapWithApp(template, frame: 20));

        expect(find.textContaining('Top'), findsWidgets);
      });
    });

    group('toScene', () {
      test('creates scene with calculated duration', () {
        final template = TheSpotlight(data: testData);
        final scene = template.toScene();

        expect(scene.durationInFrames, 205);
      });

      test('creates scene with custom duration', () {
        final template = TheSpotlight(data: testData);
        final scene = template.toScene(durationInFrames: 300);

        expect(scene.durationInFrames, 300);
      });

      test('creates scene with transitions', () {
        final template = TheSpotlight(data: testData);
        final scene = template.toSceneWithCrossFade();

        expect(scene.transitionIn, isNotNull);
        expect(scene.transitionOut, isNotNull);
      });
    });

    group('animation phases', () {
      testWidgets('renders correctly before spotlight starts', (tester) async {
        final template = TheSpotlight(data: testData);
        await tester.pumpWidget(wrapWithApp(template, frame: 10));

        expect(find.byType(TheSpotlight), findsOneWidget);
      });

      testWidgets('renders correctly during spotlight movement',
          (tester) async {
        final template = TheSpotlight(data: testData);
        await tester.pumpWidget(wrapWithApp(template, frame: 80));

        expect(find.byType(TheSpotlight), findsOneWidget);
      });

      testWidgets('renders correctly at winner reveal', (tester) async {
        final template = TheSpotlight(data: testData);
        await tester.pumpWidget(wrapWithApp(template, frame: 180));

        expect(find.byType(TheSpotlight), findsOneWidget);
      });
    });

    group('spotlight variations', () {
      testWidgets('renders with small spotlight', (tester) async {
        final template = TheSpotlight(data: testData, spotlightRadius: 80);
        await tester.pumpWidget(wrapWithApp(template));

        expect(find.byType(TheSpotlight), findsOneWidget);
      });

      testWidgets('renders with large spotlight', (tester) async {
        final template = TheSpotlight(data: testData, spotlightRadius: 300);
        await tester.pumpWidget(wrapWithApp(template));

        expect(find.byType(TheSpotlight), findsOneWidget);
      });

      testWidgets('renders with fast transitions', (tester) async {
        final template = TheSpotlight(data: testData, framesPerItem: 10);
        await tester.pumpWidget(wrapWithApp(template));

        expect(find.byType(TheSpotlight), findsOneWidget);
      });

      testWidgets('renders with slow transitions', (tester) async {
        final template = TheSpotlight(data: testData, framesPerItem: 50);
        await tester.pumpWidget(wrapWithApp(template));

        expect(find.byType(TheSpotlight), findsOneWidget);
      });
    });

    group('theme variations', () {
      testWidgets('renders with spotify theme', (tester) async {
        final template = TheSpotlight(
          data: testData,
          theme: TemplateTheme.spotify,
        );
        await tester.pumpWidget(wrapWithApp(template));

        expect(find.byType(TheSpotlight), findsOneWidget);
      });

      testWidgets('renders with neon theme', (tester) async {
        final template = TheSpotlight(
          data: testData,
          theme: TemplateTheme.neon,
        );
        await tester.pumpWidget(wrapWithApp(template));

        expect(find.byType(TheSpotlight), findsOneWidget);
      });
    });

    group('edge cases', () {
      testWidgets('handles single item', (tester) async {
        final singleData = RankingData(
          items: const [RankingItem(rank: 1, label: 'Only One')],
        );
        final template = TheSpotlight(data: singleData);
        await tester.pumpWidget(wrapWithApp(template));

        expect(find.byType(TheSpotlight), findsOneWidget);
      });

      testWidgets('handles many items (limited to 5)', (tester) async {
        final manyData = RankingData(
          items: List.generate(
            10,
            (i) => RankingItem(rank: i + 1, label: 'Item ${i + 1}'),
          ),
        );
        final template = TheSpotlight(data: manyData);
        await tester.pumpWidget(wrapWithApp(template));

        expect(find.byType(TheSpotlight), findsOneWidget);
      });

      testWidgets('handles long labels', (tester) async {
        final longData = RankingData(
          items: const [
            RankingItem(
              rank: 1,
              label: 'This Is A Very Long Label That Might Overflow',
            ),
            RankingItem(rank: 2, label: 'Short'),
          ],
        );
        final template = TheSpotlight(data: longData);
        await tester.pumpWidget(wrapWithApp(template));

        expect(find.byType(TheSpotlight), findsOneWidget);
      });
    });
  });
}
