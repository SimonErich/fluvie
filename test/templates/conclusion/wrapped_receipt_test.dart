import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/templates/conclusion/wrapped_receipt.dart';
import 'package:fluvie/src/templates/_base/template_base.dart';
import 'package:fluvie/src/templates/_base/template_config.dart';
import 'package:fluvie/src/templates/_base/template_data.dart';
import '../../helpers/test_helpers.dart';

void main() {
  group('WrappedReceipt', () {
    final testData = SummaryData(
      title: 'YOUR WRAPPED RECEIPT',
      name: 'JOHN DOE',
      subtitle: 'SEE YOU NEXT YEAR',
      year: 2024,
      stats: {
        'Top Song': 'Midnight Rain',
        'Top Artist': 'Taylor Swift',
        'Hours Listened': '1,234',
        'Songs Played': '5,678',
      },
    );

    group('construction', () {
      test('creates with required data', () {
        final template = WrappedReceipt(data: testData);

        expect(template.data, testData);
        expect(template.summaryData, testData);
      });

      test('has default values', () {
        final template = WrappedReceipt(data: testData);

        expect(template.items, isNull);
        expect(template.showTexture, isTrue);
        expect(template.scrollSpeed, 1.0);
      });

      test('accepts custom values', () {
        final template = WrappedReceipt(
          data: testData,
          items: const [
            ReceiptItem(label: 'Item 1', value: '100'),
            ReceiptItem(label: 'Item 2', value: '200'),
          ],
          showTexture: false,
          scrollSpeed: 1.5,
        );

        expect(template.items, hasLength(2));
        expect(template.showTexture, isFalse);
        expect(template.scrollSpeed, 1.5);
      });

      test('accepts theme', () {
        final template = WrappedReceipt(
          data: testData,
          theme: TemplateTheme.minimal,
        );

        expect(template.theme, isNotNull);
      });

      test('accepts timing', () {
        final template = WrappedReceipt(
          data: testData,
          timing: TemplateTiming.smooth,
        );

        expect(template.timing, TemplateTiming.smooth);
      });
    });

    group('template properties', () {
      test('recommendedLength is 250 frames', () {
        final template = WrappedReceipt(data: testData);
        expect(template.recommendedLength, 250);
      });

      test('category is conclusion', () {
        final template = WrappedReceipt(data: testData);
        expect(template.category, TemplateCategory.conclusion);
      });

      test('description is set', () {
        final template = WrappedReceipt(data: testData);
        expect(template.description, isNotEmpty);
        expect(template.description, contains('receipt'));
      });

      test('defaultTheme is minimal', () {
        final template = WrappedReceipt(data: testData);
        expect(template.defaultTheme, TemplateTheme.minimal);
      });
    });

    group('summaryData getter', () {
      test('returns data cast to SummaryData', () {
        final template = WrappedReceipt(data: testData);
        expect(template.summaryData, testData);
        expect(template.summaryData.stats.length, 4);
        expect(template.summaryData.name, 'JOHN DOE');
      });
    });

    group('effectiveItems getter', () {
      test('uses provided items when available', () {
        final template = WrappedReceipt(
          data: testData,
          items: const [
            ReceiptItem(label: 'Custom', value: '999'),
          ],
        );
        expect(template.effectiveItems, hasLength(1));
        expect(template.effectiveItems.first.label, 'Custom');
      });

      test('generates items from stats when items not provided', () {
        final template = WrappedReceipt(data: testData);
        expect(template.effectiveItems, hasLength(4));
      });
    });

    group('widget rendering', () {
      testWidgets('renders without error', (tester) async {
        final template = WrappedReceipt(data: testData);
        await tester.pumpWidget(wrapWithApp(template));

        expect(find.byType(WrappedReceipt), findsOneWidget);
      });

      testWidgets('renders without texture', (tester) async {
        final template = WrappedReceipt(
          data: testData,
          showTexture: false,
        );
        await tester.pumpWidget(wrapWithApp(template, frame: 60));

        expect(find.byType(WrappedReceipt), findsOneWidget);
      });

      testWidgets('renders with custom items', (tester) async {
        final template = WrappedReceipt(
          data: testData,
          items: const [
            ReceiptItem(label: 'Song A', value: '100 plays'),
            ReceiptItem(label: 'Song B', value: '90 plays'),
            ReceiptItem(label: 'Song C', value: '80 plays'),
          ],
        );
        await tester.pumpWidget(wrapWithApp(template, frame: 100));

        expect(find.byType(WrappedReceipt), findsOneWidget);
      });

      testWidgets('renders with fast scroll speed', (tester) async {
        final template = WrappedReceipt(
          data: testData,
          scrollSpeed: 2.0,
        );
        await tester.pumpWidget(wrapWithApp(template));

        expect(find.byType(WrappedReceipt), findsOneWidget);
      });

      testWidgets('renders with slow scroll speed', (tester) async {
        final template = WrappedReceipt(
          data: testData,
          scrollSpeed: 0.5,
        );
        await tester.pumpWidget(wrapWithApp(template));

        expect(find.byType(WrappedReceipt), findsOneWidget);
      });
    });

    group('toScene', () {
      test('creates scene with correct duration', () {
        final template = WrappedReceipt(data: testData);
        final scene = template.toScene();

        expect(scene.durationInFrames, 250);
      });

      test('creates scene with custom duration', () {
        final template = WrappedReceipt(data: testData);
        final scene = template.toScene(durationInFrames: 300);

        expect(scene.durationInFrames, 300);
      });

      test('creates scene with transitions', () {
        final template = WrappedReceipt(data: testData);
        final scene = template.toSceneWithCrossFade();

        expect(scene.transitionIn, isNotNull);
        expect(scene.transitionOut, isNotNull);
      });
    });

    group('animation frames', () {
      testWidgets('renders correctly at frame 0', (tester) async {
        final template = WrappedReceipt(data: testData);
        await tester.pumpWidget(wrapWithApp(template, frame: 0));

        expect(find.byType(WrappedReceipt), findsOneWidget);
      });

      testWidgets('renders correctly during entry animation', (tester) async {
        final template = WrappedReceipt(data: testData);
        await tester.pumpWidget(wrapWithApp(template, frame: 35));

        expect(find.byType(WrappedReceipt), findsOneWidget);
      });

      testWidgets('renders correctly during header display', (tester) async {
        final template = WrappedReceipt(data: testData);
        await tester.pumpWidget(wrapWithApp(template, frame: 55));

        expect(find.byType(WrappedReceipt), findsOneWidget);
      });

      testWidgets('renders correctly during title display', (tester) async {
        final template = WrappedReceipt(data: testData);
        await tester.pumpWidget(wrapWithApp(template, frame: 75));

        expect(find.byType(WrappedReceipt), findsOneWidget);
      });

      testWidgets('renders correctly during items display', (tester) async {
        final template = WrappedReceipt(data: testData);
        await tester.pumpWidget(wrapWithApp(template, frame: 100));

        expect(find.byType(WrappedReceipt), findsOneWidget);
      });

      testWidgets('renders correctly during summary display', (tester) async {
        final template = WrappedReceipt(data: testData);
        await tester.pumpWidget(wrapWithApp(template, frame: 170));

        expect(find.byType(WrappedReceipt), findsOneWidget);
      });

      testWidgets('renders correctly during footer display', (tester) async {
        final template = WrappedReceipt(data: testData);
        await tester.pumpWidget(wrapWithApp(template, frame: 220));

        expect(find.byType(WrappedReceipt), findsOneWidget);
      });

      testWidgets('renders correctly at end frame', (tester) async {
        final template = WrappedReceipt(data: testData);
        await tester.pumpWidget(wrapWithApp(template, frame: 250));

        expect(find.byType(WrappedReceipt), findsOneWidget);
      });
    });

    group('theme variations', () {
      testWidgets('renders with minimal theme', (tester) async {
        final template = WrappedReceipt(
          data: testData,
          theme: TemplateTheme.minimal,
        );
        await tester.pumpWidget(wrapWithApp(template));

        expect(find.byType(WrappedReceipt), findsOneWidget);
      });

      testWidgets('renders with spotify theme', (tester) async {
        final template = WrappedReceipt(
          data: testData,
          theme: TemplateTheme.spotify,
        );
        await tester.pumpWidget(wrapWithApp(template));

        expect(find.byType(WrappedReceipt), findsOneWidget);
      });

      testWidgets('renders with pastel theme', (tester) async {
        final template = WrappedReceipt(
          data: testData,
          theme: TemplateTheme.pastel,
        );
        await tester.pumpWidget(wrapWithApp(template));

        expect(find.byType(WrappedReceipt), findsOneWidget);
      });
    });

    group('edge cases', () {
      testWidgets('handles data without title', (tester) async {
        final noTitleData = SummaryData(
          name: 'USER',
          year: 2024,
          stats: {'Hours': '100'},
        );
        final template = WrappedReceipt(data: noTitleData);
        await tester.pumpWidget(wrapWithApp(template, frame: 75));

        expect(find.byType(WrappedReceipt), findsOneWidget);
      });

      testWidgets('handles data without name', (tester) async {
        final noNameData = SummaryData(
          title: 'RECEIPT',
          year: 2024,
          stats: {'Hours': '100'},
        );
        final template = WrappedReceipt(data: noNameData);
        await tester.pumpWidget(wrapWithApp(template, frame: 55));

        expect(find.byType(WrappedReceipt), findsOneWidget);
      });

      testWidgets('handles data without subtitle', (tester) async {
        final noSubtitleData = SummaryData(
          title: 'RECEIPT',
          name: 'USER',
          year: 2024,
          stats: {'Hours': '100'},
        );
        final template = WrappedReceipt(data: noSubtitleData);
        await tester.pumpWidget(wrapWithApp(template, frame: 220));

        expect(find.byType(WrappedReceipt), findsOneWidget);
      });

      testWidgets('handles empty stats', (tester) async {
        final emptyStatsData = SummaryData(
          title: 'RECEIPT',
          name: 'USER',
          stats: {},
        );
        final template = WrappedReceipt(data: emptyStatsData);
        await tester.pumpWidget(wrapWithApp(template));

        expect(find.byType(WrappedReceipt), findsOneWidget);
      });

      testWidgets('handles empty items list', (tester) async {
        final template = WrappedReceipt(
          data: testData,
          items: const [],
        );
        await tester.pumpWidget(wrapWithApp(template));

        expect(find.byType(WrappedReceipt), findsOneWidget);
      });

      testWidgets('handles many items', (tester) async {
        final manyItemsData = SummaryData(
          title: 'RECEIPT',
          name: 'USER',
          stats: {
            'Song 1': '100',
            'Song 2': '90',
            'Song 3': '80',
            'Song 4': '70',
            'Song 5': '60',
            'Song 6': '50',
            'Song 7': '40',
            'Song 8': '30',
            'Song 9': '20',
            'Song 10': '10',
          },
        );
        final template = WrappedReceipt(data: manyItemsData);
        await tester.pumpWidget(wrapWithApp(template));

        expect(find.byType(WrappedReceipt), findsOneWidget);
      });

      testWidgets('handles minimal data', (tester) async {
        final minimalData = SummaryData(stats: {});
        final template = WrappedReceipt(data: minimalData);
        await tester.pumpWidget(wrapWithApp(template));

        expect(find.byType(WrappedReceipt), findsOneWidget);
      });

      testWidgets('handles item with subtitle', (tester) async {
        final template = WrappedReceipt(
          data: testData,
          items: const [
            ReceiptItem(label: 'Song', value: '100', subtitle: 'By Artist'),
          ],
        );
        await tester.pumpWidget(wrapWithApp(template, frame: 100));

        expect(find.byType(WrappedReceipt), findsOneWidget);
      });

      testWidgets('handles long item labels', (tester) async {
        final template = WrappedReceipt(
          data: testData,
          items: const [
            ReceiptItem(
              label:
                  'This is a very long song title that might need truncation',
              value: '100',
            ),
          ],
        );
        await tester.pumpWidget(wrapWithApp(template, frame: 100));

        expect(find.byType(WrappedReceipt), findsOneWidget);
      });
    });
  });

  group('ReceiptItem', () {
    test('creates with required parameters', () {
      const item = ReceiptItem(label: 'Test', value: '100');
      expect(item.label, 'Test');
      expect(item.value, '100');
      expect(item.subtitle, isNull);
    });

    test('creates with optional subtitle', () {
      const item = ReceiptItem(
        label: 'Test',
        value: '100',
        subtitle: 'Details',
      );
      expect(item.label, 'Test');
      expect(item.value, '100');
      expect(item.subtitle, 'Details');
    });
  });
}
