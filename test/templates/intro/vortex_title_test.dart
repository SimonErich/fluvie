import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/templates/intro/vortex_title.dart';
import 'package:fluvie/src/templates/_base/template_base.dart';
import 'package:fluvie/src/templates/_base/template_config.dart';
import 'package:fluvie/src/templates/_base/template_data.dart';
import '../../helpers/test_helpers.dart';

void main() {
  group('VortexTitle', () {
    const testData = IntroData(
      title: 'WRAPPED',
      subtitle: 'Your Year in Review',
      year: 2024,
    );

    group('construction', () {
      test('creates with required data', () {
        const template = VortexTitle(data: testData);

        expect(template.data, testData);
        expect(template.introData, testData);
      });

      test('has default values', () {
        const template = VortexTitle(data: testData);

        expect(template.animateLetters, isTrue);
        expect(template.spiralSpeed, 1.0);
        expect(template.spiralRotations, 2.0);
        expect(template.showTrails, isTrue);
      });

      test('accepts custom values', () {
        const template = VortexTitle(
          data: testData,
          animateLetters: false,
          spiralSpeed: 1.5,
          spiralRotations: 3.0,
          showTrails: false,
        );

        expect(template.animateLetters, isFalse);
        expect(template.spiralSpeed, 1.5);
        expect(template.spiralRotations, 3.0);
        expect(template.showTrails, isFalse);
      });

      test('accepts theme', () {
        final template = VortexTitle(
          data: testData,
          theme: TemplateTheme.neon,
        );

        expect(template.theme, isNotNull);
      });

      test('accepts timing', () {
        const template = VortexTitle(
          data: testData,
          timing: TemplateTiming.dramatic,
        );

        expect(template.timing, TemplateTiming.dramatic);
      });
    });

    group('template properties', () {
      test('recommendedLength is 180 frames', () {
        const template = VortexTitle(data: testData);
        expect(template.recommendedLength, 180);
      });

      test('category is intro', () {
        const template = VortexTitle(data: testData);
        expect(template.category, TemplateCategory.intro);
      });

      test('description is set', () {
        const template = VortexTitle(data: testData);
        expect(template.description, isNotEmpty);
        expect(template.description, contains('spiral'));
      });

      test('defaultTheme is neon', () {
        const template = VortexTitle(data: testData);
        expect(template.defaultTheme, TemplateTheme.neon);
      });
    });

    group('introData getter', () {
      test('returns data cast to IntroData', () {
        const template = VortexTitle(data: testData);
        expect(template.introData, testData);
        expect(template.introData.title, 'WRAPPED');
        expect(template.introData.subtitle, 'Your Year in Review');
        expect(template.introData.year, 2024);
      });
    });

    group('widget rendering', () {
      testWidgets('renders without error', (tester) async {
        const template = VortexTitle(data: testData);
        await tester.pumpWidget(wrapWithApp(template));

        expect(find.byType(VortexTitle), findsOneWidget);
      });

      testWidgets('renders letters in letter animation mode', (tester) async {
        const template = VortexTitle(data: testData, animateLetters: true);
        await tester.pumpWidget(wrapWithApp(template, frame: 100));

        expect(find.byType(VortexTitle), findsOneWidget);
      });

      testWidgets('renders title in word animation mode', (tester) async {
        const template = VortexTitle(data: testData, animateLetters: false);
        await tester.pumpWidget(wrapWithApp(template, frame: 100));

        expect(find.text('WRAPPED'), findsWidgets);
      });

      testWidgets('displays year when provided', (tester) async {
        const template = VortexTitle(data: testData);
        await tester.pumpWidget(wrapWithApp(template, frame: 140));

        expect(find.text('2024'), findsWidgets);
      });

      testWidgets('displays subtitle when provided', (tester) async {
        const template = VortexTitle(data: testData);
        await tester.pumpWidget(wrapWithApp(template, frame: 150));

        expect(find.text('Your Year in Review'), findsWidgets);
      });

      testWidgets('renders without subtitle', (tester) async {
        const dataNoSubtitle = IntroData(title: 'Test');
        const template = VortexTitle(data: dataNoSubtitle);
        await tester.pumpWidget(wrapWithApp(template));

        expect(find.byType(VortexTitle), findsOneWidget);
      });

      testWidgets('renders without year', (tester) async {
        const dataNoYear = IntroData(title: 'Test', subtitle: 'Sub');
        const template = VortexTitle(data: dataNoYear);
        await tester.pumpWidget(wrapWithApp(template));

        expect(find.byType(VortexTitle), findsOneWidget);
      });

      testWidgets('renders with trails disabled', (tester) async {
        const template = VortexTitle(data: testData, showTrails: false);
        await tester.pumpWidget(wrapWithApp(template));

        expect(find.byType(VortexTitle), findsOneWidget);
      });
    });

    group('toScene', () {
      test('creates scene with correct duration', () {
        const template = VortexTitle(data: testData);
        final scene = template.toScene();

        expect(scene.durationInFrames, 180);
      });

      test('creates scene with custom duration', () {
        const template = VortexTitle(data: testData);
        final scene = template.toScene(durationInFrames: 240);

        expect(scene.durationInFrames, 240);
      });

      test('creates scene with transitions', () {
        const template = VortexTitle(data: testData);
        final scene = template.toSceneWithCrossFade();

        expect(scene.transitionIn, isNotNull);
        expect(scene.transitionOut, isNotNull);
      });
    });

    group('animation frames', () {
      testWidgets('renders correctly at frame 0', (tester) async {
        const template = VortexTitle(data: testData);
        await tester.pumpWidget(wrapWithApp(template, frame: 0));

        expect(find.byType(VortexTitle), findsOneWidget);
      });

      testWidgets('renders correctly at mid frame', (tester) async {
        const template = VortexTitle(data: testData);
        await tester.pumpWidget(wrapWithApp(template, frame: 90));

        expect(find.byType(VortexTitle), findsOneWidget);
      });

      testWidgets('renders correctly at end frame', (tester) async {
        const template = VortexTitle(data: testData);
        await tester.pumpWidget(wrapWithApp(template, frame: 180));

        expect(find.byType(VortexTitle), findsOneWidget);
      });
    });

    group('spiral variations', () {
      testWidgets('renders with slow spiral', (tester) async {
        const template = VortexTitle(data: testData, spiralSpeed: 0.5);
        await tester.pumpWidget(wrapWithApp(template));

        expect(find.byType(VortexTitle), findsOneWidget);
      });

      testWidgets('renders with fast spiral', (tester) async {
        const template = VortexTitle(data: testData, spiralSpeed: 2.5);
        await tester.pumpWidget(wrapWithApp(template));

        expect(find.byType(VortexTitle), findsOneWidget);
      });

      testWidgets('renders with many rotations', (tester) async {
        const template = VortexTitle(data: testData, spiralRotations: 5.0);
        await tester.pumpWidget(wrapWithApp(template));

        expect(find.byType(VortexTitle), findsOneWidget);
      });

      testWidgets('renders with few rotations', (tester) async {
        const template = VortexTitle(data: testData, spiralRotations: 0.5);
        await tester.pumpWidget(wrapWithApp(template));

        expect(find.byType(VortexTitle), findsOneWidget);
      });
    });

    group('theme variations', () {
      testWidgets('renders with neon theme', (tester) async {
        final template = VortexTitle(
          data: testData,
          theme: TemplateTheme.neon,
        );
        await tester.pumpWidget(wrapWithApp(template));

        expect(find.byType(VortexTitle), findsOneWidget);
      });

      testWidgets('renders with spotify theme', (tester) async {
        final template = VortexTitle(
          data: testData,
          theme: TemplateTheme.spotify,
        );
        await tester.pumpWidget(wrapWithApp(template));

        expect(find.byType(VortexTitle), findsOneWidget);
      });

      testWidgets('renders with midnight theme', (tester) async {
        final template = VortexTitle(
          data: testData,
          theme: TemplateTheme.midnight,
        );
        await tester.pumpWidget(wrapWithApp(template));

        expect(find.byType(VortexTitle), findsOneWidget);
      });
    });

    group('edge cases', () {
      testWidgets('handles empty title', (tester) async {
        const emptyData = IntroData(title: '');
        const template = VortexTitle(data: emptyData);
        await tester.pumpWidget(wrapWithApp(template));

        expect(find.byType(VortexTitle), findsOneWidget);
      });

      testWidgets('handles single character title', (tester) async {
        const singleCharData = IntroData(title: 'A');
        const template = VortexTitle(data: singleCharData);
        await tester.pumpWidget(wrapWithApp(template));

        expect(find.byType(VortexTitle), findsOneWidget);
      });

      testWidgets('handles very long title', (tester) async {
        const longData = IntroData(
          title: 'SUPERCALIFRAGILISTICEXPIALIDOCIOUS',
        );
        const template = VortexTitle(data: longData);
        await tester.pumpWidget(wrapWithApp(template));

        expect(find.byType(VortexTitle), findsOneWidget);
      });

      testWidgets('handles title with spaces', (tester) async {
        const spaceData = IntroData(title: 'YOUR YEAR');
        const template = VortexTitle(data: spaceData);
        await tester.pumpWidget(wrapWithApp(template));

        expect(find.byType(VortexTitle), findsOneWidget);
      });
    });
  });
}
