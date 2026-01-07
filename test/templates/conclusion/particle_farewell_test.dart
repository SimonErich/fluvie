import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/templates/conclusion/particle_farewell.dart';
import 'package:fluvie/src/templates/_base/template_base.dart';
import 'package:fluvie/src/templates/_base/template_config.dart';
import 'package:fluvie/src/templates/_base/template_data.dart';
import '../../helpers/test_helpers.dart';

void main() {
  group('ParticleFarewell', () {
    const testData = SummaryData(
      title: 'Thank You',
      name: 'John',
      message: 'Until next time',
      year: 2024,
      stats: {'Hours': '1,234', 'Songs': '5,678'},
    );

    group('construction', () {
      test('creates with required data', () {
        const template = ParticleFarewell(data: testData);

        expect(template.data, testData);
        expect(template.summaryData, testData);
      });

      test('has default values', () {
        const template = ParticleFarewell(data: testData);

        expect(template.particleCount, 200);
        expect(template.explosionDuration, 60);
      });

      test('accepts custom values', () {
        const template = ParticleFarewell(
          data: testData,
          particleCount: 500,
          explosionDuration: 90,
        );

        expect(template.particleCount, 500);
        expect(template.explosionDuration, 90);
      });

      test('accepts theme', () {
        const template = ParticleFarewell(
          data: testData,
          theme: TemplateTheme.midnight,
        );

        expect(template.theme, isNotNull);
      });

      test('accepts timing', () {
        const template = ParticleFarewell(
          data: testData,
          timing: TemplateTiming.dramatic,
        );

        expect(template.timing, TemplateTiming.dramatic);
      });
    });

    group('template properties', () {
      test('recommendedLength is 150 frames', () {
        const template = ParticleFarewell(data: testData);
        expect(template.recommendedLength, 150);
      });

      test('category is conclusion', () {
        const template = ParticleFarewell(data: testData);
        expect(template.category, TemplateCategory.conclusion);
      });

      test('description is set', () {
        const template = ParticleFarewell(data: testData);
        expect(template.description, isNotEmpty);
        expect(template.description, contains('particle'));
      });

      test('defaultTheme is midnight', () {
        const template = ParticleFarewell(data: testData);
        expect(template.defaultTheme, TemplateTheme.midnight);
      });
    });

    group('summaryData getter', () {
      test('returns data cast to SummaryData', () {
        const template = ParticleFarewell(data: testData);
        expect(template.summaryData, testData);
        expect(template.summaryData.message, 'Until next time');
        expect(template.summaryData.year, 2024);
      });
    });

    group('widget rendering', () {
      testWidgets('renders without error', (tester) async {
        const template = ParticleFarewell(data: testData);
        await tester.pumpWidget(wrapWithApp(template));

        expect(find.byType(ParticleFarewell), findsOneWidget);
      });

      testWidgets('displays message', (tester) async {
        const template = ParticleFarewell(data: testData);
        await tester.pumpWidget(wrapWithApp(template, frame: 40));

        expect(find.text('Until next time'), findsWidgets);
      });

      testWidgets('displays year', (tester) async {
        const template = ParticleFarewell(data: testData);
        await tester.pumpWidget(wrapWithApp(template, frame: 60));

        expect(find.text('2024'), findsWidgets);
      });

      testWidgets('renders with many particles', (tester) async {
        const template = ParticleFarewell(
          data: testData,
          particleCount: 1000,
        );
        await tester.pumpWidget(wrapWithApp(template, frame: 90));

        expect(find.byType(ParticleFarewell), findsOneWidget);
      });

      testWidgets('renders with few particles', (tester) async {
        const template = ParticleFarewell(
          data: testData,
          particleCount: 50,
        );
        await tester.pumpWidget(wrapWithApp(template, frame: 90));

        expect(find.byType(ParticleFarewell), findsOneWidget);
      });

      testWidgets('renders with short explosion duration', (tester) async {
        const template = ParticleFarewell(
          data: testData,
          explosionDuration: 30,
        );
        await tester.pumpWidget(wrapWithApp(template, frame: 100));

        expect(find.byType(ParticleFarewell), findsOneWidget);
      });
    });

    group('toScene', () {
      test('creates scene with correct duration', () {
        const template = ParticleFarewell(data: testData);
        final scene = template.toScene();

        expect(scene.durationInFrames, 150);
      });

      test('creates scene with custom duration', () {
        const template = ParticleFarewell(data: testData);
        final scene = template.toScene(durationInFrames: 200);

        expect(scene.durationInFrames, 200);
      });

      test('creates scene with transitions', () {
        const template = ParticleFarewell(data: testData);
        final scene = template.toSceneWithCrossFade();

        expect(scene.transitionIn, isNotNull);
        expect(scene.transitionOut, isNotNull);
      });
    });

    group('animation frames', () {
      testWidgets('renders correctly at frame 0', (tester) async {
        const template = ParticleFarewell(data: testData);
        await tester.pumpWidget(wrapWithApp(template, frame: 0));

        expect(find.byType(ParticleFarewell), findsOneWidget);
      });

      testWidgets('renders correctly during message entry', (tester) async {
        const template = ParticleFarewell(data: testData);
        await tester.pumpWidget(wrapWithApp(template, frame: 30));

        expect(find.byType(ParticleFarewell), findsOneWidget);
      });

      testWidgets('renders correctly during year entry', (tester) async {
        const template = ParticleFarewell(data: testData);
        await tester.pumpWidget(wrapWithApp(template, frame: 55));

        expect(find.byType(ParticleFarewell), findsOneWidget);
      });

      testWidgets('renders correctly before explosion', (tester) async {
        const template = ParticleFarewell(data: testData);
        await tester.pumpWidget(wrapWithApp(template, frame: 75));

        expect(find.byType(ParticleFarewell), findsOneWidget);
      });

      testWidgets('renders correctly during explosion start', (tester) async {
        const template = ParticleFarewell(data: testData);
        await tester.pumpWidget(wrapWithApp(template, frame: 85));

        expect(find.byType(ParticleFarewell), findsOneWidget);
      });

      testWidgets('renders correctly during explosion', (tester) async {
        const template = ParticleFarewell(data: testData);
        await tester.pumpWidget(wrapWithApp(template, frame: 110));

        expect(find.byType(ParticleFarewell), findsOneWidget);
      });

      testWidgets('renders correctly at end frame', (tester) async {
        const template = ParticleFarewell(data: testData);
        await tester.pumpWidget(wrapWithApp(template, frame: 150));

        expect(find.byType(ParticleFarewell), findsOneWidget);
      });
    });

    group('theme variations', () {
      testWidgets('renders with midnight theme', (tester) async {
        const template = ParticleFarewell(
          data: testData,
          theme: TemplateTheme.midnight,
        );
        await tester.pumpWidget(wrapWithApp(template));

        expect(find.byType(ParticleFarewell), findsOneWidget);
      });

      testWidgets('renders with neon theme', (tester) async {
        const template = ParticleFarewell(
          data: testData,
          theme: TemplateTheme.neon,
        );
        await tester.pumpWidget(wrapWithApp(template));

        expect(find.byType(ParticleFarewell), findsOneWidget);
      });

      testWidgets('renders with spotify theme', (tester) async {
        const template = ParticleFarewell(
          data: testData,
          theme: TemplateTheme.spotify,
        );
        await tester.pumpWidget(wrapWithApp(template));

        expect(find.byType(ParticleFarewell), findsOneWidget);
      });
    });

    group('edge cases', () {
      testWidgets('handles data without message', (tester) async {
        const noMessageData = SummaryData(
          title: 'Thanks',
          name: 'User',
          year: 2024,
          stats: {'Hours': '100'},
        );
        const template = ParticleFarewell(data: noMessageData);
        await tester.pumpWidget(wrapWithApp(template, frame: 40));

        expect(find.byType(ParticleFarewell), findsOneWidget);
      });

      testWidgets('handles data without year', (tester) async {
        const noYearData = SummaryData(
          title: 'Thanks',
          name: 'User',
          message: 'See you!',
          stats: {'Hours': '100'},
        );
        const template = ParticleFarewell(data: noYearData);
        await tester.pumpWidget(wrapWithApp(template, frame: 55));

        expect(find.byType(ParticleFarewell), findsOneWidget);
      });

      testWidgets('handles minimal data', (tester) async {
        const minimalData = SummaryData(
          stats: {'Key': 'Value'},
        );
        const template = ParticleFarewell(data: minimalData);
        await tester.pumpWidget(wrapWithApp(template));

        expect(find.byType(ParticleFarewell), findsOneWidget);
      });

      testWidgets('handles empty stats', (tester) async {
        const emptyStatsData = SummaryData(
          title: 'Thanks',
          name: 'User',
          stats: {},
        );
        const template = ParticleFarewell(data: emptyStatsData);
        await tester.pumpWidget(wrapWithApp(template));

        expect(find.byType(ParticleFarewell), findsOneWidget);
      });

      testWidgets('handles long message', (tester) async {
        const longMessageData = SummaryData(
          title: 'Thanks',
          message:
              'This is a very long farewell message that might wrap to multiple lines',
          year: 2024,
          stats: {},
        );
        const template = ParticleFarewell(data: longMessageData);
        await tester.pumpWidget(wrapWithApp(template, frame: 40));

        expect(find.byType(ParticleFarewell), findsOneWidget);
      });

      testWidgets('handles zero particles', (tester) async {
        const template = ParticleFarewell(
          data: testData,
          particleCount: 0,
        );
        await tester.pumpWidget(wrapWithApp(template, frame: 110));

        expect(find.byType(ParticleFarewell), findsOneWidget);
      });
    });
  });
}
