import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/templates/data_viz/binary_rain.dart';
import 'package:fluvie/src/templates/_base/template_base.dart';
import 'package:fluvie/src/templates/_base/template_config.dart';
import 'package:fluvie/src/templates/_base/template_data.dart';
import '../../helpers/test_helpers.dart';

void main() {
  group('BinaryRain', () {
    const testData = DataVizData(
      title: 'Your Songs',
      metrics: [
        MetricData(label: 'Song 1', value: 100),
        MetricData(label: 'Song 2', value: 80),
        MetricData(label: 'Song 3', value: 60),
      ],
    );

    group('construction', () {
      test('creates with required data', () {
        const template = BinaryRain(data: testData);

        expect(template.data, testData);
        expect(template.dataVizData, testData);
      });

      test('has default values', () {
        const template = BinaryRain(data: testData);

        expect(template.columnCount, 20);
        expect(template.fallSpeed, 1.0);
        expect(template.items, isEmpty);
        expect(template.includeBinary, isTrue);
        expect(template.seed, 42);
      });

      test('accepts custom values', () {
        const template = BinaryRain(
          data: testData,
          columnCount: 30,
          fallSpeed: 1.5,
          items: ['Item 1', 'Item 2'],
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
        const template = BinaryRain(
          data: testData,
          theme: TemplateTheme.neon,
        );

        expect(template.theme, isNotNull);
      });

      test('accepts timing', () {
        const template = BinaryRain(
          data: testData,
          timing: TemplateTiming.dramatic,
        );

        expect(template.timing, TemplateTiming.dramatic);
      });
    });

    group('template properties', () {
      test('recommendedLength is 180 frames', () {
        const template = BinaryRain(data: testData);
        expect(template.recommendedLength, 180);
      });

      test('category is dataViz', () {
        const template = BinaryRain(data: testData);
        expect(template.category, TemplateCategory.dataViz);
      });

      test('description is set', () {
        const template = BinaryRain(data: testData);
        expect(template.description, isNotEmpty);
        expect(template.description, contains('Matrix'));
      });

      test('defaultTheme is neon', () {
        const template = BinaryRain(data: testData);
        expect(template.defaultTheme, TemplateTheme.neon);
      });
    });

    group('dataVizData getter', () {
      test('returns data cast to DataVizData', () {
        const template = BinaryRain(data: testData);
        expect(template.dataVizData, testData);
        expect(template.dataVizData.metrics.length, 3);
        expect(template.dataVizData.title, 'Your Songs');
      });
    });

    group('effectiveItems getter', () {
      test('uses provided items when available', () {
        const template = BinaryRain(
          data: testData,
          items: ['Custom 1', 'Custom 2'],
        );
        expect(template.effectiveItems, ['Custom 1', 'Custom 2']);
      });

      test('uses metric labels when items not provided', () {
        const template = BinaryRain(data: testData);
        expect(template.effectiveItems, ['Song 1', 'Song 2', 'Song 3']);
      });
    });

    group('widget rendering', () {
      testWidgets('renders without error', (tester) async {
        const template = BinaryRain(data: testData);
        await tester.pumpWidget(wrapWithApp(template));

        expect(find.byType(BinaryRain), findsOneWidget);
      });

      testWidgets('displays title', (tester) async {
        const template = BinaryRain(data: testData);
        await tester.pumpWidget(wrapWithApp(template, frame: 60));

        expect(find.text('Your Songs'), findsWidgets);
      });

      testWidgets('renders without binary characters', (tester) async {
        const template = BinaryRain(
          data: testData,
          includeBinary: false,
        );
        await tester.pumpWidget(wrapWithApp(template));

        expect(find.byType(BinaryRain), findsOneWidget);
      });

      testWidgets('renders with custom items', (tester) async {
        const template = BinaryRain(
          data: testData,
          items: ['Alpha', 'Beta', 'Gamma'],
        );
        await tester.pumpWidget(wrapWithApp(template));

        expect(find.byType(BinaryRain), findsOneWidget);
      });

      testWidgets('renders with different fall speed', (tester) async {
        const template = BinaryRain(
          data: testData,
          fallSpeed: 2.0,
        );
        await tester.pumpWidget(wrapWithApp(template));

        expect(find.byType(BinaryRain), findsOneWidget);
      });
    });

    group('toScene', () {
      test('creates scene with correct duration', () {
        const template = BinaryRain(data: testData);
        final scene = template.toScene();

        expect(scene.durationInFrames, 180);
      });

      test('creates scene with custom duration', () {
        const template = BinaryRain(data: testData);
        final scene = template.toScene(durationInFrames: 240);

        expect(scene.durationInFrames, 240);
      });

      test('creates scene with transitions', () {
        const template = BinaryRain(data: testData);
        final scene = template.toSceneWithCrossFade();

        expect(scene.transitionIn, isNotNull);
        expect(scene.transitionOut, isNotNull);
      });
    });

    group('animation frames', () {
      testWidgets('renders correctly at frame 0', (tester) async {
        const template = BinaryRain(data: testData);
        await tester.pumpWidget(wrapWithApp(template, frame: 0));

        expect(find.byType(BinaryRain), findsOneWidget);
      });

      testWidgets('renders correctly at mid frame', (tester) async {
        const template = BinaryRain(data: testData);
        await tester.pumpWidget(wrapWithApp(template, frame: 90));

        expect(find.byType(BinaryRain), findsOneWidget);
      });

      testWidgets('renders correctly at end frame', (tester) async {
        const template = BinaryRain(data: testData);
        await tester.pumpWidget(wrapWithApp(template, frame: 180));

        expect(find.byType(BinaryRain), findsOneWidget);
      });
    });

    group('theme variations', () {
      testWidgets('renders with neon theme', (tester) async {
        const template = BinaryRain(
          data: testData,
          theme: TemplateTheme.neon,
        );
        await tester.pumpWidget(wrapWithApp(template));

        expect(find.byType(BinaryRain), findsOneWidget);
      });

      testWidgets('renders with midnight theme', (tester) async {
        const template = BinaryRain(
          data: testData,
          theme: TemplateTheme.midnight,
        );
        await tester.pumpWidget(wrapWithApp(template));

        expect(find.byType(BinaryRain), findsOneWidget);
      });

      testWidgets('renders with retro theme', (tester) async {
        const template = BinaryRain(
          data: testData,
          theme: TemplateTheme.retro,
        );
        await tester.pumpWidget(wrapWithApp(template));

        expect(find.byType(BinaryRain), findsOneWidget);
      });
    });

    group('edge cases', () {
      testWidgets('handles empty metrics', (tester) async {
        const emptyData = DataVizData(
          title: 'Empty',
          metrics: [],
        );
        const template = BinaryRain(data: emptyData);
        await tester.pumpWidget(wrapWithApp(template));

        expect(find.byType(BinaryRain), findsOneWidget);
      });

      testWidgets('handles empty items list with empty metrics',
          (tester) async {
        const emptyData = DataVizData(
          title: 'Empty',
          metrics: [],
        );
        const template = BinaryRain(
          data: emptyData,
          items: [],
        );
        await tester.pumpWidget(wrapWithApp(template));

        expect(find.byType(BinaryRain), findsOneWidget);
      });

      testWidgets('handles many columns', (tester) async {
        const template = BinaryRain(
          data: testData,
          columnCount: 50,
        );
        await tester.pumpWidget(wrapWithApp(template));

        expect(find.byType(BinaryRain), findsOneWidget);
      });

      testWidgets('handles few columns', (tester) async {
        const template = BinaryRain(
          data: testData,
          columnCount: 5,
        );
        await tester.pumpWidget(wrapWithApp(template));

        expect(find.byType(BinaryRain), findsOneWidget);
      });

      testWidgets('handles data with subtitle', (tester) async {
        const subtitleData = DataVizData(
          title: 'Songs',
          subtitle: '1,234 tracks',
          metrics: [MetricData(label: 'Track', value: 1234)],
        );
        const template = BinaryRain(data: subtitleData);
        await tester.pumpWidget(wrapWithApp(template, frame: 80));

        expect(find.byType(BinaryRain), findsOneWidget);
      });

      testWidgets('handles very slow fall speed', (tester) async {
        const template = BinaryRain(
          data: testData,
          fallSpeed: 0.1,
        );
        await tester.pumpWidget(wrapWithApp(template));

        expect(find.byType(BinaryRain), findsOneWidget);
      });

      testWidgets('handles very fast fall speed', (tester) async {
        const template = BinaryRain(
          data: testData,
          fallSpeed: 5.0,
        );
        await tester.pumpWidget(wrapWithApp(template));

        expect(find.byType(BinaryRain), findsOneWidget);
      });
    });
  });
}
