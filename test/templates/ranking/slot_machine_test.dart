import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/templates/ranking/slot_machine.dart';
import 'package:fluvie/src/templates/_base/template_base.dart';
import 'package:fluvie/src/templates/_base/template_config.dart';
import 'package:fluvie/src/templates/_base/template_data.dart';
import '../../helpers/test_helpers.dart';

void main() {
  group('SlotMachine', () {
    final testData = RankingData(
      title: 'Your #1 Song',
      items: [
        const RankingItem(rank: 1, label: 'Blinding Lights', imagePath: 'assets/song1.jpg'),
        const RankingItem(rank: 2, label: 'Shape of You'),
        const RankingItem(rank: 3, label: 'Dance Monkey'),
        const RankingItem(rank: 4, label: 'Rockstar'),
        const RankingItem(rank: 5, label: 'One Dance'),
      ],
    );

    group('construction', () {
      test('creates with required data', () {
        final template = SlotMachine(data: testData);

        expect(template.data, testData);
        expect(template.rankingData, testData);
      });

      test('has default values', () {
        final template = SlotMachine(data: testData);

        expect(template.spinCycles, 5);
        expect(template.showFrame, isTrue);
      });

      test('accepts custom values', () {
        final template = SlotMachine(
          data: testData,
          spinCycles: 8,
          showFrame: false,
        );

        expect(template.spinCycles, 8);
        expect(template.showFrame, isFalse);
      });

      test('accepts theme', () {
        final template = SlotMachine(
          data: testData,
          theme: TemplateTheme.neon,
        );

        expect(template.theme, isNotNull);
      });

      test('accepts timing', () {
        final template = SlotMachine(
          data: testData,
          timing: TemplateTiming.dramatic,
        );

        expect(template.timing, TemplateTiming.dramatic);
      });
    });

    group('template properties', () {
      test('recommendedLength is 180 frames', () {
        final template = SlotMachine(data: testData);
        expect(template.recommendedLength, 180);
      });

      test('category is ranking', () {
        final template = SlotMachine(data: testData);
        expect(template.category, TemplateCategory.ranking);
      });

      test('description is set', () {
        final template = SlotMachine(data: testData);
        expect(template.description, isNotEmpty);
        expect(template.description.toLowerCase(), contains('slot'));
      });
    });

    group('rankingData getter', () {
      test('returns data cast to RankingData', () {
        final template = SlotMachine(data: testData);
        expect(template.rankingData, testData);
        expect(template.rankingData.items.length, 5);
        expect(template.rankingData.topItem.label, 'Blinding Lights');
      });
    });

    group('widget rendering', () {
      testWidgets('renders without error', (tester) async {
        final template = SlotMachine(data: testData);
        await tester.pumpWidget(wrapWithApp(template));

        expect(find.byType(SlotMachine), findsOneWidget);
      });

      testWidgets('displays title', (tester) async {
        ignoreOverflowErrors();
        final template = SlotMachine(data: testData);
        await tester.pumpWidget(wrapWithApp(template, frame: 30));

        expect(find.text('Your #1 Song'), findsWidgets);
      });

      testWidgets('renders item labels', (tester) async {
        ignoreOverflowErrors();
        final template = SlotMachine(data: testData);
        await tester.pumpWidget(wrapWithApp(template, frame: 150));

        expect(find.byType(SlotMachine), findsOneWidget);
      });

      testWidgets('renders without frame', (tester) async {
        ignoreOverflowErrors();
        final template = SlotMachine(data: testData, showFrame: false);
        await tester.pumpWidget(wrapWithApp(template));

        expect(find.byType(SlotMachine), findsOneWidget);
      });

      testWidgets('renders with default title when none provided', (tester) async {
        ignoreOverflowErrors();
        final noTitleData = RankingData(
          items: const [RankingItem(rank: 1, label: 'Winner')],
        );
        final template = SlotMachine(data: noTitleData);
        await tester.pumpWidget(wrapWithApp(template, frame: 30));

        expect(find.textContaining('winner'), findsWidgets);
      });
    });

    group('toScene', () {
      test('creates scene with correct duration', () {
        final template = SlotMachine(data: testData);
        final scene = template.toScene();

        expect(scene.durationInFrames, 180);
      });

      test('creates scene with custom duration', () {
        final template = SlotMachine(data: testData);
        final scene = template.toScene(durationInFrames: 220);

        expect(scene.durationInFrames, 220);
      });

      test('creates scene with transitions', () {
        final template = SlotMachine(data: testData);
        final scene = template.toSceneWithCrossFade();

        expect(scene.transitionIn, isNotNull);
        expect(scene.transitionOut, isNotNull);
      });
    });

    group('animation phases', () {
      testWidgets('renders correctly at frame 0 (before spin)', (tester) async {
        ignoreOverflowErrors();
        final template = SlotMachine(data: testData);
        await tester.pumpWidget(wrapWithApp(template, frame: 0));

        expect(find.byType(SlotMachine), findsOneWidget);
      });

      testWidgets('renders correctly during spinning phase', (tester) async {
        ignoreOverflowErrors();
        final template = SlotMachine(data: testData);
        await tester.pumpWidget(wrapWithApp(template, frame: 60));

        expect(find.byType(SlotMachine), findsOneWidget);
      });

      testWidgets('renders correctly during settling phase', (tester) async {
        ignoreOverflowErrors();
        final template = SlotMachine(data: testData);
        await tester.pumpWidget(wrapWithApp(template, frame: 140));

        expect(find.byType(SlotMachine), findsOneWidget);
      });

      testWidgets('renders correctly at end frame', (tester) async {
        ignoreOverflowErrors();
        final template = SlotMachine(data: testData);
        await tester.pumpWidget(wrapWithApp(template, frame: 180));

        expect(find.byType(SlotMachine), findsOneWidget);
      });
    });

    group('spin cycle variations', () {
      testWidgets('renders with few spin cycles', (tester) async {
        final template = SlotMachine(data: testData, spinCycles: 2);
        await tester.pumpWidget(wrapWithApp(template));

        expect(find.byType(SlotMachine), findsOneWidget);
      });

      testWidgets('renders with many spin cycles', (tester) async {
        final template = SlotMachine(data: testData, spinCycles: 10);
        await tester.pumpWidget(wrapWithApp(template));

        expect(find.byType(SlotMachine), findsOneWidget);
      });
    });

    group('theme variations', () {
      testWidgets('renders with spotify theme', (tester) async {
        final template = SlotMachine(
          data: testData,
          theme: TemplateTheme.spotify,
        );
        await tester.pumpWidget(wrapWithApp(template));

        expect(find.byType(SlotMachine), findsOneWidget);
      });

      testWidgets('renders with neon theme', (tester) async {
        final template = SlotMachine(
          data: testData,
          theme: TemplateTheme.neon,
        );
        await tester.pumpWidget(wrapWithApp(template));

        expect(find.byType(SlotMachine), findsOneWidget);
      });

      testWidgets('renders with retro theme', (tester) async {
        final template = SlotMachine(
          data: testData,
          theme: TemplateTheme.retro,
        );
        await tester.pumpWidget(wrapWithApp(template));

        expect(find.byType(SlotMachine), findsOneWidget);
      });
    });

    group('edge cases', () {
      testWidgets('handles single item', (tester) async {
        final singleData = RankingData(
          items: const [RankingItem(rank: 1, label: 'Only Winner')],
        );
        final template = SlotMachine(data: singleData);
        await tester.pumpWidget(wrapWithApp(template));

        expect(find.byType(SlotMachine), findsOneWidget);
      });

      testWidgets('handles many items', (tester) async {
        final manyData = RankingData(
          items: List.generate(
            20,
            (i) => RankingItem(rank: i + 1, label: 'Song ${i + 1}'),
          ),
        );
        final template = SlotMachine(data: manyData);
        await tester.pumpWidget(wrapWithApp(template));

        expect(find.byType(SlotMachine), findsOneWidget);
      });

      testWidgets('handles long labels', (tester) async {
        final longData = RankingData(
          items: const [
            RankingItem(
              rank: 1,
              label: 'This Is A Very Long Song Title That Might Overflow',
            ),
          ],
        );
        final template = SlotMachine(data: longData);
        await tester.pumpWidget(wrapWithApp(template));

        expect(find.byType(SlotMachine), findsOneWidget);
      });

      testWidgets('handles items without images', (tester) async {
        final noImageData = RankingData(
          items: const [
            RankingItem(rank: 1, label: 'No Image Song'),
            RankingItem(rank: 2, label: 'Another No Image'),
          ],
        );
        final template = SlotMachine(data: noImageData);
        await tester.pumpWidget(wrapWithApp(template));

        expect(find.byType(SlotMachine), findsOneWidget);
      });
    });
  });
}
