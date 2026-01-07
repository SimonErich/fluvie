import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/templates/collage/bento_recap.dart';
import 'package:fluvie/src/templates/_base/template_base.dart';
import 'package:fluvie/src/templates/_base/template_config.dart';
import 'package:fluvie/src/templates/_base/template_data.dart';
import '../../helpers/test_helpers.dart';

void main() {
  group('BentoRecap', () {
    final testData = CollageData(
      title: 'Your 2024',
      subtitle: 'Year in Review',
      images: ['highlight1.jpg', 'highlight2.jpg'],
      stats: {'Hours': '1,234', 'Songs': '5,678'},
      description: 'Your music journey',
    );

    group('construction', () {
      test('creates with required data', () {
        final template = BentoRecap(data: testData);

        expect(template.data, testData);
        expect(template.collageData, testData);
      });

      test('has default values', () {
        final template = BentoRecap(data: testData);

        expect(template.layout, BentoLayout.balanced);
        expect(template.cellGap, 12);
        expect(template.seed, 42);
      });

      test('accepts custom values', () {
        final template = BentoRecap(
          data: testData,
          layout: BentoLayout.heroFocused,
          cellGap: 20,
          seed: 123,
        );

        expect(template.layout, BentoLayout.heroFocused);
        expect(template.cellGap, 20);
        expect(template.seed, 123);
      });

      test('accepts theme', () {
        final template = BentoRecap(
          data: testData,
          theme: TemplateTheme.minimal,
        );

        expect(template.theme, isNotNull);
      });

      test('accepts timing', () {
        final template = BentoRecap(
          data: testData,
          timing: TemplateTiming.elastic,
        );

        expect(template.timing, TemplateTiming.elastic);
      });
    });

    group('template properties', () {
      test('recommendedLength is 180 frames', () {
        final template = BentoRecap(data: testData);
        expect(template.recommendedLength, 180);
      });

      test('category is collage', () {
        final template = BentoRecap(data: testData);
        expect(template.category, TemplateCategory.collage);
      });

      test('description is set', () {
        final template = BentoRecap(data: testData);
        expect(template.description, isNotEmpty);
        expect(template.description, contains('Bento'));
      });

      test('defaultTheme is minimal', () {
        final template = BentoRecap(data: testData);
        expect(template.defaultTheme, TemplateTheme.minimal);
      });
    });

    group('collageData getter', () {
      test('returns data cast to CollageData', () {
        final template = BentoRecap(data: testData);
        expect(template.collageData, testData);
        expect(template.collageData.title, 'Your 2024');
        expect(
            template.collageData.stats, {'Hours': '1,234', 'Songs': '5,678'});
      });
    });

    group('widget rendering', () {
      testWidgets('renders without error', (tester) async {
        final template = BentoRecap(data: testData);
        await tester.pumpWidget(wrapWithApp(template));

        expect(find.byType(BentoRecap), findsOneWidget);
      });

      testWidgets('renders with different cell gap', (tester) async {
        final template = BentoRecap(
          data: testData,
          cellGap: 24,
        );
        await tester.pumpWidget(wrapWithApp(template));

        expect(find.byType(BentoRecap), findsOneWidget);
      });

      testWidgets('renders with zero cell gap', (tester) async {
        final template = BentoRecap(
          data: testData,
          cellGap: 0,
        );
        await tester.pumpWidget(wrapWithApp(template));

        expect(find.byType(BentoRecap), findsOneWidget);
      });
    });

    group('layout variations', () {
      testWidgets('renders with balanced layout', (tester) async {
        final template = BentoRecap(
          data: testData,
          layout: BentoLayout.balanced,
        );
        await tester.pumpWidget(wrapWithApp(template));

        expect(find.byType(BentoRecap), findsOneWidget);
      });

      testWidgets('renders with hero focused layout', (tester) async {
        final template = BentoRecap(
          data: testData,
          layout: BentoLayout.heroFocused,
        );
        await tester.pumpWidget(wrapWithApp(template));

        expect(find.byType(BentoRecap), findsOneWidget);
      });

      testWidgets('renders with grid focused layout', (tester) async {
        final template = BentoRecap(
          data: testData,
          layout: BentoLayout.gridFocused,
        );
        await tester.pumpWidget(wrapWithApp(template));

        expect(find.byType(BentoRecap), findsOneWidget);
      });
    });

    group('toScene', () {
      test('creates scene with correct duration', () {
        final template = BentoRecap(data: testData);
        final scene = template.toScene();

        expect(scene.durationInFrames, 180);
      });

      test('creates scene with custom duration', () {
        final template = BentoRecap(data: testData);
        final scene = template.toScene(durationInFrames: 240);

        expect(scene.durationInFrames, 240);
      });

      test('creates scene with transitions', () {
        final template = BentoRecap(data: testData);
        final scene = template.toSceneWithCrossFade();

        expect(scene.transitionIn, isNotNull);
        expect(scene.transitionOut, isNotNull);
      });
    });

    group('animation frames', () {
      testWidgets('renders correctly at frame 0', (tester) async {
        final template = BentoRecap(data: testData);
        await tester.pumpWidget(wrapWithApp(template, frame: 0));

        expect(find.byType(BentoRecap), findsOneWidget);
      });

      testWidgets('renders correctly during cell entry', (tester) async {
        final template = BentoRecap(data: testData);
        await tester.pumpWidget(wrapWithApp(template, frame: 50));

        expect(find.byType(BentoRecap), findsOneWidget);
      });

      testWidgets('renders correctly at mid frame', (tester) async {
        final template = BentoRecap(data: testData);
        await tester.pumpWidget(wrapWithApp(template, frame: 90));

        expect(find.byType(BentoRecap), findsOneWidget);
      });

      testWidgets('renders correctly at end frame', (tester) async {
        final template = BentoRecap(data: testData);
        await tester.pumpWidget(wrapWithApp(template, frame: 180));

        expect(find.byType(BentoRecap), findsOneWidget);
      });
    });

    group('theme variations', () {
      testWidgets('renders with minimal theme', (tester) async {
        final template = BentoRecap(
          data: testData,
          theme: TemplateTheme.minimal,
        );
        await tester.pumpWidget(wrapWithApp(template));

        expect(find.byType(BentoRecap), findsOneWidget);
      });

      testWidgets('renders with spotify theme', (tester) async {
        final template = BentoRecap(
          data: testData,
          theme: TemplateTheme.spotify,
        );
        await tester.pumpWidget(wrapWithApp(template));

        expect(find.byType(BentoRecap), findsOneWidget);
      });

      testWidgets('renders with pastel theme', (tester) async {
        final template = BentoRecap(
          data: testData,
          theme: TemplateTheme.pastel,
        );
        await tester.pumpWidget(wrapWithApp(template));

        expect(find.byType(BentoRecap), findsOneWidget);
      });
    });

    group('edge cases', () {
      test('CollageData requires at least one image', () {
        expect(
          () => CollageData(title: 'Empty', images: []),
          throwsA(isA<AssertionError>()),
        );
      });

      testWidgets('handles empty stats', (tester) async {
        final noStatsData = CollageData(
          title: 'Your Year',
          images: ['img.jpg'],
          stats: {},
        );
        final template = BentoRecap(data: noStatsData);
        await tester.pumpWidget(wrapWithApp(template));

        expect(find.byType(BentoRecap), findsOneWidget);
      });

      testWidgets('handles data without title', (tester) async {
        final noTitleData = CollageData(
          subtitle: 'Year End',
          images: ['img.jpg'],
          stats: {'Hours': '100'},
        );
        final template = BentoRecap(data: noTitleData);
        await tester.pumpWidget(wrapWithApp(template));

        expect(find.byType(BentoRecap), findsOneWidget);
      });

      testWidgets('handles data without description', (tester) async {
        final noDescData = CollageData(
          title: 'Your Year',
          images: ['img.jpg'],
          stats: {'Hours': '100'},
        );
        final template = BentoRecap(data: noDescData);
        await tester.pumpWidget(wrapWithApp(template));

        expect(find.byType(BentoRecap), findsOneWidget);
      });

      testWidgets('handles many images', (tester) async {
        final manyImagesData = CollageData(
          title: 'Gallery',
          images: [
            'img1.jpg',
            'img2.jpg',
            'img3.jpg',
            'img4.jpg',
            'img5.jpg',
            'img6.jpg',
            'img7.jpg',
            'img8.jpg',
            'img9.jpg',
            'img10.jpg',
          ],
          stats: {'Hours': '100'},
        );
        final template = BentoRecap(data: manyImagesData);
        await tester.pumpWidget(wrapWithApp(template));

        expect(find.byType(BentoRecap), findsOneWidget);
      });

      testWidgets('handles many stats', (tester) async {
        final manyStatsData = CollageData(
          title: 'Stats',
          images: ['img.jpg'],
          stats: {
            'Hours': '1,234',
            'Songs': '5,678',
            'Artists': '892',
            'Genres': '45',
            'Albums': '234',
          },
        );
        final template = BentoRecap(data: manyStatsData);
        await tester.pumpWidget(wrapWithApp(template));

        expect(find.byType(BentoRecap), findsOneWidget);
      });
    });
  });

  group('BentoLayout', () {
    test('has all expected layouts', () {
      expect(BentoLayout.values, hasLength(3));
      expect(BentoLayout.values, contains(BentoLayout.balanced));
      expect(BentoLayout.values, contains(BentoLayout.heroFocused));
      expect(BentoLayout.values, contains(BentoLayout.gridFocused));
    });
  });

  group('BentoCellType', () {
    test('has all expected types', () {
      expect(BentoCellType.values, hasLength(5));
      expect(BentoCellType.values, contains(BentoCellType.hero));
      expect(BentoCellType.values, contains(BentoCellType.image));
      expect(BentoCellType.values, contains(BentoCellType.stat));
      expect(BentoCellType.values, contains(BentoCellType.icon));
      expect(BentoCellType.values, contains(BentoCellType.text));
    });
  });
}
