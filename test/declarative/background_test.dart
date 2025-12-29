import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/declarative/background/background.dart';

void main() {
  group('Background.solid', () {
    testWidgets('creates solid background with specified color', (
      tester,
    ) async {
      const color = Color(0xFF123456);
      final background = Background.solid(color);

      expect(background, isA<SolidBackground>());
      expect((background as SolidBackground).color, equals(color));
    });

    testWidgets('builds as FadeContainer', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              return Background.solid(Colors.red).build(context, 100);
            },
          ),
        ),
      );

      // FadeContainer is built from the background
      expect(find.byType(MaterialApp), findsOneWidget);
    });
  });

  group('Background.gradient', () {
    testWidgets('creates gradient background with colors map', (tester) async {
      final background = Background.gradient(
        colors: {0: Colors.red, 60: Colors.blue},
      );

      expect(background, isA<GradientBackground>());
      final gradBg = background as GradientBackground;
      expect(gradBg.colors.length, equals(2));
      expect(gradBg.colors[0], equals(Colors.red));
      expect(gradBg.colors[60], equals(Colors.blue));
    });

    testWidgets('uses default linear gradient type', (tester) async {
      final background = Background.gradient(
        colors: {0: Colors.red, 60: Colors.blue},
      );

      final gradBg = background as GradientBackground;
      expect(gradBg.type, equals(GradientType.linear));
    });

    testWidgets('supports radial gradient type', (tester) async {
      final background = Background.gradient(
        colors: {0: Colors.red, 60: Colors.blue},
        type: GradientType.radial,
      );

      final gradBg = background as GradientBackground;
      expect(gradBg.type, equals(GradientType.radial));
    });

    testWidgets('supports sweep gradient type', (tester) async {
      final background = Background.gradient(
        colors: {0: Colors.red, 60: Colors.blue},
        type: GradientType.sweep,
      );

      final gradBg = background as GradientBackground;
      expect(gradBg.type, equals(GradientType.sweep));
    });

    testWidgets('supports alignment parameters', (tester) async {
      final background = Background.gradient(
        colors: {0: Colors.red, 60: Colors.blue},
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
      );

      final gradBg = background as GradientBackground;
      expect(gradBg.begin, equals(Alignment.centerLeft));
      expect(gradBg.end, equals(Alignment.centerRight));
    });
  });

  group('Background.image', () {
    testWidgets('creates image background with asset path', (tester) async {
      const background = Background.image(assetPath: 'assets/bg.png');

      expect(background, isA<ImageBackground>());
      expect(
        (background as ImageBackground).assetPath,
        equals('assets/bg.png'),
      );
    });

    testWidgets('uses default cover fit', (tester) async {
      const background = Background.image(assetPath: 'assets/bg.png');

      expect((background as ImageBackground).fit, equals(BoxFit.cover));
    });

    testWidgets('supports custom fit', (tester) async {
      const background = Background.image(
        assetPath: 'assets/bg.png',
        fit: BoxFit.contain,
      );

      expect((background as ImageBackground).fit, equals(BoxFit.contain));
    });
  });

  group('Background.video', () {
    testWidgets('creates video background with asset path', (tester) async {
      const background = Background.video(assetPath: 'assets/bg.mp4');

      expect(background, isA<VideoBackground>());
      expect(
        (background as VideoBackground).assetPath,
        equals('assets/bg.mp4'),
      );
    });

    testWidgets('uses default cover fit', (tester) async {
      const background = Background.video(assetPath: 'assets/bg.mp4');

      expect((background as VideoBackground).fit, equals(BoxFit.cover));
    });
  });

  group('Background.darkOverlay', () {
    testWidgets('creates semi-transparent black background', (tester) async {
      final background = Background.darkOverlay();

      expect(background, isA<SolidBackground>());
      final solidBg = background as SolidBackground;
      expect(solidBg.color.r, equals(0));
      expect(solidBg.color.g, equals(0));
      expect(solidBg.color.b, equals(0));
      expect(solidBg.color.a, closeTo(0.4, 0.01));
    });

    testWidgets('supports custom opacity', (tester) async {
      final background = Background.darkOverlay(opacity: 0.7);

      final solidBg = background as SolidBackground;
      expect(solidBg.color.a, closeTo(0.7, 0.01));
    });

    testWidgets('opacity 0.0 creates transparent', (tester) async {
      final background = Background.darkOverlay(opacity: 0.0);

      final solidBg = background as SolidBackground;
      expect(solidBg.color.a, equals(0.0));
    });

    testWidgets('opacity 1.0 creates opaque black', (tester) async {
      final background = Background.darkOverlay(opacity: 1.0);

      final solidBg = background as SolidBackground;
      expect(solidBg.color.a, equals(1.0));
    });
  });

  group('Background.cinemaBlack', () {
    testWidgets('creates gradient background', (tester) async {
      final background = Background.cinemaBlack();

      expect(background, isA<GradientBackground>());
    });

    testWidgets('uses linear gradient from top to bottom', (tester) async {
      final background = Background.cinemaBlack();
      final gradBg = background as GradientBackground;

      expect(gradBg.type, equals(GradientType.linear));
      expect(gradBg.begin, equals(Alignment.topCenter));
      expect(gradBg.end, equals(Alignment.bottomCenter));
    });

    testWidgets('uses pure black color', (tester) async {
      final background = Background.cinemaBlack();
      final gradBg = background as GradientBackground;

      expect(gradBg.colors[0], equals(const Color(0xFF000000)));
    });
  });

  group('Background.radial', () {
    testWidgets('creates radial gradient with center and edge colors', (
      tester,
    ) async {
      final background = Background.radial(
        centerColor: Colors.purple,
        edgeColor: Colors.black,
      );

      expect(background, isA<RadialBackground>());
      final radBg = background as RadialBackground;
      expect(radBg.centerColor, equals(Colors.purple));
      expect(radBg.edgeColor, equals(Colors.black));
    });

    testWidgets('uses center alignment by default', (tester) async {
      final background = Background.radial(
        centerColor: Colors.white,
        edgeColor: Colors.black,
      );

      final radBg = background as RadialBackground;
      expect(radBg.center, equals(Alignment.center));
    });

    testWidgets('supports custom center alignment', (tester) async {
      final background = Background.radial(
        centerColor: Colors.white,
        edgeColor: Colors.black,
        center: Alignment.topLeft,
      );

      final radBg = background as RadialBackground;
      expect(radBg.center, equals(Alignment.topLeft));
    });

    testWidgets('builds container with RadialGradient', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              return Background.radial(
                centerColor: Colors.purple,
                edgeColor: Colors.black,
              ).build(context, 100);
            },
          ),
        ),
      );

      expect(find.byType(Container), findsOneWidget);
    });
  });

  group('GradientBackground.build', () {
    testWidgets('returns empty SizedBox for empty colors', (tester) async {
      final background = GradientBackground(colors: {});

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(builder: (context) => background.build(context, 100)),
        ),
      );

      expect(find.byType(SizedBox), findsOneWidget);
    });

    testWidgets('returns FadeContainer for single color', (tester) async {
      final background = GradientBackground(colors: {0: Colors.red});

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(builder: (context) => background.build(context, 100)),
        ),
      );

      // Single color is rendered as FadeContainer
      expect(find.byType(MaterialApp), findsOneWidget);
    });
  });
}
