import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/templates/ranking/stack_climb.dart';
import 'package:fluvie/src/templates/_base/template_base.dart';
import 'package:fluvie/src/templates/_base/template_config.dart';
import 'package:fluvie/src/templates/_base/template_data.dart';
import '../../helpers/test_helpers.dart';

void main() {
  group('StackClimb', () {
    final testData = RankingData(
      title: 'Your Top Artists',
      items: [
        const RankingItem(rank: 1, label: 'Taylor Swift', imagePath: 'assets/taylor.jpg'),
        const RankingItem(rank: 2, label: 'Drake', imagePath: 'assets/drake.jpg'),
        const RankingItem(rank: 3, label: 'The Weeknd'),
        const RankingItem(rank: 4, label: 'Beyoncé'),
        const RankingItem(rank: 5, label: 'Bad Bunny'),
      ],
    );

    group('construction', () {
      test('creates with required data', () {
        final template = StackClimb(data: testData);

        expect(template.data, testData);
        expect(template.rankingData, testData);
      });

      test('has default values', () {
        final template = StackClimb(data: testData);

        expect(template.slideDirection, StackSlideDirection.left);
        expect(template.showConfetti, isTrue);
        expect(template.slideDelay, 25);
      });

      test('accepts custom values', () {
        final template = StackClimb(
          data: testData,
          slideDirection: StackSlideDirection.right,
          showConfetti: false,
          slideDelay: 30,
        );

        expect(template.slideDirection, StackSlideDirection.right);
        expect(template.showConfetti, isFalse);
        expect(template.slideDelay, 30);
      });

      test('accepts theme', () {
        final template = StackClimb(
          data: testData,
          theme: TemplateTheme.spotify,
        );

        expect(template.theme, isNotNull);
      });

      test('accepts timing', () {
        final template = StackClimb(
          data: testData,
          timing: TemplateTiming.dramatic,
        );

        expect(template.timing, TemplateTiming.dramatic);
      });
    });

    group('template properties', () {
      test('recommendedLength is 200 frames', () {
        final template = StackClimb(data: testData);
        expect(template.recommendedLength, 200);
      });

      test('category is ranking', () {
        final template = StackClimb(data: testData);
        expect(template.category, TemplateCategory.ranking);
      });

      test('description is set', () {
        final template = StackClimb(data: testData);
        expect(template.description, isNotEmpty);
        expect(template.description, contains('slide'));
      });

      test('defaultTheme is spotify', () {
        final template = StackClimb(data: testData);
        expect(template.defaultTheme, TemplateTheme.spotify);
      });
    });

    group('rankingData getter', () {
      test('returns data cast to RankingData', () {
        final template = StackClimb(data: testData);
        expect(template.rankingData, testData);
        expect(template.rankingData.items.length, 5);
        expect(template.rankingData.topItem.label, 'Taylor Swift');
      });
    });

    group('widget rendering', () {
      testWidgets('renders without error', (tester) async {
        final template = StackClimb(data: testData);
        await tester.pumpWidget(wrapWithApp(template));

        expect(find.byType(StackClimb), findsOneWidget);
      });

      testWidgets('displays title', (tester) async {
        final template = StackClimb(data: testData);
        await tester.pumpWidget(wrapWithApp(template, frame: 50));

        expect(find.text('Your Top Artists'), findsWidgets);
      });

      testWidgets('displays ranking items', (tester) async {
        final template = StackClimb(data: testData);
        await tester.pumpWidget(wrapWithApp(template, frame: 100));

        expect(find.text('Taylor Swift'), findsWidgets);
      });

      testWidgets('displays rank badges', (tester) async {
        final template = StackClimb(data: testData);
        await tester.pumpWidget(wrapWithApp(template, frame: 100));

        expect(find.text('#1'), findsWidgets);
      });

      testWidgets('renders with confetti disabled', (tester) async {
        final template = StackClimb(data: testData, showConfetti: false);
        await tester.pumpWidget(wrapWithApp(template));

        expect(find.byType(StackClimb), findsOneWidget);
      });

      testWidgets('renders with fewer items', (tester) async {
        final smallData = RankingData(
          title: 'Top 3',
          items: const [
            RankingItem(rank: 1, label: 'First'),
            RankingItem(rank: 2, label: 'Second'),
            RankingItem(rank: 3, label: 'Third'),
          ],
        );
        final template = StackClimb(data: smallData);
        await tester.pumpWidget(wrapWithApp(template));

        expect(find.byType(StackClimb), findsOneWidget);
      });
    });

    group('slide directions', () {
      testWidgets('renders with left slide', (tester) async {
        final template = StackClimb(
          data: testData,
          slideDirection: StackSlideDirection.left,
        );
        await tester.pumpWidget(wrapWithApp(template));

        expect(find.byType(StackClimb), findsOneWidget);
      });

      testWidgets('renders with right slide', (tester) async {
        final template = StackClimb(
          data: testData,
          slideDirection: StackSlideDirection.right,
        );
        await tester.pumpWidget(wrapWithApp(template));

        expect(find.byType(StackClimb), findsOneWidget);
      });

      testWidgets('renders with up slide', (tester) async {
        final template = StackClimb(
          data: testData,
          slideDirection: StackSlideDirection.up,
        );
        await tester.pumpWidget(wrapWithApp(template));

        expect(find.byType(StackClimb), findsOneWidget);
      });

      testWidgets('renders with down slide', (tester) async {
        final template = StackClimb(
          data: testData,
          slideDirection: StackSlideDirection.down,
        );
        await tester.pumpWidget(wrapWithApp(template));

        expect(find.byType(StackClimb), findsOneWidget);
      });
    });

    group('toScene', () {
      test('creates scene with correct duration', () {
        final template = StackClimb(data: testData);
        final scene = template.toScene();

        expect(scene.durationInFrames, 200);
      });

      test('creates scene with custom duration', () {
        final template = StackClimb(data: testData);
        final scene = template.toScene(durationInFrames: 250);

        expect(scene.durationInFrames, 250);
      });

      test('creates scene with transitions', () {
        final template = StackClimb(data: testData);
        final scene = template.toSceneWithCrossFade();

        expect(scene.transitionIn, isNotNull);
        expect(scene.transitionOut, isNotNull);
      });
    });

    group('animation frames', () {
      testWidgets('renders correctly at frame 0', (tester) async {
        final template = StackClimb(data: testData);
        await tester.pumpWidget(wrapWithApp(template, frame: 0));

        expect(find.byType(StackClimb), findsOneWidget);
      });

      testWidgets('renders correctly at mid frame', (tester) async {
        final template = StackClimb(data: testData);
        await tester.pumpWidget(wrapWithApp(template, frame: 100));

        expect(find.byType(StackClimb), findsOneWidget);
      });

      testWidgets('renders correctly at end frame', (tester) async {
        final template = StackClimb(data: testData);
        await tester.pumpWidget(wrapWithApp(template, frame: 200));

        expect(find.byType(StackClimb), findsOneWidget);
      });
    });

    group('theme variations', () {
      testWidgets('renders with spotify theme', (tester) async {
        final template = StackClimb(
          data: testData,
          theme: TemplateTheme.spotify,
        );
        await tester.pumpWidget(wrapWithApp(template));

        expect(find.byType(StackClimb), findsOneWidget);
      });

      testWidgets('renders with neon theme', (tester) async {
        final template = StackClimb(
          data: testData,
          theme: TemplateTheme.neon,
        );
        await tester.pumpWidget(wrapWithApp(template));

        expect(find.byType(StackClimb), findsOneWidget);
      });
    });

    group('edge cases', () {
      testWidgets('handles single item', (tester) async {
        final singleData = RankingData(
          items: const [RankingItem(rank: 1, label: 'Only One')],
        );
        final template = StackClimb(data: singleData);
        await tester.pumpWidget(wrapWithApp(template));

        expect(find.byType(StackClimb), findsOneWidget);
      });

      testWidgets('handles many items (limited to 5)', (tester) async {
        final manyData = RankingData(
          items: List.generate(
            10,
            (i) => RankingItem(rank: i + 1, label: 'Item ${i + 1}'),
          ),
        );
        final template = StackClimb(data: manyData);
        await tester.pumpWidget(wrapWithApp(template));

        expect(find.byType(StackClimb), findsOneWidget);
      });

      testWidgets('handles items with values', (tester) async {
        final valueData = RankingData(
          items: const [
            RankingItem(rank: 1, label: 'Artist 1', value: '1,234 plays'),
            RankingItem(rank: 2, label: 'Artist 2', value: '987 plays'),
          ],
        );
        final template = StackClimb(data: valueData);
        await tester.pumpWidget(wrapWithApp(template, frame: 100));

        expect(find.byType(StackClimb), findsOneWidget);
      });

      testWidgets('handles long labels', (tester) async {
        final longData = RankingData(
          items: const [
            RankingItem(
              rank: 1,
              label: 'This Is A Very Long Artist Name That Might Overflow',
            ),
          ],
        );
        final template = StackClimb(data: longData);
        await tester.pumpWidget(wrapWithApp(template));

        expect(find.byType(StackClimb), findsOneWidget);
      });
    });
  });

  group('StackSlideDirection', () {
    test('has all expected directions', () {
      expect(StackSlideDirection.values, hasLength(4));
      expect(StackSlideDirection.values, contains(StackSlideDirection.left));
      expect(StackSlideDirection.values, contains(StackSlideDirection.right));
      expect(StackSlideDirection.values, contains(StackSlideDirection.up));
      expect(StackSlideDirection.values, contains(StackSlideDirection.down));
    });
  });
}
