import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/templates/intro/digital_mirror.dart';
import 'package:fluvie/src/templates/_base/template_base.dart';
import 'package:fluvie/src/templates/_base/template_config.dart';
import 'package:fluvie/src/templates/_base/template_data.dart';
import '../../helpers/test_helpers.dart';

void main() {
  group('DigitalMirror', () {
    const testData = IntroData(
      title: 'Your Story',
      subtitle: 'Begins Here',
      userName: 'John',
      profileImagePath: 'assets/profile.jpg',
    );

    group('construction', () {
      test('creates with required data', () {
        const template = DigitalMirror(data: testData);

        expect(template.data, testData);
        expect(template.introData, testData);
      });

      test('has default values', () {
        const template = DigitalMirror(data: testData);

        expect(template.blurIntensity, 20.0);
        expect(template.showBreathing, isTrue);
        expect(template.profileShape, ProfileShape.circle);
      });

      test('accepts custom values', () {
        const template = DigitalMirror(
          data: testData,
          blurIntensity: 30.0,
          showBreathing: false,
          profileShape: ProfileShape.hexagon,
        );

        expect(template.blurIntensity, 30.0);
        expect(template.showBreathing, isFalse);
        expect(template.profileShape, ProfileShape.hexagon);
      });

      test('accepts theme', () {
        const template = DigitalMirror(
          data: testData,
          theme: TemplateTheme.midnight,
        );

        expect(template.theme, isNotNull);
      });

      test('accepts timing', () {
        const template = DigitalMirror(
          data: testData,
          timing: TemplateTiming.dramatic,
        );

        expect(template.timing, TemplateTiming.dramatic);
      });
    });

    group('template properties', () {
      test('recommendedLength is 150 frames', () {
        const template = DigitalMirror(data: testData);
        expect(template.recommendedLength, 150);
      });

      test('category is intro', () {
        const template = DigitalMirror(data: testData);
        expect(template.category, TemplateCategory.intro);
      });

      test('description is set', () {
        const template = DigitalMirror(data: testData);
        expect(template.description, isNotEmpty);
        expect(template.description, contains('breathing'));
      });

      test('defaultTheme is midnight', () {
        const template = DigitalMirror(data: testData);
        expect(template.defaultTheme, TemplateTheme.midnight);
      });
    });

    group('introData getter', () {
      test('returns data cast to IntroData', () {
        const template = DigitalMirror(data: testData);
        expect(template.introData, testData);
        expect(template.introData.title, 'Your Story');
        expect(template.introData.userName, 'John');
      });
    });

    group('widget rendering', () {
      testWidgets('renders without error', (tester) async {
        const template = DigitalMirror(data: testData);
        await tester.pumpWidget(wrapWithApp(template));

        expect(find.byType(DigitalMirror), findsOneWidget);
      });

      testWidgets('displays title text', (tester) async {
        const template = DigitalMirror(data: testData);
        await tester.pumpWidget(wrapWithApp(template, frame: 100));

        expect(find.text('Your Story'), findsWidgets);
      });

      testWidgets('displays username when provided', (tester) async {
        const template = DigitalMirror(data: testData);
        await tester.pumpWidget(wrapWithApp(template, frame: 100));

        expect(find.text('Hey, John'), findsWidgets);
      });

      testWidgets('displays subtitle when provided', (tester) async {
        const template = DigitalMirror(data: testData);
        await tester.pumpWidget(wrapWithApp(template, frame: 120));

        expect(find.text('Begins Here'), findsWidgets);
      });

      testWidgets('renders without username', (tester) async {
        const dataNoUser = IntroData(title: 'Test');
        const template = DigitalMirror(data: dataNoUser);
        await tester.pumpWidget(wrapWithApp(template));

        expect(find.byType(DigitalMirror), findsOneWidget);
      });

      testWidgets('renders with breathing disabled', (tester) async {
        const template = DigitalMirror(
          data: testData,
          showBreathing: false,
        );
        await tester.pumpWidget(wrapWithApp(template));

        expect(find.byType(DigitalMirror), findsOneWidget);
      });
    });

    group('profile shapes', () {
      testWidgets('renders with circle shape', (tester) async {
        const template = DigitalMirror(
          data: testData,
          profileShape: ProfileShape.circle,
        );
        await tester.pumpWidget(wrapWithApp(template));

        expect(find.byType(DigitalMirror), findsOneWidget);
      });

      testWidgets('renders with rounded square shape', (tester) async {
        const template = DigitalMirror(
          data: testData,
          profileShape: ProfileShape.roundedSquare,
        );
        await tester.pumpWidget(wrapWithApp(template));

        expect(find.byType(DigitalMirror), findsOneWidget);
      });

      testWidgets('renders with hexagon shape', (tester) async {
        const template = DigitalMirror(
          data: testData,
          profileShape: ProfileShape.hexagon,
        );
        await tester.pumpWidget(wrapWithApp(template));

        expect(find.byType(DigitalMirror), findsOneWidget);
      });
    });

    group('toScene', () {
      test('creates scene with correct duration', () {
        const template = DigitalMirror(data: testData);
        final scene = template.toScene();

        expect(scene.durationInFrames, 150);
      });

      test('creates scene with custom duration', () {
        const template = DigitalMirror(data: testData);
        final scene = template.toScene(durationInFrames: 200);

        expect(scene.durationInFrames, 200);
      });
    });

    group('animation frames', () {
      testWidgets('renders correctly at frame 0', (tester) async {
        const template = DigitalMirror(data: testData);
        await tester.pumpWidget(wrapWithApp(template, frame: 0));

        expect(find.byType(DigitalMirror), findsOneWidget);
      });

      testWidgets('renders correctly at mid frame', (tester) async {
        const template = DigitalMirror(data: testData);
        await tester.pumpWidget(wrapWithApp(template, frame: 75));

        expect(find.byType(DigitalMirror), findsOneWidget);
      });

      testWidgets('renders correctly at end frame', (tester) async {
        const template = DigitalMirror(data: testData);
        await tester.pumpWidget(wrapWithApp(template, frame: 150));

        expect(find.byType(DigitalMirror), findsOneWidget);
      });
    });

    group('blur intensity variations', () {
      testWidgets('renders with low blur', (tester) async {
        const template = DigitalMirror(data: testData, blurIntensity: 5.0);
        await tester.pumpWidget(wrapWithApp(template));

        expect(find.byType(DigitalMirror), findsOneWidget);
      });

      testWidgets('renders with high blur', (tester) async {
        const template = DigitalMirror(data: testData, blurIntensity: 50.0);
        await tester.pumpWidget(wrapWithApp(template));

        expect(find.byType(DigitalMirror), findsOneWidget);
      });
    });

    group('theme variations', () {
      testWidgets('renders with midnight theme', (tester) async {
        const template = DigitalMirror(
          data: testData,
          theme: TemplateTheme.midnight,
        );
        await tester.pumpWidget(wrapWithApp(template));

        expect(find.byType(DigitalMirror), findsOneWidget);
      });

      testWidgets('renders with neon theme', (tester) async {
        const template = DigitalMirror(
          data: testData,
          theme: TemplateTheme.neon,
        );
        await tester.pumpWidget(wrapWithApp(template));

        expect(find.byType(DigitalMirror), findsOneWidget);
      });
    });

    group('edge cases', () {
      testWidgets('handles empty title', (tester) async {
        const emptyData = IntroData(title: '');
        const template = DigitalMirror(data: emptyData);
        await tester.pumpWidget(wrapWithApp(template));

        expect(find.byType(DigitalMirror), findsOneWidget);
      });

      testWidgets('handles very long title', (tester) async {
        const longData = IntroData(
          title: 'This is a very long title that might overflow',
        );
        const template = DigitalMirror(data: longData);
        await tester.pumpWidget(wrapWithApp(template));

        expect(find.byType(DigitalMirror), findsOneWidget);
      });

      testWidgets('handles special characters', (tester) async {
        const specialData = IntroData(title: '🎵 Your 2024! 🎵');
        const template = DigitalMirror(data: specialData);
        await tester.pumpWidget(wrapWithApp(template));

        expect(find.byType(DigitalMirror), findsOneWidget);
      });
    });
  });

  group('ProfileShape', () {
    test('has all expected shapes', () {
      expect(ProfileShape.values, hasLength(3));
      expect(ProfileShape.values, contains(ProfileShape.circle));
      expect(ProfileShape.values, contains(ProfileShape.roundedSquare));
      expect(ProfileShape.values, contains(ProfileShape.hexagon));
    });
  });
}
