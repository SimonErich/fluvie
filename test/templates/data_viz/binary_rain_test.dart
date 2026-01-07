import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/templates/data_viz/binary_rain.dart';
import 'package:fluvie/src/templates/_base/template_base.dart';
import 'package:fluvie/src/templates/_base/template_config.dart';
import 'package:fluvie/src/templates/_base/template_data.dart';
import '../../helpers/test_helpers.dart';

void main() {
  group('BinaryRain', () {
    final testData = DataVizData(
      title: 'Your Songs',
      metrics: [
        const MetricData(label: 'Song 1', value: 100),
        const MetricData(label: 'Song 2', value: 80),
        const MetricData(label: 'Song 3', value: 60),
      ],
    );

    group('construction', () {
      test('creates with required data', () {
        final template = BinaryRain(data: testData);

        expect(template.data, testData);
        expect(template.dataVizData, testData);
      });

      test('has default values', () {
        final template = BinaryRain(data: testData);

        expect(template.columnCount, 20);
        expect(template.fallSpeed, 1.0);
        expect(template.items, isEmpty);
        expect(template.includeBinary, isTrue);
        expect(template.seed, 42);
      });

      test('accepts custom values', () {
        final template = BinaryRain(
          data: testData,
          columnCount: 30,
          fallSpeed: 1.5,
          items: const ['Item 1', 'Item 2'],
          includeBinary: false,
          seed: 123,
        );

        expect(template.columnCount, 30);
        expect(template.fallSpeed, 1.5);
        expect(template.items, ['Item 1', 'Item 2']);
        expect(template.includeBinary, isFalse);
        expect(template.seed, 123);
      });

      test('accepts theme', () {
        final template = BinaryRain(
          data: testData,
          theme: TemplateTheme.neon,
        );

        expect(template.theme, isNotNull);
      });

      test('accepts timing', () {
        final template = BinaryRain(
          data: testData,
          timing: TemplateTiming.dramatic,
        );

        expect(template.timing, TemplateTiming.dramatic);
      });
    });

    group('template properties', () {
      test('recommendedLength is 180 frames', () {
        final template = BinaryRain(data: testData);
        expect(template.recommendedLength, 180);
      });

      test('category is dataViz', () {
        final template = BinaryRain(data: testData);
        expect(template.category, TemplateCategory.dataViz);
      });

      test('description is set', () {
        final template = BinaryRain(data: testData);
        expect(template.description, isNotEmpty);
        expect(template.description, contains('Matrix'));
      });

      test('defaultTheme is neon', () {
        final template = BinaryRain(data: testData);
        expect(template.defaultTheme, TemplateTheme.neon);
      });
    });

    group('dataVizData getter', () {
      test('returns data cast to DataVizData', () {
        final template = BinaryRain(data: testData);
        expect(template.dataVizData, testData);
        expect(template.dataVizData.metrics.length, 3);
        expect(template.dataVizData.title, 'Your Songs');
      });
    });

    group('effectiveItems getter', () {
      test('uses provided items when available', () {
        final template = BinaryRain(
          data: testData,
          items: const ['Custom 1', 'Custom 2'],
        );
        expect(template.effectiveItems, ['Custom 1', 'Custom 2']);
      });

      test('uses metric labels when items not provided', () {
        final template = BinaryRain(data: testData);
        expect(template.effectiveItems, ['Song 1', 'Song 2', 'Song 3']);
      });
    });

    group('widget rendering', () {
      testWidgets('renders without error', (tester) async {
        final template = BinaryRain(data: testData);
        await tester.pumpWidget(wrapWithApp(template));

        expect(find.byType(BinaryRain), findsOneWidget);
      });

      testWidgets('displays title', (tester) async {
        final template = BinaryRain(data: testData);
        await tester.pumpWidget(wrapWithApp(template, frame: 60));

        expect(find.text('Your Songs'), findsWidgets);
      });

      testWidgets('renders without binary characters', (tester) async {
        final template = BinaryRain(
          data: testData,
          includeBinary: false,
        );
        await tester.pumpWidget(wrapWithApp(template));

        expect(find.byType(BinaryRain), findsOneWidget);
      });

      testWidgets('renders with custom items', (tester) async {
        final template = BinaryRain(
          data: testData,
          items: const ['Alpha', 'Beta', 'Gamma'],
        );
        await tester.pumpWidget(wrapWithApp(template));

        expect(find.byType(BinaryRain), findsOneWidget);
      });

      testWidgets('renders with different fall speed', (tester) async {
        final template = BinaryRain(
          data: testData,
          fallSpeed: 2.0,
        );
        await tester.pumpWidget(wrapWithApp(template));

        expect(find.byType(BinaryRain), findsOneWidget);
      });
    });

    group('toScene', () {
      test('creates scene with correct duration', () {
        final template = BinaryRain(data: testData);
        final scene = template.toScene();

        expect(scene.durationInFrames, 180);
      });

      test('creates scene with custom duration', () {
        final template = BinaryRain(data: testData);
        final scene = template.toScene(durationInFrames: 240);

        expect(scene.durationInFrames, 240);
      });

      test('creates scene with transitions', () {
        final template = BinaryRain(data: testData);
        final scene = template.toSceneWithCrossFade();

        expect(scene.transitionIn, isNotNull);
        expect(scene.transitionOut, isNotNull);
      });
    });

    group('animation frames', () {
      testWidgets('renders correctly at frame 0', (tester) async {
        final template = BinaryRain(data: testData);
        await tester.pumpWidget(wrapWithApp(template, frame: 0));

        expect(find.byType(BinaryRain), findsOneWidget);
      });

      testWidgets('renders correctly at mid frame', (tester) async {
        final template = BinaryRain(data: testData);
        await tester.pumpWidget(wrapWithApp(template, frame: 90));

        expect(find.byType(BinaryRain), findsOneWidget);
      });

      testWidgets('renders correctly at end frame', (tester) async {
        final template = BinaryRain(data: testData);
        await tester.pumpWidget(wrapWithApp(template, frame: 180));

        expect(find.byType(BinaryRain), findsOneWidget);
      });
    });

    group('theme variations', () {
      testWidgets('renders with neon theme', (tester) async {
        final template = BinaryRain(
          data: testData,
          theme: TemplateTheme.neon,
        );
        await tester.pumpWidget(wrapWithApp(template));

        expect(find.byType(BinaryRain), findsOneWidget);
      });

      testWidgets('renders with midnight theme', (tester) async {
        final template = BinaryRain(
          data: testData,
          theme: TemplateTheme.midnight,
        );
        await tester.pumpWidget(wrapWithApp(template));

        expect(find.byType(BinaryRain), findsOneWidget);
      });

      testWidgets('renders with retro theme', (tester) async {
        final template = BinaryRain(
          data: testData,
          theme: TemplateTheme.retro,
        );
        await tester.pumpWidget(wrapWithApp(template));

        expect(find.byType(BinaryRain), findsOneWidget);
      });
    });

    group('edge cases', () {
      testWidgets('handles empty metrics', (tester) async {
        final emptyData = DataVizData(
          title: 'Empty',
          metrics: const [],
        );
        final template = BinaryRain(data: emptyData);
        await tester.pumpWidget(wrapWithApp(template));

        expect(find.byType(BinaryRain), findsOneWidget);
      });

      testWidgets('handles empty items list with empty metrics',
          (tester) async {
        final emptyData = DataVizData(
          title: 'Empty',
          metrics: const [],
        );
        final template = BinaryRain(
          data: emptyData,
          items: const [],
        );
        await tester.pumpWidget(wrapWithApp(template));

        expect(find.byType(BinaryRain), findsOneWidget);
      });

      testWidgets('handles many columns', (tester) async {
        final template = BinaryRain(
          data: testData,
          columnCount: 50,
        );
        await tester.pumpWidget(wrapWithApp(template));

        expect(find.byType(BinaryRain), findsOneWidget);
      });

      testWidgets('handles few columns', (tester) async {
        final template = BinaryRain(
          data: testData,
          columnCount: 5,
        );
        await tester.pumpWidget(wrapWithApp(template));

        expect(find.byType(BinaryRain), findsOneWidget);
      });

      testWidgets('handles data with subtitle', (tester) async {
        final subtitleData = DataVizData(
          title: 'Songs',
          subtitle: '1,234 tracks',
          metrics: const [MetricData(label: 'Track', value: 1234)],
        );
        final template = BinaryRain(data: subtitleData);
        await tester.pumpWidget(wrapWithApp(template, frame: 80));

        expect(find.byType(BinaryRain), findsOneWidget);
      });

      testWidgets('handles very slow fall speed', (tester) async {
        final template = BinaryRain(
          data: testData,
          fallSpeed: 0.1,
        );
        await tester.pumpWidget(wrapWithApp(template));

        expect(find.byType(BinaryRain), findsOneWidget);
      });

      testWidgets('handles very fast fall speed', (tester) async {
        final template = BinaryRain(
          data: testData,
          fallSpeed: 5.0,
        );
        await tester.pumpWidget(wrapWithApp(template));

        expect(find.byType(BinaryRain), findsOneWidget);
      });
    });
  });
}
