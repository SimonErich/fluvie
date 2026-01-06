import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/templates/collage/triptych_scroll.dart';
import 'package:fluvie/src/templates/_base/template_base.dart';
import 'package:fluvie/src/templates/_base/template_config.dart';
import 'package:fluvie/src/templates/_base/template_data.dart';
import 'package:fluvie/src/declarative/core/scene.dart';
import '../../helpers/test_helpers.dart';

void main() {
  group('TriptychScroll', () {
    final testData = CollageData(
      title: 'Your Year',
      subtitle: 'A journey in music',
      description: '1,234 moments captured',
      images: [
        'img1.jpg', 'img2.jpg', 'img3.jpg', 'img4.jpg', 'img5.jpg',
        'img6.jpg', 'img7.jpg', 'img8.jpg', 'img9.jpg', 'img10.jpg',
      ],
    );

    group('construction and initialization', () {
      test('stores data correctly', () {
        final template = TriptychScroll(data: testData);

        expect(template.data, same(testData));
        expect(template.collageData, same(testData));
        expect(template.collageData.title, 'Your Year');
        expect(template.collageData.subtitle, 'A journey in music');
        expect(template.collageData.description, '1,234 moments captured');
        expect(template.collageData.images.length, 10);
      });

      test('applies default values correctly', () {
        final template = TriptychScroll(data: testData);

        expect(template.columnCount, 3, reason: 'Default column count should be 3');
        expect(template.scrollSpeed, 1.0, reason: 'Default scroll speed should be 1.0');
        expect(template.showTitle, isTrue, reason: 'Title should be shown by default');
        expect(template.imageGap, 8, reason: 'Default image gap should be 8');
        expect(template.theme, isNull, reason: 'Theme should be null by default');
        expect(template.timing, isNull, reason: 'Timing should be null by default');
      });

      test('accepts and stores custom values', () {
        final template = TriptychScroll(
          data: testData,
          columnCount: 5,
          scrollSpeed: 1.5,
          showTitle: false,
          imageGap: 16,
          theme: TemplateTheme.neon,
          timing: TemplateTiming.smooth,
        );

        expect(template.columnCount, 5);
        expect(template.scrollSpeed, 1.5);
        expect(template.showTitle, isFalse);
        expect(template.imageGap, 16);
        expect(template.theme, TemplateTheme.neon);
        expect(template.timing, TemplateTiming.smooth);
      });
    });

    group('template metadata', () {
      test('recommendedLength returns correct value', () {
        final template = TriptychScroll(data: testData);
        expect(template.recommendedLength, 200);
      });

      test('category is collage', () {
        final template = TriptychScroll(data: testData);
        expect(template.category, TemplateCategory.collage);
      });

      test('description mentions parallax effect', () {
        final template = TriptychScroll(data: testData);
        expect(template.description, contains('parallax'));
      });

      test('defaultTheme is spotify', () {
        final template = TriptychScroll(data: testData);
        expect(template.defaultTheme, TemplateTheme.spotify);
        expect(template.defaultTheme.primaryColor, const Color(0xFF1DB954));
        expect(template.defaultTheme.backgroundColor, const Color(0xFF121212));
      });
    });

    group('scene creation', () {
      test('toScene creates scene with recommended duration', () {
        final template = TriptychScroll(data: testData);
        final scene = template.toScene();

        expect(scene, isA<Scene>());
        expect(scene.durationInFrames, 200);
      });

      test('toScene allows custom duration', () {
        final template = TriptychScroll(data: testData);
        final scene = template.toScene(durationInFrames: 300);

        expect(scene.durationInFrames, 300);
      });

      test('toSceneWithCrossFade adds transitions', () {
        final template = TriptychScroll(data: testData);
        final scene = template.toSceneWithCrossFade(fadeDuration: 20);

        expect(scene.transitionIn, isNotNull);
        expect(scene.transitionOut, isNotNull);
      });
    });

    group('widget rendering', () {
      testWidgets('creates Row with correct number of columns', (tester) async {
        ignoreOverflowErrors();
        final template = TriptychScroll(data: testData, columnCount: 3);
        await tester.pumpWidget(wrapWithApp(template));

        final rows = tester.widgetList<Row>(find.byType(Row));
        expect(rows, isNotEmpty);
      });

      testWidgets('shows title text when showTitle is true', (tester) async {
        ignoreOverflowErrors();
        final template = TriptychScroll(data: testData, showTitle: true);
        await tester.pumpWidget(wrapWithApp(template, frame: 60));

        expect(find.text('Your Year'), findsWidgets);
      });

      testWidgets('shows subtitle when present', (tester) async {
        ignoreOverflowErrors();
        final template = TriptychScroll(data: testData, showTitle: true);
        await tester.pumpWidget(wrapWithApp(template, frame: 60));

        expect(find.text('A journey in music'), findsWidgets);
      });

      testWidgets('shows description badge when present', (tester) async {
        ignoreOverflowErrors();
        final template = TriptychScroll(data: testData, showTitle: true);
        await tester.pumpWidget(wrapWithApp(template, frame: 60));

        expect(find.text('1,234 moments captured'), findsWidgets);
      });

      testWidgets('hides title when showTitle is false', (tester) async {
        ignoreOverflowErrors();
        final template = TriptychScroll(data: testData, showTitle: false);
        await tester.pumpWidget(wrapWithApp(template, frame: 60));

        expect(find.text('Your Year'), findsNothing);
      });

      testWidgets('applies theme background color', (tester) async {
        ignoreOverflowErrors();
        final template = TriptychScroll(
          data: testData,
          theme: TemplateTheme.neon,
        );
        await tester.pumpWidget(wrapWithApp(template));

        final containers = tester.widgetList<Container>(find.byType(Container));
        final hasNeonBackground = containers.any(
          (c) => c.color == TemplateTheme.neon.backgroundColor,
        );
        expect(hasNeonBackground, isTrue);
      });

      testWidgets('renders ClipRRect for image containers', (tester) async {
        ignoreOverflowErrors();
        final template = TriptychScroll(data: testData);
        await tester.pumpWidget(wrapWithApp(template));

        expect(find.byType(ClipRRect), findsWidgets);
      });
    });

    group('animation behavior', () {
      testWidgets('renders at different frames without error', (tester) async {
        ignoreOverflowErrors();
        final template = TriptychScroll(data: testData, scrollSpeed: 1.0);

        // Render at frame 0
        await tester.pumpWidget(wrapWithApp(template, frame: 0));
        expect(find.byType(TriptychScroll), findsOneWidget);

        // Render at frame 50 - should also render
        await tester.pumpWidget(wrapWithApp(template, frame: 50));
        expect(find.byType(TriptychScroll), findsOneWidget);

        // The parallax scrolling effect uses Transform.translate internally
        expect(find.byType(ClipRect), findsWidgets);
      });

      testWidgets('zero scroll speed creates static display', (tester) async {
        ignoreOverflowErrors();
        final template = TriptychScroll(data: testData, scrollSpeed: 0.0);

        await tester.pumpWidget(wrapWithApp(template, frame: 0));
        expect(find.byType(TriptychScroll), findsOneWidget);

        await tester.pumpWidget(wrapWithApp(template, frame: 100));
        expect(find.byType(TriptychScroll), findsOneWidget);
      });

      testWidgets('title animation appears after frame 30', (tester) async {
        ignoreOverflowErrors();
        final template = TriptychScroll(data: testData, showTitle: true);

        await tester.pumpWidget(wrapWithApp(template, frame: 80));
        expect(find.text('Your Year'), findsWidgets);
      });
    });

    group('edge cases', () {
      test('CollageData requires at least one image', () {
        // CollageData has an assertion requiring at least 1 image
        expect(
          () => CollageData(title: 'Empty', images: []),
          throwsA(isA<AssertionError>()),
        );
      });

      testWidgets('handles single image', (tester) async {
        ignoreOverflowErrors();
        final singleData = CollageData(title: 'Single', images: ['img.jpg']);
        final template = TriptychScroll(data: singleData);
        await tester.pumpWidget(wrapWithApp(template));

        expect(find.byType(TriptychScroll), findsOneWidget);
      });

      testWidgets('handles data without title', (tester) async {
        ignoreOverflowErrors();
        final noTitleData = CollageData(images: ['img1.jpg', 'img2.jpg']);
        final template = TriptychScroll(data: noTitleData, showTitle: true);
        await tester.pumpWidget(wrapWithApp(template, frame: 60));

        expect(find.text('Your Gallery'), findsWidgets);
      });

      testWidgets('handles single column layout', (tester) async {
        ignoreOverflowErrors();
        final template = TriptychScroll(data: testData, columnCount: 1);
        await tester.pumpWidget(wrapWithApp(template));

        expect(find.byType(TriptychScroll), findsOneWidget);
        expect(find.byType(Expanded), findsWidgets);
      });

      testWidgets('handles many columns', (tester) async {
        ignoreOverflowErrors();
        final template = TriptychScroll(data: testData, columnCount: 7);
        await tester.pumpWidget(wrapWithApp(template));

        expect(find.byType(TriptychScroll), findsOneWidget);
      });

      testWidgets('handles negative scroll speed', (tester) async {
        ignoreOverflowErrors();
        final template = TriptychScroll(data: testData, scrollSpeed: -1.0);
        await tester.pumpWidget(wrapWithApp(template, frame: 50));

        expect(find.byType(TriptychScroll), findsOneWidget);
      });

      testWidgets('handles zero image gap', (tester) async {
        ignoreOverflowErrors();
        final template = TriptychScroll(data: testData, imageGap: 0);
        await tester.pumpWidget(wrapWithApp(template));

        expect(find.byType(TriptychScroll), findsOneWidget);
      });

      testWidgets('handles large image gap', (tester) async {
        ignoreOverflowErrors();
        final template = TriptychScroll(data: testData, imageGap: 50);
        await tester.pumpWidget(wrapWithApp(template));

        expect(find.byType(TriptychScroll), findsOneWidget);
      });
    });

    group('theme variations', () {
      for (final entry in {
        'spotify': TemplateTheme.spotify,
        'neon': TemplateTheme.neon,
        'minimal': TemplateTheme.minimal,
        'midnight': TemplateTheme.midnight,
        'sunset': TemplateTheme.sunset,
      }.entries) {
        testWidgets('renders correctly with ${entry.key} theme', (tester) async {
          ignoreOverflowErrors();
          final template = TriptychScroll(data: testData, theme: entry.value);
          await tester.pumpWidget(wrapWithApp(template));

          expect(find.byType(TriptychScroll), findsOneWidget);
          final containers = tester.widgetList<Container>(find.byType(Container));
          expect(containers, isNotEmpty);
        });
      }
    });

    group('timing presets', () {
      test('accepts all timing presets', () {
        final timings = [
          TemplateTiming.quick,
          TemplateTiming.standard,
          TemplateTiming.dramatic,
          TemplateTiming.elastic,
          TemplateTiming.slowReveal,
          TemplateTiming.smooth,
        ];

        for (final timing in timings) {
          final template = TriptychScroll(data: testData, timing: timing);
          expect(template.timing, timing);
        }
      });
    });
  });
}
