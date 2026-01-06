import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/domain/render_config.dart';
import 'package:fluvie/src/presentation/render_controller.dart';
import 'package:fluvie/src/presentation/video_composition.dart';

void main() {
  group('RenderController', () {
    late RenderController controller;

    setUp(() {
      controller = RenderController();
    });

    tearDown(() {
      controller.dispose();
    });

    group('initial state', () {
      test('currentFrame starts at 0', () {
        expect(controller.currentFrame, 0);
      });

      test('isRendering starts as false', () {
        expect(controller.isRendering, isFalse);
      });

      test('hasComposition starts as false', () {
        expect(controller.hasComposition, isFalse);
      });

      test('config is null without composition', () {
        expect(controller.config, isNull);
      });

      test('timeline is null without composition', () {
        expect(controller.timeline, isNull);
      });

      test('durationInFrames returns 0 without composition', () {
        expect(controller.durationInFrames, 0);
      });

      test('fps returns 30 without composition', () {
        expect(controller.fps, 30);
      });

      test('progress returns 0.0 without composition', () {
        expect(controller.progress, 0.0);
      });

      test('boundaryKey is not null', () {
        expect(controller.boundaryKey, isNotNull);
      });

      test('frameReadyNotifier is not null', () {
        expect(controller.frameReadyNotifier, isNotNull);
      });
    });

    group('setFrame', () {
      test('updates currentFrame', () {
        controller.setFrame(50);
        expect(controller.currentFrame, 50);
      });

      test('notifies listeners on frame change', () {
        var notified = false;
        controller.addListener(() => notified = true);

        controller.setFrame(10);

        expect(notified, isTrue);
      });

      test('does not notify if frame unchanged', () {
        controller.setFrame(10);

        var notified = false;
        controller.addListener(() => notified = true);

        controller.setFrame(10);

        expect(notified, isFalse);
      });
    });

    group('reset', () {
      test('sets frame to 0', () {
        controller.setFrame(100);
        controller.reset();
        expect(controller.currentFrame, 0);
      });
    });

    group('startRendering / stopRendering', () {
      test('startRendering sets isRendering to true', () {
        controller.startRendering();
        expect(controller.isRendering, isTrue);
      });

      test('stopRendering sets isRendering to false', () {
        controller.startRendering();
        controller.stopRendering();
        expect(controller.isRendering, isFalse);
      });

      test('startRendering notifies listeners', () {
        var notified = false;
        controller.addListener(() => notified = true);

        controller.startRendering();

        expect(notified, isTrue);
      });

      test('stopRendering notifies listeners', () {
        controller.startRendering();

        var notified = false;
        controller.addListener(() => notified = true);

        controller.stopRendering();

        expect(notified, isTrue);
      });
    });

    group('attach / detach', () {
      test('attach sets hasComposition to true', () {
        controller.attach(_createCompositionData());
        expect(controller.hasComposition, isTrue);
      });

      test('attach updates timeline', () {
        controller.attach(_createCompositionData(fps: 60, duration: 300));
        expect(controller.timeline, isNotNull);
        expect(controller.fps, 60);
        expect(controller.durationInFrames, 300);
      });

      test('attach creates valid config', () {
        controller.attach(_createCompositionData());
        expect(controller.config, isA<RenderConfig>());
      });

      test('detach sets hasComposition to false', () {
        controller.attach(_createCompositionData());
        controller.detach();
        expect(controller.hasComposition, isFalse);
      });

      test('detach clears config', () {
        controller.attach(_createCompositionData());
        controller.detach();
        expect(controller.config, isNull);
      });

      test('attach notifies listeners', () {
        var notified = false;
        controller.addListener(() => notified = true);

        controller.attach(_createCompositionData());

        expect(notified, isTrue);
      });

      test('detach notifies listeners', () {
        controller.attach(_createCompositionData());

        var notified = false;
        controller.addListener(() => notified = true);

        controller.detach();

        expect(notified, isTrue);
      });
    });

    group('progress', () {
      test('returns 0.0 at frame 0', () {
        controller.attach(_createCompositionData(duration: 100));
        controller.setFrame(0);
        expect(controller.progress, 0.0);
      });

      test('returns 0.5 at midpoint', () {
        controller.attach(_createCompositionData(duration: 100));
        controller.setFrame(50);
        expect(controller.progress, 0.5);
      });

      test('returns 1.0 at end', () {
        controller.attach(_createCompositionData(duration: 100));
        controller.setFrame(100);
        expect(controller.progress, 1.0);
      });

      test('returns 0.0 when durationInFrames is 0', () {
        controller.attach(_createCompositionData(duration: 0));
        controller.setFrame(0);
        expect(controller.progress, 0.0);
      });
    });
  });

  group('RenderCompositionData', () {
    test('creates with required fields', () {
      final data = RenderCompositionData(
        timeline: TimelineConfig(
          fps: 30,
          durationInFrames: 150,
          width: 1920,
          height: 1080,
        ),
      );

      expect(data.timeline.fps, 30);
      expect(data.timeline.durationInFrames, 150);
      expect(data.sequences, isEmpty);
      expect(data.audioTracks, isEmpty);
    });

    test('toRenderConfig creates valid config', () {
      final data = RenderCompositionData(
        timeline: TimelineConfig(
          fps: 60,
          durationInFrames: 300,
          width: 1280,
          height: 720,
        ),
      );

      final config = data.toRenderConfig();

      expect(config.timeline.fps, 60);
      expect(config.timeline.durationInFrames, 300);
      expect(config.timeline.width, 1280);
      expect(config.timeline.height, 720);
    });
  });

  group('RenderableComposition', () {
    late RenderController controller;

    setUp(() {
      controller = RenderController();
    });

    tearDown(() {
      controller.dispose();
    });

    testWidgets('attaches controller on init', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: RenderableComposition(
            controller: controller,
            composition: const VideoComposition(
              fps: 30,
              durationInFrames: 150,
              width: 1920,
              height: 1080,
              child: SizedBox(),
            ),
          ),
        ),
      );

      expect(controller.hasComposition, isTrue);
      expect(controller.fps, 30);
      expect(controller.durationInFrames, 150);
    });

    testWidgets('detaches controller on dispose', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: RenderableComposition(
            controller: controller,
            composition: const VideoComposition(
              fps: 30,
              durationInFrames: 150,
              width: 1920,
              height: 1080,
              child: SizedBox(),
            ),
          ),
        ),
      );

      expect(controller.hasComposition, isTrue);

      await tester.pumpWidget(const MaterialApp(home: SizedBox()));

      expect(controller.hasComposition, isFalse);
    });

    testWidgets('renders composition child', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: RenderableComposition(
            controller: controller,
            composition: const VideoComposition(
              fps: 30,
              durationInFrames: 150,
              width: 400,
              height: 300,
              child: Text('Test Content'),
            ),
          ),
        ),
      );

      expect(find.text('Test Content'), findsOneWidget);
    });

    testWidgets('creates RepaintBoundary with controller key', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: RenderableComposition(
            controller: controller,
            composition: const VideoComposition(
              fps: 30,
              durationInFrames: 150,
              width: 400,
              height: 300,
              child: SizedBox(),
            ),
          ),
        ),
      );

      expect(find.byKey(controller.boundaryKey), findsOneWidget);
    });

    testWidgets('default previewMode is fit', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: RenderableComposition(
            controller: controller,
            composition: const VideoComposition(
              fps: 30,
              durationInFrames: 150,
              width: 400,
              height: 300,
              child: SizedBox(),
            ),
          ),
        ),
      );

      expect(find.byType(FittedBox), findsOneWidget);
    });

    testWidgets('previewMode.scroll creates scrollable', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: RenderableComposition(
            controller: controller,
            previewMode: PreviewMode.scroll,
            composition: const VideoComposition(
              fps: 30,
              durationInFrames: 150,
              width: 4000,
              height: 3000,
              child: SizedBox(),
            ),
          ),
        ),
      );

      expect(find.byType(SingleChildScrollView), findsWidgets);
    });

    testWidgets('previewMode.actual shows at actual size', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: RenderableComposition(
            controller: controller,
            previewMode: PreviewMode.actual,
            composition: const VideoComposition(
              fps: 30,
              durationInFrames: 150,
              width: 400,
              height: 300,
              child: SizedBox(),
            ),
          ),
        ),
      );

      expect(find.byType(FittedBox), findsNothing);
      expect(find.byType(SingleChildScrollView), findsNothing);
    });

    testWidgets('responds to frame updates', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: RenderableComposition(
            controller: controller,
            composition: const VideoComposition(
              fps: 30,
              durationInFrames: 150,
              width: 400,
              height: 300,
              child: SizedBox(),
            ),
          ),
        ),
      );

      controller.setFrame(50);
      await tester.pump();

      expect(controller.currentFrame, 50);
    });
  });

  group('PreviewMode', () {
    test('has fit mode', () {
      expect(PreviewMode.fit, isNotNull);
    });

    test('has scroll mode', () {
      expect(PreviewMode.scroll, isNotNull);
    });

    test('has actual mode', () {
      expect(PreviewMode.actual, isNotNull);
    });

    test('all modes are distinct', () {
      expect(PreviewMode.fit, isNot(equals(PreviewMode.scroll)));
      expect(PreviewMode.fit, isNot(equals(PreviewMode.actual)));
      expect(PreviewMode.scroll, isNot(equals(PreviewMode.actual)));
    });
  });
}

RenderCompositionData _createCompositionData({
  int fps = 30,
  int duration = 150,
  int width = 1920,
  int height = 1080,
}) {
  return RenderCompositionData(
    timeline: TimelineConfig(
      fps: fps,
      durationInFrames: duration,
      width: width,
      height: height,
    ),
  );
}
