import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/templates/thematic/kaleidoscope.dart';
import 'package:fluvie/src/templates/_base/template_base.dart';
import 'package:fluvie/src/templates/_base/template_config.dart';
import 'package:fluvie/src/templates/_base/template_data.dart';
import '../../helpers/test_helpers.dart';

void main() {
  group('Kaleidoscope', () {
    const testData = ThematicData(
      text: 'Psychedelic Rock',
      title: 'Your Top Sound',
      subtitle: 'Psychedelic Rock',
      description: 'A journey through colors',
    );

    group('construction', () {
      test('creates with required data', () {
        const template = Kaleidoscope(data: testData);

        expect(template.data, testData);
        expect(template.thematicData, testData);
      });

      test('has default values', () {
        const template = Kaleidoscope(data: testData);

        expect(template.segmentCount, 6);
        expect(template.rotationSpeed, 0.3);
        expect(template.pulseIntensity, 0.1);
        expect(template.images, isNull);
      });

      test('accepts custom values', () {
        const template = Kaleidoscope(
          data: testData,
          segmentCount: 8,
          rotationSpeed: 0.5,
          pulseIntensity: 0.2,
          images: ['album1.jpg', 'album2.jpg'],
        );

        expect(template.segmentCount, 8);
        expect(template.rotationSpeed, 0.5);
        expect(template.pulseIntensity, 0.2);
        expect(template.images, ['album1.jpg', 'album2.jpg']);
      });

      test('accepts theme', () {
        final template = Kaleidoscope(
          data: testData,
          theme: TemplateTheme.neon,
        );

        expect(template.theme, isNotNull);
      });

      test('accepts timing', () {
        const template = Kaleidoscope(
          data: testData,
          timing: TemplateTiming.smooth,
        );

        expect(template.timing, TemplateTiming.smooth);
      });
    });

    group('template properties', () {
      test('recommendedLength is 200 frames', () {
        const template = Kaleidoscope(data: testData);
        expect(template.recommendedLength, 200);
      });

      test('category is thematic', () {
        const template = Kaleidoscope(data: testData);
        expect(template.category, TemplateCategory.thematic);
      });

      test('description is set', () {
        const template = Kaleidoscope(data: testData);
        expect(template.description, isNotEmpty);
        expect(template.description, contains('kaleidoscope'));
      });

      test('defaultTheme is neon', () {
        const template = Kaleidoscope(data: testData);
        expect(template.defaultTheme, TemplateTheme.neon);
      });
    });

    group('thematicData getter', () {
      test('returns data cast to ThematicData', () {
        const template = Kaleidoscope(data: testData);
        expect(template.thematicData, testData);
        expect(template.thematicData.title, 'Your Top Sound');
        expect(template.thematicData.subtitle, 'Psychedelic Rock');
      });
    });

    group('widget rendering', () {
      testWidgets('renders without error', (tester) async {
        const template = Kaleidoscope(data: testData);
        await tester.pumpWidget(wrapWithApp(template));

        expect(find.byType(Kaleidoscope), findsOneWidget);
      });

      testWidgets('displays title', (tester) async {
        const template = Kaleidoscope(data: testData);
        await tester.pumpWidget(wrapWithApp(template, frame: 80));

        expect(find.text('Your Top Sound'), findsWidgets);
      });

      testWidgets('renders with different segment count', (tester) async {
        const template = Kaleidoscope(
          data: testData,
          segmentCount: 4,
        );
        await tester.pumpWidget(wrapWithApp(template));

        expect(find.byType(Kaleidoscope), findsOneWidget);
      });

      testWidgets('renders with many segments', (tester) async {
        const template = Kaleidoscope(
          data: testData,
          segmentCount: 12,
        );
        await tester.pumpWidget(wrapWithApp(template));

        expect(find.byType(Kaleidoscope), findsOneWidget);
      });

      testWidgets('renders with fast rotation', (tester) async {
        const template = Kaleidoscope(
          data: testData,
          rotationSpeed: 1.0,
        );
        await tester.pumpWidget(wrapWithApp(template, frame: 50));

        expect(find.byType(Kaleidoscope), findsOneWidget);
      });

      testWidgets('renders with high pulse intensity', (tester) async {
        const template = Kaleidoscope(
          data: testData,
          pulseIntensity: 0.5,
        );
        await tester.pumpWidget(wrapWithApp(template, frame: 50));

        expect(find.byType(Kaleidoscope), findsOneWidget);
      });

      testWidgets('renders with images', (tester) async {
        const template = Kaleidoscope(
          data: testData,
          images: ['img1.jpg', 'img2.jpg', 'img3.jpg'],
        );
        await tester.pumpWidget(wrapWithApp(template));

        expect(find.byType(Kaleidoscope), findsOneWidget);
      });
    });

    group('toScene', () {
      test('creates scene with correct duration', () {
        const template = Kaleidoscope(data: testData);
        final scene = template.toScene();

        expect(scene.durationInFrames, 200);
      });

      test('creates scene with custom duration', () {
        const template = Kaleidoscope(data: testData);
        final scene = template.toScene(durationInFrames: 300);

        expect(scene.durationInFrames, 300);
      });

      test('creates scene with transitions', () {
        const template = Kaleidoscope(data: testData);
        final scene = template.toSceneWithCrossFade();

        expect(scene.transitionIn, isNotNull);
        expect(scene.transitionOut, isNotNull);
      });
    });

    group('animation frames', () {
      testWidgets('renders correctly at frame 0', (tester) async {
        const template = Kaleidoscope(data: testData);
        await tester.pumpWidget(wrapWithApp(template, frame: 0));

        expect(find.byType(Kaleidoscope), findsOneWidget);
      });

      testWidgets('renders correctly during entry animation', (tester) async {
        const template = Kaleidoscope(data: testData);
        await tester.pumpWidget(wrapWithApp(template, frame: 30));

        expect(find.byType(Kaleidoscope), findsOneWidget);
      });

      testWidgets('renders correctly during title animation', (tester) async {
        const template = Kaleidoscope(data: testData);
        await tester.pumpWidget(wrapWithApp(template, frame: 80));

        expect(find.byType(Kaleidoscope), findsOneWidget);
      });

      testWidgets('renders correctly at mid frame', (tester) async {
        const template = Kaleidoscope(data: testData);
        await tester.pumpWidget(wrapWithApp(template, frame: 100));

        expect(find.byType(Kaleidoscope), findsOneWidget);
      });

      testWidgets('renders correctly at end frame', (tester) async {
        const template = Kaleidoscope(data: testData);
        await tester.pumpWidget(wrapWithApp(template, frame: 200));

        expect(find.byType(Kaleidoscope), findsOneWidget);
      });
    });

    group('theme variations', () {
      testWidgets('renders with neon theme', (tester) async {
        final template = Kaleidoscope(
          data: testData,
          theme: TemplateTheme.neon,
        );
        await tester.pumpWidget(wrapWithApp(template));

        expect(find.byType(Kaleidoscope), findsOneWidget);
      });

      testWidgets('renders with spotify theme', (tester) async {
        final template = Kaleidoscope(
          data: testData,
          theme: TemplateTheme.spotify,
        );
        await tester.pumpWidget(wrapWithApp(template));

        expect(find.byType(Kaleidoscope), findsOneWidget);
      });

      testWidgets('renders with pastel theme', (tester) async {
        final template = Kaleidoscope(
          data: testData,
          theme: TemplateTheme.pastel,
        );
        await tester.pumpWidget(wrapWithApp(template));

        expect(find.byType(Kaleidoscope), findsOneWidget);
      });
    });

    group('edge cases', () {
      testWidgets('handles data without title', (tester) async {
        const noTitleData = ThematicData(
          text: 'Content',
          subtitle: 'Subtitle',
          description: 'Description',
        );
        const template = Kaleidoscope(data: noTitleData);
        await tester.pumpWidget(wrapWithApp(template, frame: 80));

        expect(find.byType(Kaleidoscope), findsOneWidget);
      });

      testWidgets('handles data without subtitle', (tester) async {
        const noSubtitleData = ThematicData(
          text: 'Content',
          title: 'Title',
          description: 'Description',
        );
        const template = Kaleidoscope(data: noSubtitleData);
        await tester.pumpWidget(wrapWithApp(template, frame: 80));

        expect(find.byType(Kaleidoscope), findsOneWidget);
      });

      testWidgets('handles data without description', (tester) async {
        const noDescData = ThematicData(
          text: 'Content',
          title: 'Title',
          subtitle: 'Subtitle',
        );
        const template = Kaleidoscope(data: noDescData);
        await tester.pumpWidget(wrapWithApp(template, frame: 110));

        expect(find.byType(Kaleidoscope), findsOneWidget);
      });

      testWidgets('handles minimal segment count', (tester) async {
        const template = Kaleidoscope(
          data: testData,
          segmentCount: 2,
        );
        await tester.pumpWidget(wrapWithApp(template));

        expect(find.byType(Kaleidoscope), findsOneWidget);
      });

      testWidgets('handles zero rotation speed', (tester) async {
        const template = Kaleidoscope(
          data: testData,
          rotationSpeed: 0.0,
        );
        await tester.pumpWidget(wrapWithApp(template, frame: 50));

        expect(find.byType(Kaleidoscope), findsOneWidget);
      });

      testWidgets('handles negative rotation speed', (tester) async {
        const template = Kaleidoscope(
          data: testData,
          rotationSpeed: -0.3,
        );
        await tester.pumpWidget(wrapWithApp(template, frame: 50));

        expect(find.byType(Kaleidoscope), findsOneWidget);
      });

      testWidgets('handles zero pulse intensity', (tester) async {
        const template = Kaleidoscope(
          data: testData,
          pulseIntensity: 0.0,
        );
        await tester.pumpWidget(wrapWithApp(template, frame: 50));

        expect(find.byType(Kaleidoscope), findsOneWidget);
      });

      testWidgets('handles empty images list', (tester) async {
        const template = Kaleidoscope(
          data: testData,
          images: [],
        );
        await tester.pumpWidget(wrapWithApp(template));

        expect(find.byType(Kaleidoscope), findsOneWidget);
      });

      testWidgets('handles minimal data', (tester) async {
        const minimalData = ThematicData(text: 'Text only');
        const template = Kaleidoscope(data: minimalData);
        await tester.pumpWidget(wrapWithApp(template));

        expect(find.byType(Kaleidoscope), findsOneWidget);
      });
    });
  });
}
