import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/templates/thematic/lofi_window.dart';
import 'package:fluvie/src/templates/_base/template_base.dart';
import 'package:fluvie/src/templates/_base/template_config.dart';
import 'package:fluvie/src/templates/_base/template_data.dart';
import '../../helpers/test_helpers.dart';

void main() {
  group('LofiWindow', () {
    const testData = ThematicData(
      text: 'Late Night Vibes',
      title: 'Late Night Vibes',
      subtitle: '2,345 hours',
      description: 'Your most listened genre after midnight',
    );

    group('construction', () {
      test('creates with required data', () {
        const template = LofiWindow(data: testData);

        expect(template.data, testData);
        expect(template.thematicData, testData);
      });

      test('has default values', () {
        const template = LofiWindow(data: testData);

        expect(template.rainIntensity, 0.7);
        expect(template.fogAmount, 0.4);
        expect(template.showCityLights, isTrue);
        expect(template.seed, 42);
      });

      test('accepts custom values', () {
        const template = LofiWindow(
          data: testData,
          rainIntensity: 1.0,
          fogAmount: 0.8,
          showCityLights: false,
          seed: 123,
        );

        expect(template.rainIntensity, 1.0);
        expect(template.fogAmount, 0.8);
        expect(template.showCityLights, isFalse);
        expect(template.seed, 123);
      });

      test('accepts theme', () {
        const template = LofiWindow(
          data: testData,
          theme: TemplateTheme.midnight,
        );

        expect(template.theme, isNotNull);
      });

      test('accepts timing', () {
        const template = LofiWindow(
          data: testData,
          timing: TemplateTiming.smooth,
        );

        expect(template.timing, TemplateTiming.smooth);
      });
    });

    group('template properties', () {
      test('recommendedLength is 180 frames', () {
        const template = LofiWindow(data: testData);
        expect(template.recommendedLength, 180);
      });

      test('category is thematic', () {
        const template = LofiWindow(data: testData);
        expect(template.category, TemplateCategory.thematic);
      });

      test('description is set', () {
        const template = LofiWindow(data: testData);
        expect(template.description, isNotEmpty);
        expect(template.description, contains('Pixel'));
      });

      test('defaultTheme is midnight', () {
        const template = LofiWindow(data: testData);
        expect(template.defaultTheme, TemplateTheme.midnight);
      });
    });

    group('thematicData getter', () {
      test('returns data cast to ThematicData', () {
        const template = LofiWindow(data: testData);
        expect(template.thematicData, testData);
        expect(template.thematicData.title, 'Late Night Vibes');
        expect(template.thematicData.subtitle, '2,345 hours');
      });
    });

    group('widget rendering', () {
      testWidgets('renders without error', (tester) async {
        const template = LofiWindow(data: testData);
        await tester.pumpWidget(wrapWithApp(template));

        expect(find.byType(LofiWindow), findsOneWidget);
      });

      testWidgets('displays title', (tester) async {
        const template = LofiWindow(data: testData);
        await tester.pumpWidget(wrapWithApp(template, frame: 60));

        expect(find.text('Late Night Vibes'), findsWidgets);
      });

      testWidgets('renders without city lights', (tester) async {
        const template = LofiWindow(
          data: testData,
          showCityLights: false,
        );
        await tester.pumpWidget(wrapWithApp(template, frame: 50));

        expect(find.byType(LofiWindow), findsOneWidget);
      });

      testWidgets('renders with high rain intensity', (tester) async {
        const template = LofiWindow(
          data: testData,
          rainIntensity: 1.0,
        );
        await tester.pumpWidget(wrapWithApp(template));

        expect(find.byType(LofiWindow), findsOneWidget);
      });

      testWidgets('renders with low rain intensity', (tester) async {
        const template = LofiWindow(
          data: testData,
          rainIntensity: 0.1,
        );
        await tester.pumpWidget(wrapWithApp(template));

        expect(find.byType(LofiWindow), findsOneWidget);
      });

      testWidgets('renders with high fog amount', (tester) async {
        const template = LofiWindow(
          data: testData,
          fogAmount: 1.0,
        );
        await tester.pumpWidget(wrapWithApp(template));

        expect(find.byType(LofiWindow), findsOneWidget);
      });
    });

    group('toScene', () {
      test('creates scene with correct duration', () {
        const template = LofiWindow(data: testData);
        final scene = template.toScene();

        expect(scene.durationInFrames, 180);
      });

      test('creates scene with custom duration', () {
        const template = LofiWindow(data: testData);
        final scene = template.toScene(durationInFrames: 240);

        expect(scene.durationInFrames, 240);
      });

      test('creates scene with transitions', () {
        const template = LofiWindow(data: testData);
        final scene = template.toSceneWithCrossFade();

        expect(scene.transitionIn, isNotNull);
        expect(scene.transitionOut, isNotNull);
      });
    });

    group('animation frames', () {
      testWidgets('renders correctly at frame 0', (tester) async {
        const template = LofiWindow(data: testData);
        await tester.pumpWidget(wrapWithApp(template, frame: 0));

        expect(find.byType(LofiWindow), findsOneWidget);
      });

      testWidgets('renders correctly during title fade in', (tester) async {
        const template = LofiWindow(data: testData);
        await tester.pumpWidget(wrapWithApp(template, frame: 50));

        expect(find.byType(LofiWindow), findsOneWidget);
      });

      testWidgets('renders correctly at mid frame', (tester) async {
        const template = LofiWindow(data: testData);
        await tester.pumpWidget(wrapWithApp(template, frame: 90));

        expect(find.byType(LofiWindow), findsOneWidget);
      });

      testWidgets('renders correctly during description reveal',
          (tester) async {
        const template = LofiWindow(data: testData);
        await tester.pumpWidget(wrapWithApp(template, frame: 120));

        expect(find.byType(LofiWindow), findsOneWidget);
      });

      testWidgets('renders correctly at end frame', (tester) async {
        const template = LofiWindow(data: testData);
        await tester.pumpWidget(wrapWithApp(template, frame: 180));

        expect(find.byType(LofiWindow), findsOneWidget);
      });
    });

    group('theme variations', () {
      testWidgets('renders with midnight theme', (tester) async {
        const template = LofiWindow(
          data: testData,
          theme: TemplateTheme.midnight,
        );
        await tester.pumpWidget(wrapWithApp(template));

        expect(find.byType(LofiWindow), findsOneWidget);
      });

      testWidgets('renders with ocean theme', (tester) async {
        const template = LofiWindow(
          data: testData,
          theme: TemplateTheme.ocean,
        );
        await tester.pumpWidget(wrapWithApp(template));

        expect(find.byType(LofiWindow), findsOneWidget);
      });

      testWidgets('renders with neon theme', (tester) async {
        const template = LofiWindow(
          data: testData,
          theme: TemplateTheme.neon,
        );
        await tester.pumpWidget(wrapWithApp(template));

        expect(find.byType(LofiWindow), findsOneWidget);
      });
    });

    group('edge cases', () {
      testWidgets('handles data without title', (tester) async {
        const noTitleData = ThematicData(
          text: 'Content',
          subtitle: 'Subtitle only',
          description: 'Description',
        );
        const template = LofiWindow(data: noTitleData);
        await tester.pumpWidget(wrapWithApp(template, frame: 60));

        expect(find.byType(LofiWindow), findsOneWidget);
      });

      testWidgets('handles data without subtitle', (tester) async {
        const noSubtitleData = ThematicData(
          text: 'Content',
          title: 'Title only',
          description: 'Description',
        );
        const template = LofiWindow(data: noSubtitleData);
        await tester.pumpWidget(wrapWithApp(template, frame: 90));

        expect(find.byType(LofiWindow), findsOneWidget);
      });

      testWidgets('handles data without description', (tester) async {
        const noDescData = ThematicData(
          text: 'Content',
          title: 'Title',
          subtitle: 'Subtitle',
        );
        const template = LofiWindow(data: noDescData);
        await tester.pumpWidget(wrapWithApp(template, frame: 120));

        expect(find.byType(LofiWindow), findsOneWidget);
      });

      testWidgets('handles minimal data', (tester) async {
        const minimalData = ThematicData(text: 'Just text');
        const template = LofiWindow(data: minimalData);
        await tester.pumpWidget(wrapWithApp(template));

        expect(find.byType(LofiWindow), findsOneWidget);
      });

      testWidgets('handles zero rain intensity', (tester) async {
        const template = LofiWindow(
          data: testData,
          rainIntensity: 0.0,
        );
        await tester.pumpWidget(wrapWithApp(template));

        expect(find.byType(LofiWindow), findsOneWidget);
      });

      testWidgets('handles zero fog amount', (tester) async {
        const template = LofiWindow(
          data: testData,
          fogAmount: 0.0,
        );
        await tester.pumpWidget(wrapWithApp(template));

        expect(find.byType(LofiWindow), findsOneWidget);
      });

      testWidgets('handles long text content', (tester) async {
        ignoreOverflowErrors();
        const longData = ThematicData(
          text: 'Long content',
          title: 'This is a very long title that might wrap to multiple lines',
          subtitle: 'This is also a lengthy subtitle with many characters',
          description:
              'And here is an even longer description that describes the content in great detail',
        );
        const template = LofiWindow(data: longData);
        await tester.pumpWidget(wrapWithApp(template, frame: 120));

        expect(find.byType(LofiWindow), findsOneWidget);
      });
    });
  });
}
