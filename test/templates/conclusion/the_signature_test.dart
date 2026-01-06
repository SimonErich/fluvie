import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/templates/conclusion/the_signature.dart';
import 'package:fluvie/src/templates/_base/template_base.dart';
import 'package:fluvie/src/templates/_base/template_config.dart';
import 'package:fluvie/src/templates/_base/template_data.dart';
import '../../helpers/test_helpers.dart';

void main() {
  group('TheSignature', () {
    final testData = SummaryData(
      title: 'Thank You',
      name: 'John Doe',
      subtitle: 'See you next year!',
      year: 2024,
      stats: {'Hours': '1,234'},
    );

    group('construction', () {
      test('creates with required data', () {
        final template = TheSignature(data: testData);

        expect(template.data, testData);
        expect(template.summaryData, testData);
      });

      test('has default values', () {
        final template = TheSignature(data: testData);

        expect(template.strokeWidth, 4.0);
        expect(template.showPen, isTrue);
        expect(template.signatureColor, isNull);
      });

      test('accepts custom values', () {
        final template = TheSignature(
          data: testData,
          strokeWidth: 6.0,
          showPen: false,
          signatureColor: Colors.blue,
        );

        expect(template.strokeWidth, 6.0);
        expect(template.showPen, isFalse);
        expect(template.signatureColor, Colors.blue);
      });

      test('accepts theme', () {
        final template = TheSignature(
          data: testData,
          theme: TemplateTheme.minimal,
        );

        expect(template.theme, isNotNull);
      });

      test('accepts timing', () {
        final template = TheSignature(
          data: testData,
          timing: TemplateTiming.smooth,
        );

        expect(template.timing, TemplateTiming.smooth);
      });
    });

    group('template properties', () {
      test('recommendedLength is 200 frames', () {
        final template = TheSignature(data: testData);
        expect(template.recommendedLength, 200);
      });

      test('category is conclusion', () {
        final template = TheSignature(data: testData);
        expect(template.category, TemplateCategory.conclusion);
      });

      test('description is set', () {
        final template = TheSignature(data: testData);
        expect(template.description, isNotEmpty);
        expect(template.description, contains('handwritten'));
      });

      test('defaultTheme is minimal', () {
        final template = TheSignature(data: testData);
        expect(template.defaultTheme, TemplateTheme.minimal);
      });
    });

    group('summaryData getter', () {
      test('returns data cast to SummaryData', () {
        final template = TheSignature(data: testData);
        expect(template.summaryData, testData);
        expect(template.summaryData.name, 'John Doe');
        expect(template.summaryData.title, 'Thank You');
      });
    });

    group('widget rendering', () {
      testWidgets('renders without error', (tester) async {
        final template = TheSignature(data: testData);
        await tester.pumpWidget(wrapWithApp(template));

        expect(find.byType(TheSignature), findsOneWidget);
      });

      testWidgets('displays title', (tester) async {
        final template = TheSignature(data: testData);
        await tester.pumpWidget(wrapWithApp(template, frame: 40));

        expect(find.text('Thank You'), findsWidgets);
      });

      testWidgets('renders without pen', (tester) async {
        final template = TheSignature(
          data: testData,
          showPen: false,
        );
        await tester.pumpWidget(wrapWithApp(template, frame: 100));

        expect(find.byType(TheSignature), findsOneWidget);
      });

      testWidgets('renders with custom stroke width', (tester) async {
        final template = TheSignature(
          data: testData,
          strokeWidth: 8.0,
        );
        await tester.pumpWidget(wrapWithApp(template, frame: 100));

        expect(find.byType(TheSignature), findsOneWidget);
      });

      testWidgets('renders with custom signature color', (tester) async {
        final template = TheSignature(
          data: testData,
          signatureColor: Colors.purple,
        );
        await tester.pumpWidget(wrapWithApp(template, frame: 100));

        expect(find.byType(TheSignature), findsOneWidget);
      });
    });

    group('toScene', () {
      test('creates scene with correct duration', () {
        final template = TheSignature(data: testData);
        final scene = template.toScene();

        expect(scene.durationInFrames, 200);
      });

      test('creates scene with custom duration', () {
        final template = TheSignature(data: testData);
        final scene = template.toScene(durationInFrames: 250);

        expect(scene.durationInFrames, 250);
      });

      test('creates scene with transitions', () {
        final template = TheSignature(data: testData);
        final scene = template.toSceneWithCrossFade();

        expect(scene.transitionIn, isNotNull);
        expect(scene.transitionOut, isNotNull);
      });
    });

    group('animation frames', () {
      testWidgets('renders correctly at frame 0', (tester) async {
        final template = TheSignature(data: testData);
        await tester.pumpWidget(wrapWithApp(template, frame: 0));

        expect(find.byType(TheSignature), findsOneWidget);
      });

      testWidgets('renders correctly during thank you entry', (tester) async {
        final template = TheSignature(data: testData);
        await tester.pumpWidget(wrapWithApp(template, frame: 35));

        expect(find.byType(TheSignature), findsOneWidget);
      });

      testWidgets('renders correctly at signature start', (tester) async {
        final template = TheSignature(data: testData);
        await tester.pumpWidget(wrapWithApp(template, frame: 65));

        expect(find.byType(TheSignature), findsOneWidget);
      });

      testWidgets('renders correctly during signature drawing', (tester) async {
        final template = TheSignature(data: testData);
        await tester.pumpWidget(wrapWithApp(template, frame: 100));

        expect(find.byType(TheSignature), findsOneWidget);
      });

      testWidgets('renders correctly at signature end', (tester) async {
        final template = TheSignature(data: testData);
        await tester.pumpWidget(wrapWithApp(template, frame: 140));

        expect(find.byType(TheSignature), findsOneWidget);
      });

      testWidgets('renders correctly during ending entry', (tester) async {
        final template = TheSignature(data: testData);
        await tester.pumpWidget(wrapWithApp(template, frame: 170));

        expect(find.byType(TheSignature), findsOneWidget);
      });

      testWidgets('renders correctly at end frame', (tester) async {
        final template = TheSignature(data: testData);
        await tester.pumpWidget(wrapWithApp(template, frame: 200));

        expect(find.byType(TheSignature), findsOneWidget);
      });
    });

    group('theme variations', () {
      testWidgets('renders with minimal theme', (tester) async {
        final template = TheSignature(
          data: testData,
          theme: TemplateTheme.minimal,
        );
        await tester.pumpWidget(wrapWithApp(template));

        expect(find.byType(TheSignature), findsOneWidget);
      });

      testWidgets('renders with spotify theme', (tester) async {
        final template = TheSignature(
          data: testData,
          theme: TemplateTheme.spotify,
        );
        await tester.pumpWidget(wrapWithApp(template));

        expect(find.byType(TheSignature), findsOneWidget);
      });

      testWidgets('renders with pastel theme', (tester) async {
        final template = TheSignature(
          data: testData,
          theme: TemplateTheme.pastel,
        );
        await tester.pumpWidget(wrapWithApp(template));

        expect(find.byType(TheSignature), findsOneWidget);
      });
    });

    group('edge cases', () {
      testWidgets('handles data without name', (tester) async {
        final noNameData = SummaryData(
          title: 'Thank You',
          subtitle: 'Goodbye!',
          year: 2024,
          stats: {},
        );
        final template = TheSignature(data: noNameData);
        await tester.pumpWidget(wrapWithApp(template, frame: 100));

        expect(find.byType(TheSignature), findsOneWidget);
      });

      testWidgets('handles data without title', (tester) async {
        final noTitleData = SummaryData(
          name: 'John',
          subtitle: 'Goodbye!',
          year: 2024,
          stats: {},
        );
        final template = TheSignature(data: noTitleData);
        await tester.pumpWidget(wrapWithApp(template, frame: 40));

        expect(find.byType(TheSignature), findsOneWidget);
      });

      testWidgets('handles data without subtitle', (tester) async {
        final noSubtitleData = SummaryData(
          title: 'Thanks',
          name: 'User',
          year: 2024,
          stats: {},
        );
        final template = TheSignature(data: noSubtitleData);
        await tester.pumpWidget(wrapWithApp(template, frame: 170));

        expect(find.byType(TheSignature), findsOneWidget);
      });

      testWidgets('handles data without year', (tester) async {
        final noYearData = SummaryData(
          title: 'Thanks',
          name: 'User',
          stats: {},
        );
        final template = TheSignature(data: noYearData);
        await tester.pumpWidget(wrapWithApp(template, frame: 190));

        expect(find.byType(TheSignature), findsOneWidget);
      });

      testWidgets('handles long name', (tester) async {
        final longNameData = SummaryData(
          title: 'Thank You',
          name: 'Dr. Alexander Bartholomew Fitzgerald III',
          stats: {},
        );
        final template = TheSignature(data: longNameData);
        await tester.pumpWidget(wrapWithApp(template, frame: 100));

        expect(find.byType(TheSignature), findsOneWidget);
      });

      testWidgets('handles short name', (tester) async {
        final shortNameData = SummaryData(
          title: 'Thanks',
          name: 'Jo',
          stats: {},
        );
        final template = TheSignature(data: shortNameData);
        await tester.pumpWidget(wrapWithApp(template, frame: 100));

        expect(find.byType(TheSignature), findsOneWidget);
      });

      testWidgets('handles minimal data', (tester) async {
        final minimalData = SummaryData(stats: {});
        final template = TheSignature(data: minimalData);
        await tester.pumpWidget(wrapWithApp(template));

        expect(find.byType(TheSignature), findsOneWidget);
      });

      testWidgets('handles thin stroke width', (tester) async {
        final template = TheSignature(
          data: testData,
          strokeWidth: 1.0,
        );
        await tester.pumpWidget(wrapWithApp(template, frame: 100));

        expect(find.byType(TheSignature), findsOneWidget);
      });

      testWidgets('handles thick stroke width', (tester) async {
        final template = TheSignature(
          data: testData,
          strokeWidth: 12.0,
        );
        await tester.pumpWidget(wrapWithApp(template, frame: 100));

        expect(find.byType(TheSignature), findsOneWidget);
      });
    });
  });
}
