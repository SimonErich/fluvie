import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/templates/collage/the_grid_shuffle.dart';
import 'package:fluvie/src/templates/_base/template_base.dart';
import 'package:fluvie/src/templates/_base/template_config.dart';
import 'package:fluvie/src/templates/_base/template_data.dart';
import '../../helpers/test_helpers.dart';

void main() {
  group('TheGridShuffle', () {
    final testData = CollageData(
      title: 'Your Top Albums',
      images: [
        'assets/album1.jpg',
        'assets/album2.jpg',
        'assets/album3.jpg',
        'assets/album4.jpg',
        'assets/album5.jpg',
        'assets/album6.jpg',
        'assets/album7.jpg',
        'assets/album8.jpg',
        'assets/album9.jpg',
      ],
    );

    group('construction', () {
      test('creates with required data', () {
        final template = TheGridShuffle(data: testData);

        expect(template.data, testData);
        expect(template.collageData, testData);
      });

      test('has default values', () {
        final template = TheGridShuffle(data: testData);

        expect(template.gridSize, 3);
        expect(template.shuffleDuration, 60);
        expect(template.cellGap, 8);
        expect(template.seed, 42);
      });

      test('accepts custom values', () {
        final template = TheGridShuffle(
          data: testData,
          gridSize: 4,
          shuffleDuration: 90,
          cellGap: 12,
          seed: 123,
        );

        expect(template.gridSize, 4);
        expect(template.shuffleDuration, 90);
        expect(template.cellGap, 12);
        expect(template.seed, 123);
      });

      test('accepts theme', () {
        final template = TheGridShuffle(
          data: testData,
          theme: TemplateTheme.spotify,
        );

        expect(template.theme, isNotNull);
      });

      test('accepts timing', () {
        final template = TheGridShuffle(
          data: testData,
          timing: TemplateTiming.elastic,
        );

        expect(template.timing, TemplateTiming.elastic);
      });
    });

    group('template properties', () {
      test('recommendedLength is 150 frames', () {
        final template = TheGridShuffle(data: testData);
        expect(template.recommendedLength, 150);
      });

      test('category is collage', () {
        final template = TheGridShuffle(data: testData);
        expect(template.category, TemplateCategory.collage);
      });

      test('description is set', () {
        final template = TheGridShuffle(data: testData);
        expect(template.description, isNotEmpty);
        expect(template.description, contains('grid'));
      });

      test('defaultTheme is spotify', () {
        final template = TheGridShuffle(data: testData);
        expect(template.defaultTheme, TemplateTheme.spotify);
      });
    });

    group('collageData getter', () {
      test('returns data cast to CollageData', () {
        final template = TheGridShuffle(data: testData);
        expect(template.collageData, testData);
        expect(template.collageData.images.length, 9);
        expect(template.collageData.title, 'Your Top Albums');
      });
    });

    group('widget rendering', () {
      testWidgets('renders without error', (tester) async {
        final template = TheGridShuffle(data: testData);
        await tester.pumpWidget(wrapWithApp(template));

        expect(find.byType(TheGridShuffle), findsOneWidget);
      });

      testWidgets('displays title', (tester) async {
        final template = TheGridShuffle(data: testData);
        await tester.pumpWidget(wrapWithApp(template, frame: 20));

        expect(find.text('Your Top Albums'), findsWidgets);
      });

      testWidgets('renders with subtitle', (tester) async {
        final dataWithSubtitle = CollageData(
          title: 'Top Albums',
          subtitle: '2024 Favorites',
          images: ['img1.jpg', 'img2.jpg'],
        );
        final template = TheGridShuffle(data: dataWithSubtitle);
        await tester.pumpWidget(wrapWithApp(template, frame: 130));

        expect(find.byType(TheGridShuffle), findsOneWidget);
      });

      testWidgets('renders with different grid size', (tester) async {
        final template = TheGridShuffle(
          data: testData,
          gridSize: 4,
        );
        await tester.pumpWidget(wrapWithApp(template));

        expect(find.byType(TheGridShuffle), findsOneWidget);
      });

      testWidgets('renders with different cell gap', (tester) async {
        final template = TheGridShuffle(
          data: testData,
          cellGap: 16,
        );
        await tester.pumpWidget(wrapWithApp(template));

        expect(find.byType(TheGridShuffle), findsOneWidget);
      });
    });

    group('toScene', () {
      test('creates scene with correct duration', () {
        final template = TheGridShuffle(data: testData);
        final scene = template.toScene();

        expect(scene.durationInFrames, 150);
      });

      test('creates scene with custom duration', () {
        final template = TheGridShuffle(data: testData);
        final scene = template.toScene(durationInFrames: 200);

        expect(scene.durationInFrames, 200);
      });

      test('creates scene with transitions', () {
        final template = TheGridShuffle(data: testData);
        final scene = template.toSceneWithCrossFade();

        expect(scene.transitionIn, isNotNull);
        expect(scene.transitionOut, isNotNull);
      });
    });

    group('animation frames', () {
      testWidgets('renders correctly at frame 0', (tester) async {
        final template = TheGridShuffle(data: testData);
        await tester.pumpWidget(wrapWithApp(template, frame: 0));

        expect(find.byType(TheGridShuffle), findsOneWidget);
      });

      testWidgets('renders correctly during entry phase', (tester) async {
        final template = TheGridShuffle(data: testData);
        await tester.pumpWidget(wrapWithApp(template, frame: 20));

        expect(find.byType(TheGridShuffle), findsOneWidget);
      });

      testWidgets('renders correctly during shuffle phase', (tester) async {
        final template = TheGridShuffle(data: testData);
        await tester.pumpWidget(wrapWithApp(template, frame: 60));

        expect(find.byType(TheGridShuffle), findsOneWidget);
      });

      testWidgets('renders correctly during settle phase', (tester) async {
        final template = TheGridShuffle(data: testData);
        await tester.pumpWidget(wrapWithApp(template, frame: 100));

        expect(find.byType(TheGridShuffle), findsOneWidget);
      });

      testWidgets('renders correctly at end frame', (tester) async {
        final template = TheGridShuffle(data: testData);
        await tester.pumpWidget(wrapWithApp(template, frame: 150));

        expect(find.byType(TheGridShuffle), findsOneWidget);
      });
    });

    group('theme variations', () {
      testWidgets('renders with spotify theme', (tester) async {
        final template = TheGridShuffle(
          data: testData,
          theme: TemplateTheme.spotify,
        );
        await tester.pumpWidget(wrapWithApp(template));

        expect(find.byType(TheGridShuffle), findsOneWidget);
      });

      testWidgets('renders with neon theme', (tester) async {
        final template = TheGridShuffle(
          data: testData,
          theme: TemplateTheme.neon,
        );
        await tester.pumpWidget(wrapWithApp(template));

        expect(find.byType(TheGridShuffle), findsOneWidget);
      });

      testWidgets('renders with minimal theme', (tester) async {
        final template = TheGridShuffle(
          data: testData,
          theme: TemplateTheme.minimal,
        );
        await tester.pumpWidget(wrapWithApp(template));

        expect(find.byType(TheGridShuffle), findsOneWidget);
      });
    });

    group('edge cases', () {
      test('CollageData requires at least one image', () {
        expect(
          () => CollageData(title: 'Empty', images: []),
          throwsA(isA<AssertionError>()),
        );
      });

      testWidgets('handles single image', (tester) async {
        final singleData = CollageData(
          title: 'Single',
          images: ['single.jpg'],
        );
        final template = TheGridShuffle(data: singleData);
        await tester.pumpWidget(wrapWithApp(template));

        expect(find.byType(TheGridShuffle), findsOneWidget);
      });

      testWidgets('handles more images than grid cells', (tester) async {
        final manyImages = CollageData(
          title: 'Many',
          images: [
            'img1.jpg', 'img2.jpg', 'img3.jpg', 'img4.jpg', 'img5.jpg',
            'img6.jpg', 'img7.jpg', 'img8.jpg', 'img9.jpg', 'img10.jpg',
            'img11.jpg', 'img12.jpg', 'img13.jpg', 'img14.jpg', 'img15.jpg',
          ],
        );
        final template = TheGridShuffle(data: manyImages);
        await tester.pumpWidget(wrapWithApp(template));

        expect(find.byType(TheGridShuffle), findsOneWidget);
      });

      testWidgets('handles 2x2 grid', (tester) async {
        final template = TheGridShuffle(
          data: testData,
          gridSize: 2,
        );
        await tester.pumpWidget(wrapWithApp(template));

        expect(find.byType(TheGridShuffle), findsOneWidget);
      });

      testWidgets('handles zero cell gap', (tester) async {
        final template = TheGridShuffle(
          data: testData,
          cellGap: 0,
        );
        await tester.pumpWidget(wrapWithApp(template));

        expect(find.byType(TheGridShuffle), findsOneWidget);
      });

      testWidgets('handles long title', (tester) async {
        final longTitleData = CollageData(
          title: 'This is a very long title that might overflow the container',
          images: ['img1.jpg', 'img2.jpg'],
        );
        final template = TheGridShuffle(data: longTitleData);
        await tester.pumpWidget(wrapWithApp(template));

        expect(find.byType(TheGridShuffle), findsOneWidget);
      });
    });
  });
}
