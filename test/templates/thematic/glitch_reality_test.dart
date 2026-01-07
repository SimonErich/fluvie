import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/templates/thematic/glitch_reality.dart';
import 'package:fluvie/src/templates/_base/template_base.dart';
import 'package:fluvie/src/templates/_base/template_config.dart';
import 'package:fluvie/src/templates/_base/template_data.dart';
import '../../helpers/test_helpers.dart';

void main() {
  group('GlitchReality', () {
    const testData = ThematicData(
      text: 'Midnight Rain',
      title: 'Hidden Gem',
      subtitle: 'A song you discovered',
      value: 'Midnight Rain',
    );

    group('construction', () {
      test('creates with required data', () {
        const template = GlitchReality(data: testData);

        expect(template.data, testData);
        expect(template.thematicData, testData);
      });

      test('has default values', () {
        const template = GlitchReality(data: testData);

        expect(template.glitchIntensity, 0.8);
        expect(template.showScanlines, isTrue);
        expect(template.showChromatic, isTrue);
        expect(template.glitchFrames, isNull);
        expect(template.seed, 42);
      });

      test('accepts custom values', () {
        const template = GlitchReality(
          data: testData,
          glitchIntensity: 0.5,
          showScanlines: false,
          showChromatic: false,
          glitchFrames: [20, 50, 80],
          seed: 123,
        );

        expect(template.glitchIntensity, 0.5);
        expect(template.showScanlines, isFalse);
        expect(template.showChromatic, isFalse);
        expect(template.glitchFrames, [20, 50, 80]);
        expect(template.seed, 123);
      });

      test('accepts theme', () {
        final template = GlitchReality(
          data: testData,
          theme: TemplateTheme.retro,
        );

        expect(template.theme, isNotNull);
      });

      test('accepts timing', () {
        const template = GlitchReality(
          data: testData,
          timing: TemplateTiming.elastic,
        );

        expect(template.timing, TemplateTiming.elastic);
      });
    });

    group('template properties', () {
      test('recommendedLength is 150 frames', () {
        const template = GlitchReality(data: testData);
        expect(template.recommendedLength, 150);
      });

      test('category is thematic', () {
        const template = GlitchReality(data: testData);
        expect(template.category, TemplateCategory.thematic);
      });

      test('description is set', () {
        const template = GlitchReality(data: testData);
        expect(template.description, isNotEmpty);
        expect(template.description, contains('VHS'));
      });

      test('defaultTheme is retro', () {
        const template = GlitchReality(data: testData);
        expect(template.defaultTheme, TemplateTheme.retro);
      });
    });

    group('thematicData getter', () {
      test('returns data cast to ThematicData', () {
        const template = GlitchReality(data: testData);
        expect(template.thematicData, testData);
        expect(template.thematicData.title, 'Hidden Gem');
        expect(template.thematicData.value, 'Midnight Rain');
      });
    });

    group('effectiveGlitchFrames', () {
      test('returns default frames when not specified', () {
        const template = GlitchReality(data: testData);
        expect(template.effectiveGlitchFrames, [30, 60, 90, 110]);
      });

      test('returns custom frames when specified', () {
        const template = GlitchReality(
          data: testData,
          glitchFrames: [10, 40, 70],
        );
        expect(template.effectiveGlitchFrames, [10, 40, 70]);
      });
    });

    group('widget rendering', () {
      testWidgets('renders without error', (tester) async {
        const template = GlitchReality(data: testData);
        await tester.pumpWidget(wrapWithApp(template));

        expect(find.byType(GlitchReality), findsOneWidget);
      });

      testWidgets('displays title', (tester) async {
        const template = GlitchReality(data: testData);
        await tester.pumpWidget(wrapWithApp(template, frame: 20));

        expect(find.text('Hidden Gem'), findsWidgets);
      });

      testWidgets('renders without scanlines', (tester) async {
        const template = GlitchReality(
          data: testData,
          showScanlines: false,
        );
        await tester.pumpWidget(wrapWithApp(template));

        expect(find.byType(GlitchReality), findsOneWidget);
      });

      testWidgets('renders without chromatic aberration', (tester) async {
        const template = GlitchReality(
          data: testData,
          showChromatic: false,
        );
        await tester.pumpWidget(wrapWithApp(template, frame: 35));

        expect(find.byType(GlitchReality), findsOneWidget);
      });

      testWidgets('renders with low glitch intensity', (tester) async {
        const template = GlitchReality(
          data: testData,
          glitchIntensity: 0.2,
        );
        await tester.pumpWidget(wrapWithApp(template, frame: 35));

        expect(find.byType(GlitchReality), findsOneWidget);
      });

      testWidgets('renders with high glitch intensity', (tester) async {
        const template = GlitchReality(
          data: testData,
          glitchIntensity: 1.0,
        );
        await tester.pumpWidget(wrapWithApp(template, frame: 35));

        expect(find.byType(GlitchReality), findsOneWidget);
      });
    });

    group('toScene', () {
      test('creates scene with correct duration', () {
        const template = GlitchReality(data: testData);
        final scene = template.toScene();

        expect(scene.durationInFrames, 150);
      });

      test('creates scene with custom duration', () {
        const template = GlitchReality(data: testData);
        final scene = template.toScene(durationInFrames: 200);

        expect(scene.durationInFrames, 200);
      });

      test('creates scene with transitions', () {
        const template = GlitchReality(data: testData);
        final scene = template.toSceneWithCrossFade();

        expect(scene.transitionIn, isNotNull);
        expect(scene.transitionOut, isNotNull);
      });
    });

    group('animation frames', () {
      testWidgets('renders correctly at frame 0', (tester) async {
        const template = GlitchReality(data: testData);
        await tester.pumpWidget(wrapWithApp(template, frame: 0));

        expect(find.byType(GlitchReality), findsOneWidget);
      });

      testWidgets('renders correctly before first glitch', (tester) async {
        const template = GlitchReality(data: testData);
        await tester.pumpWidget(wrapWithApp(template, frame: 25));

        expect(find.byType(GlitchReality), findsOneWidget);
      });

      testWidgets('renders correctly during first glitch', (tester) async {
        const template = GlitchReality(data: testData);
        await tester.pumpWidget(wrapWithApp(template, frame: 35));

        expect(find.byType(GlitchReality), findsOneWidget);
      });

      testWidgets('renders correctly during second glitch', (tester) async {
        const template = GlitchReality(data: testData);
        await tester.pumpWidget(wrapWithApp(template, frame: 65));

        expect(find.byType(GlitchReality), findsOneWidget);
      });

      testWidgets('renders correctly at end frame', (tester) async {
        const template = GlitchReality(data: testData);
        await tester.pumpWidget(wrapWithApp(template, frame: 150));

        expect(find.byType(GlitchReality), findsOneWidget);
      });
    });

    group('theme variations', () {
      testWidgets('renders with retro theme', (tester) async {
        final template = GlitchReality(
          data: testData,
          theme: TemplateTheme.retro,
        );
        await tester.pumpWidget(wrapWithApp(template));

        expect(find.byType(GlitchReality), findsOneWidget);
      });

      testWidgets('renders with neon theme', (tester) async {
        final template = GlitchReality(
          data: testData,
          theme: TemplateTheme.neon,
        );
        await tester.pumpWidget(wrapWithApp(template));

        expect(find.byType(GlitchReality), findsOneWidget);
      });

      testWidgets('renders with midnight theme', (tester) async {
        final template = GlitchReality(
          data: testData,
          theme: TemplateTheme.midnight,
        );
        await tester.pumpWidget(wrapWithApp(template));

        expect(find.byType(GlitchReality), findsOneWidget);
      });
    });

    group('edge cases', () {
      testWidgets('handles data without title', (tester) async {
        const noTitleData = ThematicData(
          text: 'Song Name',
          subtitle: 'A discovery',
          value: 'Song Name',
        );
        const template = GlitchReality(data: noTitleData);
        await tester.pumpWidget(wrapWithApp(template, frame: 20));

        expect(find.byType(GlitchReality), findsOneWidget);
      });

      testWidgets('handles data without value', (tester) async {
        const noValueData = ThematicData(
          text: 'Hidden Gem',
          title: 'Hidden Gem',
          subtitle: 'No value',
        );
        const template = GlitchReality(data: noValueData);
        await tester.pumpWidget(wrapWithApp(template, frame: 40));

        expect(find.byType(GlitchReality), findsOneWidget);
      });

      testWidgets('handles data without subtitle', (tester) async {
        const noSubtitleData = ThematicData(
          text: 'Value',
          title: 'Title',
          value: 'Value',
        );
        const template = GlitchReality(data: noSubtitleData);
        await tester.pumpWidget(wrapWithApp(template, frame: 40));

        expect(find.byType(GlitchReality), findsOneWidget);
      });

      testWidgets('handles empty glitch frames', (tester) async {
        const template = GlitchReality(
          data: testData,
          glitchFrames: [],
        );
        await tester.pumpWidget(wrapWithApp(template, frame: 50));

        expect(find.byType(GlitchReality), findsOneWidget);
      });

      testWidgets('handles single glitch frame', (tester) async {
        const template = GlitchReality(
          data: testData,
          glitchFrames: [75],
        );
        await tester.pumpWidget(wrapWithApp(template, frame: 80));

        expect(find.byType(GlitchReality), findsOneWidget);
      });

      testWidgets('handles zero glitch intensity', (tester) async {
        const template = GlitchReality(
          data: testData,
          glitchIntensity: 0.0,
        );
        await tester.pumpWidget(wrapWithApp(template, frame: 35));

        expect(find.byType(GlitchReality), findsOneWidget);
      });

      testWidgets('handles long value text', (tester) async {
        const longValueData = ThematicData(
          text: 'Long Song',
          title: 'Hidden Gem',
          subtitle: 'A song',
          value: 'This Is A Very Long Song Title That Might Need To Wrap',
        );
        const template = GlitchReality(data: longValueData);
        await tester.pumpWidget(wrapWithApp(template, frame: 40));

        expect(find.byType(GlitchReality), findsOneWidget);
      });
    });
  });
}
