import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/templates/ranking/floating_polaroids.dart';
import 'package:fluvie/src/templates/_base/template_base.dart';
import 'package:fluvie/src/templates/_base/template_config.dart';
import 'package:fluvie/src/templates/_base/template_data.dart';
import '../../helpers/test_helpers.dart';

void main() {
  group('FloatingPolaroids', () {
    final testData = RankingData(
      title: 'Your Year in Photos',
      items: [
        const RankingItem(
            rank: 1, label: 'Summer Trip', imagePath: 'assets/summer.jpg'),
        const RankingItem(
            rank: 2, label: 'Concert Night', imagePath: 'assets/concert.jpg'),
        const RankingItem(rank: 3, label: 'Beach Day'),
        const RankingItem(rank: 4, label: 'Mountain Hike'),
        const RankingItem(rank: 5, label: 'City Lights'),
      ],
    );

    group('construction', () {
      test('creates with required data', () {
        final template = FloatingPolaroids(data: testData);

        expect(template.data, testData);
        expect(template.rankingData, testData);
      });

      test('has default values', () {
        final template = FloatingPolaroids(data: testData);

        expect(template.floatAmplitude, 30);
        expect(template.rotationSpeed, 0.3);
        expect(template.showFlares, isTrue);
        expect(template.seed, 42);
      });

      test('accepts custom values', () {
        final template = FloatingPolaroids(
          data: testData,
          floatAmplitude: 50,
          rotationSpeed: 0.5,
          showFlares: false,
          seed: 123,
        );

        expect(template.floatAmplitude, 50);
        expect(template.rotationSpeed, 0.5);
        expect(template.showFlares, isFalse);
        expect(template.seed, 123);
      });

      test('accepts theme', () {
        final template = FloatingPolaroids(
          data: testData,
          theme: TemplateTheme.pastel,
        );

        expect(template.theme, isNotNull);
      });

      test('accepts timing', () {
        final template = FloatingPolaroids(
          data: testData,
          timing: TemplateTiming.slowReveal,
        );

        expect(template.timing, TemplateTiming.slowReveal);
      });
    });

    group('template properties', () {
      test('recommendedLength is 210 frames', () {
        final template = FloatingPolaroids(data: testData);
        expect(template.recommendedLength, 210);
      });

      test('category is ranking', () {
        final template = FloatingPolaroids(data: testData);
        expect(template.category, TemplateCategory.ranking);
      });

      test('description is set', () {
        final template = FloatingPolaroids(data: testData);
        expect(template.description, isNotEmpty);
        expect(template.description.toLowerCase(), contains('float'));
      });

      test('defaultTheme is pastel', () {
        final template = FloatingPolaroids(data: testData);
        expect(template.defaultTheme, TemplateTheme.pastel);
      });
    });

    group('rankingData getter', () {
      test('returns data cast to RankingData', () {
        final template = FloatingPolaroids(data: testData);
        expect(template.rankingData, testData);
        expect(template.rankingData.items.length, 5);
        expect(template.rankingData.topItem.label, 'Summer Trip');
      });
    });

    group('widget rendering', () {
      testWidgets('renders without error', (tester) async {
        final template = FloatingPolaroids(data: testData);
        await tester.pumpWidget(wrapWithApp(template));

        expect(find.byType(FloatingPolaroids), findsOneWidget);
      });

      testWidgets('displays title', (tester) async {
        final template = FloatingPolaroids(data: testData);
        await tester.pumpWidget(wrapWithApp(template, frame: 40));

        expect(find.text('Your Year in Photos'), findsWidgets);
      });

      testWidgets('displays item labels', (tester) async {
        final template = FloatingPolaroids(data: testData);
        await tester.pumpWidget(wrapWithApp(template, frame: 100));

        expect(find.text('Summer Trip'), findsWidgets);
      });

      testWidgets('displays rank badges', (tester) async {
        final template = FloatingPolaroids(data: testData);
        await tester.pumpWidget(wrapWithApp(template, frame: 100));

        expect(find.text('1'), findsWidgets);
      });

      testWidgets('renders without flares', (tester) async {
        final template = FloatingPolaroids(data: testData, showFlares: false);
        await tester.pumpWidget(wrapWithApp(template));

        expect(find.byType(FloatingPolaroids), findsOneWidget);
      });

      testWidgets('renders with default title when none provided',
          (tester) async {
        final noTitleData = RankingData(
          items: const [
            RankingItem(rank: 1, label: 'Photo 1'),
            RankingItem(rank: 2, label: 'Photo 2'),
          ],
        );
        final template = FloatingPolaroids(data: noTitleData);
        await tester.pumpWidget(wrapWithApp(template, frame: 40));

        expect(find.textContaining('Favorites'), findsWidgets);
      });
    });

    group('animation phases', () {
      testWidgets('renders correctly during entry phase', (tester) async {
        final template = FloatingPolaroids(data: testData);
        await tester.pumpWidget(wrapWithApp(template, frame: 40));

        expect(find.byType(FloatingPolaroids), findsOneWidget);
      });

      testWidgets('renders correctly during float phase', (tester) async {
        final template = FloatingPolaroids(data: testData);
        await tester.pumpWidget(wrapWithApp(template, frame: 100));

        expect(find.byType(FloatingPolaroids), findsOneWidget);
      });

      testWidgets('renders correctly during reveal phase', (tester) async {
        final template = FloatingPolaroids(data: testData);
        await tester.pumpWidget(wrapWithApp(template, frame: 170));

        expect(find.byType(FloatingPolaroids), findsOneWidget);
      });

      testWidgets('renders correctly at winner spotlight', (tester) async {
        final template = FloatingPolaroids(data: testData);
        await tester.pumpWidget(wrapWithApp(template, frame: 200));

        expect(find.byType(FloatingPolaroids), findsOneWidget);
      });
    });

    group('toScene', () {
      test('creates scene with correct duration', () {
        final template = FloatingPolaroids(data: testData);
        final scene = template.toScene();

        expect(scene.durationInFrames, 210);
      });

      test('creates scene with custom duration', () {
        final template = FloatingPolaroids(data: testData);
        final scene = template.toScene(durationInFrames: 300);

        expect(scene.durationInFrames, 300);
      });

      test('creates scene with transitions', () {
        final template = FloatingPolaroids(data: testData);
        final scene = template.toSceneWithCrossFade();

        expect(scene.transitionIn, isNotNull);
        expect(scene.transitionOut, isNotNull);
      });
    });

    group('float variations', () {
      testWidgets('renders with small float amplitude', (tester) async {
        final template = FloatingPolaroids(data: testData, floatAmplitude: 10);
        await tester.pumpWidget(wrapWithApp(template));

        expect(find.byType(FloatingPolaroids), findsOneWidget);
      });

      testWidgets('renders with large float amplitude', (tester) async {
        final template = FloatingPolaroids(data: testData, floatAmplitude: 80);
        await tester.pumpWidget(wrapWithApp(template));

        expect(find.byType(FloatingPolaroids), findsOneWidget);
      });

      testWidgets('renders with slow rotation', (tester) async {
        final template = FloatingPolaroids(data: testData, rotationSpeed: 0.1);
        await tester.pumpWidget(wrapWithApp(template));

        expect(find.byType(FloatingPolaroids), findsOneWidget);
      });

      testWidgets('renders with fast rotation', (tester) async {
        final template = FloatingPolaroids(data: testData, rotationSpeed: 1.0);
        await tester.pumpWidget(wrapWithApp(template));

        expect(find.byType(FloatingPolaroids), findsOneWidget);
      });
    });

    group('seed variations', () {
      testWidgets('different seeds produce different layouts', (tester) async {
        final template1 = FloatingPolaroids(data: testData, seed: 1);
        final template2 = FloatingPolaroids(data: testData, seed: 999);

        await tester.pumpWidget(wrapWithApp(template1));
        expect(find.byType(FloatingPolaroids), findsOneWidget);

        await tester.pumpWidget(wrapWithApp(template2));
        expect(find.byType(FloatingPolaroids), findsOneWidget);
      });

      testWidgets('same seed produces consistent layout', (tester) async {
        final template = FloatingPolaroids(data: testData, seed: 42);
        await tester.pumpWidget(wrapWithApp(template));

        expect(find.byType(FloatingPolaroids), findsOneWidget);
      });
    });

    group('theme variations', () {
      testWidgets('renders with pastel theme', (tester) async {
        final template = FloatingPolaroids(
          data: testData,
          theme: TemplateTheme.pastel,
        );
        await tester.pumpWidget(wrapWithApp(template));

        expect(find.byType(FloatingPolaroids), findsOneWidget);
      });

      testWidgets('renders with spotify theme', (tester) async {
        final template = FloatingPolaroids(
          data: testData,
          theme: TemplateTheme.spotify,
        );
        await tester.pumpWidget(wrapWithApp(template));

        expect(find.byType(FloatingPolaroids), findsOneWidget);
      });

      testWidgets('renders with minimal theme', (tester) async {
        final template = FloatingPolaroids(
          data: testData,
          theme: TemplateTheme.minimal,
        );
        await tester.pumpWidget(wrapWithApp(template));

        expect(find.byType(FloatingPolaroids), findsOneWidget);
      });
    });

    group('edge cases', () {
      testWidgets('handles single item', (tester) async {
        final singleData = RankingData(
          items: const [RankingItem(rank: 1, label: 'Only Photo')],
        );
        final template = FloatingPolaroids(data: singleData);
        await tester.pumpWidget(wrapWithApp(template));

        expect(find.byType(FloatingPolaroids), findsOneWidget);
      });

      testWidgets('handles many items (limited to 8)', (tester) async {
        final manyData = RankingData(
          items: List.generate(
            15,
            (i) => RankingItem(rank: i + 1, label: 'Photo ${i + 1}'),
          ),
        );
        final template = FloatingPolaroids(data: manyData);
        await tester.pumpWidget(wrapWithApp(template));

        expect(find.byType(FloatingPolaroids), findsOneWidget);
      });

      testWidgets('handles items without images', (tester) async {
        final noImageData = RankingData(
          items: const [
            RankingItem(rank: 1, label: 'No Image 1'),
            RankingItem(rank: 2, label: 'No Image 2'),
          ],
        );
        final template = FloatingPolaroids(data: noImageData);
        await tester.pumpWidget(wrapWithApp(template));

        expect(find.byType(FloatingPolaroids), findsOneWidget);
      });

      testWidgets('handles long labels', (tester) async {
        final longData = RankingData(
          items: const [
            RankingItem(
              rank: 1,
              label:
                  'This Is A Very Long Photo Caption That Might Need Truncation',
            ),
          ],
        );
        final template = FloatingPolaroids(data: longData);
        await tester.pumpWidget(wrapWithApp(template));

        expect(find.byType(FloatingPolaroids), findsOneWidget);
      });
    });
  });
}
