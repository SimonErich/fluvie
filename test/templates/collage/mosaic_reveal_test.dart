import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/templates/collage/mosaic_reveal.dart';
import 'package:fluvie/src/templates/_base/template_base.dart';
import 'package:fluvie/src/templates/_base/template_config.dart';
import 'package:fluvie/src/templates/_base/template_data.dart';
import '../../helpers/test_helpers.dart';

void main() {
  group('MosaicReveal', () {
    final testData = CollageData(
      title: 'Your #1 Artist',
      subtitle: 'Taylor Swift',
      images: ['main_artist.jpg'],
    );

    group('construction', () {
      test('creates with required data', () {
        final template = MosaicReveal(data: testData);

        expect(template.data, testData);
        expect(template.collageData, testData);
      });

      test('has default values', () {
        final template = MosaicReveal(data: testData);

        expect(template.tilesPerRow, 12);
        expect(template.rowCount, 16);
        expect(template.seed, 42);
      });

      test('accepts custom values', () {
        final template = MosaicReveal(
          data: testData,
          tilesPerRow: 8,
          rowCount: 12,
          seed: 123,
        );

        expect(template.tilesPerRow, 8);
        expect(template.rowCount, 12);
        expect(template.seed, 123);
      });

      test('accepts theme', () {
        final template = MosaicReveal(
          data: testData,
          theme: TemplateTheme.spotify,
        );

        expect(template.theme, isNotNull);
      });

      test('accepts timing', () {
        final template = MosaicReveal(
          data: testData,
          timing: TemplateTiming.dramatic,
        );

        expect(template.timing, TemplateTiming.dramatic);
      });
    });

    group('template properties', () {
      test('recommendedLength is 200 frames', () {
        final template = MosaicReveal(data: testData);
        expect(template.recommendedLength, 200);
      });

      test('category is collage', () {
        final template = MosaicReveal(data: testData);
        expect(template.category, TemplateCategory.collage);
      });

      test('description is set', () {
        final template = MosaicReveal(data: testData);
        expect(template.description, isNotEmpty);
        expect(template.description, contains('thumbnail'));
      });

      test('defaultTheme is spotify', () {
        final template = MosaicReveal(data: testData);
        expect(template.defaultTheme, TemplateTheme.spotify);
      });
    });

    group('collageData getter', () {
      test('returns data cast to CollageData', () {
        final template = MosaicReveal(data: testData);
        expect(template.collageData, testData);
        expect(template.collageData.title, 'Your #1 Artist');
        expect(template.collageData.subtitle, 'Taylor Swift');
      });
    });

    group('widget rendering', () {
      testWidgets('renders without error', (tester) async {
        final template = MosaicReveal(data: testData);
        await tester.pumpWidget(wrapWithApp(template));

        expect(find.byType(MosaicReveal), findsOneWidget);
      });

      testWidgets('renders with fewer tiles', (tester) async {
        final template = MosaicReveal(
          data: testData,
          tilesPerRow: 6,
          rowCount: 8,
        );
        await tester.pumpWidget(wrapWithApp(template));

        expect(find.byType(MosaicReveal), findsOneWidget);
      });

      testWidgets('renders with more tiles', (tester) async {
        final template = MosaicReveal(
          data: testData,
          tilesPerRow: 20,
          rowCount: 24,
        );
        await tester.pumpWidget(wrapWithApp(template));

        expect(find.byType(MosaicReveal), findsOneWidget);
      });

      testWidgets('renders with different seed', (tester) async {
        final template = MosaicReveal(
          data: testData,
          seed: 999,
        );
        await tester.pumpWidget(wrapWithApp(template));

        expect(find.byType(MosaicReveal), findsOneWidget);
      });
    });

    group('toScene', () {
      test('creates scene with correct duration', () {
        final template = MosaicReveal(data: testData);
        final scene = template.toScene();

        expect(scene.durationInFrames, 200);
      });

      test('creates scene with custom duration', () {
        final template = MosaicReveal(data: testData);
        final scene = template.toScene(durationInFrames: 250);

        expect(scene.durationInFrames, 250);
      });

      test('creates scene with transitions', () {
        final template = MosaicReveal(data: testData);
        final scene = template.toSceneWithCrossFade();

        expect(scene.transitionIn, isNotNull);
        expect(scene.transitionOut, isNotNull);
      });
    });

    group('animation frames', () {
      testWidgets('renders correctly at frame 0', (tester) async {
        final template = MosaicReveal(data: testData);
        await tester.pumpWidget(wrapWithApp(template, frame: 0));

        expect(find.byType(MosaicReveal), findsOneWidget);
      });

      testWidgets('renders correctly during tile reveal', (tester) async {
        final template = MosaicReveal(data: testData);
        await tester.pumpWidget(wrapWithApp(template, frame: 80));

        expect(find.byType(MosaicReveal), findsOneWidget);
      });

      testWidgets('renders correctly at mid frame', (tester) async {
        final template = MosaicReveal(data: testData);
        await tester.pumpWidget(wrapWithApp(template, frame: 100));

        expect(find.byType(MosaicReveal), findsOneWidget);
      });

      testWidgets('renders correctly when title appears', (tester) async {
        final template = MosaicReveal(data: testData);
        await tester.pumpWidget(wrapWithApp(template, frame: 160));

        expect(find.byType(MosaicReveal), findsOneWidget);
      });

      testWidgets('renders correctly at end frame', (tester) async {
        final template = MosaicReveal(data: testData);
        await tester.pumpWidget(wrapWithApp(template, frame: 200));

        expect(find.byType(MosaicReveal), findsOneWidget);
      });
    });

    group('theme variations', () {
      testWidgets('renders with spotify theme', (tester) async {
        final template = MosaicReveal(
          data: testData,
          theme: TemplateTheme.spotify,
        );
        await tester.pumpWidget(wrapWithApp(template));

        expect(find.byType(MosaicReveal), findsOneWidget);
      });

      testWidgets('renders with neon theme', (tester) async {
        final template = MosaicReveal(
          data: testData,
          theme: TemplateTheme.neon,
        );
        await tester.pumpWidget(wrapWithApp(template));

        expect(find.byType(MosaicReveal), findsOneWidget);
      });

      testWidgets('renders with pastel theme', (tester) async {
        final template = MosaicReveal(
          data: testData,
          theme: TemplateTheme.pastel,
        );
        await tester.pumpWidget(wrapWithApp(template));

        expect(find.byType(MosaicReveal), findsOneWidget);
      });
    });

    group('edge cases', () {
      test('CollageData requires at least one image', () {
        expect(
          () => CollageData(title: 'Empty', images: []),
          throwsA(isA<AssertionError>()),
        );
      });

      testWidgets('handles data without title', (tester) async {
        final noTitleData = CollageData(
          subtitle: 'Artist Name',
          images: ['image.jpg'],
        );
        final template = MosaicReveal(data: noTitleData);
        await tester.pumpWidget(wrapWithApp(template, frame: 170));

        expect(find.byType(MosaicReveal), findsOneWidget);
      });

      testWidgets('handles data without subtitle', (tester) async {
        final noSubtitleData = CollageData(
          title: 'Your Top',
          images: ['image.jpg'],
        );
        final template = MosaicReveal(data: noSubtitleData);
        await tester.pumpWidget(wrapWithApp(template, frame: 170));

        expect(find.byType(MosaicReveal), findsOneWidget);
      });

      testWidgets('handles minimum tile configuration', (tester) async {
        final template = MosaicReveal(
          data: testData,
          tilesPerRow: 2,
          rowCount: 2,
        );
        await tester.pumpWidget(wrapWithApp(template));

        expect(find.byType(MosaicReveal), findsOneWidget);
      });

      testWidgets('handles multiple images in data', (tester) async {
        final multiImageData = CollageData(
          title: 'Gallery',
          images: ['img1.jpg', 'img2.jpg', 'img3.jpg'],
        );
        final template = MosaicReveal(data: multiImageData);
        await tester.pumpWidget(wrapWithApp(template));

        expect(find.byType(MosaicReveal), findsOneWidget);
      });

      testWidgets('handles long title and subtitle', (tester) async {
        final longData = CollageData(
          title: 'This is a very long title for your top artist reveal',
          subtitle: 'This artist name is also quite long and might wrap',
          images: ['image.jpg'],
        );
        final template = MosaicReveal(data: longData);
        await tester.pumpWidget(wrapWithApp(template, frame: 170));

        expect(find.byType(MosaicReveal), findsOneWidget);
      });
    });
  });
}
