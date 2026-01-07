import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/declarative/background/background.dart';
import '../../../helpers/test_helpers.dart';

void main() {
  group('Background', () {
    group('SolidBackground', () {
      test('creates with color', () {
        const background = SolidBackground(Colors.red);
        expect(background.color, Colors.red);
      });

      test('Background.solid factory works', () {
        const background = Background.solid(Colors.blue);
        expect(background, isA<SolidBackground>());
        expect((background as SolidBackground).color, Colors.blue);
      });

      testWidgets('builds widget', (tester) async {
        const background = Background.solid(Colors.green);
        await tester.pumpWidget(MaterialApp(
          home: Builder(
            builder: (context) => background.build(context, 100),
          ),
        ));

        // SolidBackground builds a FadeContainer which wraps a Container
        expect(find.byType(Container), findsWidgets);
      });
    });

    group('GradientBackground', () {
      test('creates with required colors', () {
        final background = GradientBackground(
          colors: {0: Colors.red, 60: Colors.blue},
        );

        expect(background.colors.length, 2);
        expect(background.type, GradientType.linear);
      });

      test('has default values', () {
        final background = GradientBackground(colors: {0: Colors.red});

        expect(background.type, GradientType.linear);
        expect(background.begin, Alignment.topCenter);
        expect(background.end, Alignment.bottomCenter);
      });

      test('accepts custom values', () {
        final background = GradientBackground(
          colors: {0: Colors.red, 60: Colors.blue},
          type: GradientType.radial,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );

        expect(background.type, GradientType.radial);
        expect(background.begin, Alignment.topLeft);
        expect(background.end, Alignment.bottomRight);
      });

      test('Background.gradient factory works', () {
        final background = Background.gradient(
          colors: {0: Colors.red, 60: Colors.blue},
          type: GradientType.sweep,
        );

        expect(background, isA<GradientBackground>());
        final grad = background as GradientBackground;
        expect(grad.type, GradientType.sweep);
      });

      testWidgets('builds empty widget for empty colors', (tester) async {
        final background = GradientBackground(colors: {});
        await tester.pumpWidget(MaterialApp(
          home: Builder(
            builder: (context) => background.build(context, 100),
          ),
        ));

        expect(find.byType(SizedBox), findsOneWidget);
      });

      testWidgets('builds solid for single color', (tester) async {
        final background = GradientBackground(
          colors: {0: Colors.red},
        );
        await tester.pumpWidget(MaterialApp(
          home: Builder(
            builder: (context) => background.build(context, 100),
          ),
        ));

        // Single color gradient renders a FadeContainer which wraps a Container
        expect(find.byType(Container), findsWidgets);
      });

      testWidgets('builds animated gradient for multiple colors',
          (tester) async {
        final background = GradientBackground(
          colors: {0: Colors.red, 60: Colors.blue},
        );
        await tester.pumpWidget(wrapWithApp(
          Builder(
            builder: (context) => background.build(context, 100),
          ),
        ));

        expect(find.byType(Container), findsWidgets);
      });
    });

    group('ImageBackground', () {
      test('creates with required assetPath', () {
        const background = ImageBackground(assetPath: 'assets/image.png');
        expect(background.assetPath, 'assets/image.png');
      });

      test('has default fit', () {
        const background = ImageBackground(assetPath: 'assets/image.png');
        expect(background.fit, BoxFit.cover);
      });

      test('accepts custom fit', () {
        const background = ImageBackground(
          assetPath: 'assets/image.png',
          fit: BoxFit.contain,
        );
        expect(background.fit, BoxFit.contain);
      });

      test('Background.image factory works', () {
        const background = Background.image(assetPath: 'assets/test.png');
        expect(background, isA<ImageBackground>());
      });
    });

    group('VideoBackground', () {
      test('creates with required assetPath', () {
        const background = VideoBackground(assetPath: 'assets/video.mp4');
        expect(background.assetPath, 'assets/video.mp4');
      });

      test('has default fit', () {
        const background = VideoBackground(assetPath: 'assets/video.mp4');
        expect(background.fit, BoxFit.cover);
      });

      test('accepts custom fit', () {
        const background = VideoBackground(
          assetPath: 'assets/video.mp4',
          fit: BoxFit.fill,
        );
        expect(background.fit, BoxFit.fill);
      });

      test('Background.video factory works', () {
        const background = Background.video(assetPath: 'assets/test.mp4');
        expect(background, isA<VideoBackground>());
      });

      testWidgets('builds placeholder', (tester) async {
        const background = VideoBackground(assetPath: 'assets/video.mp4');
        await tester.pumpWidget(MaterialApp(
          home: Builder(
            builder: (context) => background.build(context, 100),
          ),
        ));

        expect(find.text('Video Background'), findsOneWidget);
      });
    });

    group('RadialBackground', () {
      test('creates with required colors', () {
        const background = RadialBackground(
          centerColor: Colors.white,
          edgeColor: Colors.black,
        );

        expect(background.centerColor, Colors.white);
        expect(background.edgeColor, Colors.black);
      });

      test('has default center', () {
        const background = RadialBackground(
          centerColor: Colors.white,
          edgeColor: Colors.black,
        );

        expect(background.center, Alignment.center);
      });

      test('accepts custom center', () {
        const background = RadialBackground(
          centerColor: Colors.white,
          edgeColor: Colors.black,
          center: Alignment.topLeft,
        );

        expect(background.center, Alignment.topLeft);
      });

      test('Background.radial factory works', () {
        final background = Background.radial(
          centerColor: Colors.purple,
          edgeColor: Colors.black,
        );

        expect(background, isA<RadialBackground>());
      });

      testWidgets('builds radial gradient container', (tester) async {
        const background = RadialBackground(
          centerColor: Colors.white,
          edgeColor: Colors.black,
        );

        await tester.pumpWidget(MaterialApp(
          home: Builder(
            builder: (context) => background.build(context, 100),
          ),
        ));

        expect(find.byType(Container), findsOneWidget);
      });
    });

    group('convenience constructors', () {
      test('darkOverlay creates solid background', () {
        final background = Background.darkOverlay(opacity: 0.5);
        expect(background, isA<SolidBackground>());
        final solid = background as SolidBackground;
        expect(solid.color.a, closeTo(0.5, 0.01));
      });

      test('darkOverlay has default opacity', () {
        final background = Background.darkOverlay();
        expect(background, isA<SolidBackground>());
        final solid = background as SolidBackground;
        expect(solid.color.a, closeTo(0.4, 0.01));
      });

      test('cinemaBlack creates gradient background', () {
        final background = Background.cinemaBlack();
        expect(background, isA<GradientBackground>());
      });
    });

    group('GradientType', () {
      test('has all expected types', () {
        expect(GradientType.values, hasLength(3));
        expect(GradientType.values, contains(GradientType.linear));
        expect(GradientType.values, contains(GradientType.radial));
        expect(GradientType.values, contains(GradientType.sweep));
      });
    });
  });
}
