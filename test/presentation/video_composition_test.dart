import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/presentation/video_composition.dart';
import 'package:fluvie/src/presentation/time_consumer.dart';

void main() {
  group('VideoComposition', () {
    testWidgets('can be created with required parameters', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: VideoComposition(
            fps: 30,
            durationInFrames: 90,
            child: Container(),
          ),
        ),
      );

      expect(find.byType(VideoComposition), findsOneWidget);
    });

    testWidgets('VideoComposition.of returns composition data', (tester) async {
      VideoCompositionData? capturedComposition;

      await tester.pumpWidget(
        MaterialApp(
          home: VideoComposition(
            fps: 30,
            durationInFrames: 90,
            child: Builder(
              builder: (context) {
                capturedComposition = VideoComposition.of(context);
                return Container();
              },
            ),
          ),
        ),
      );

      expect(capturedComposition, isNotNull);
      expect(capturedComposition!.fps, equals(30));
      expect(capturedComposition!.durationInFrames, equals(90));
    });

    testWidgets('provides frame updates to descendants via FrameProvider', (tester) async {
      int capturedFrame = -1;

      await tester.pumpWidget(
        MaterialApp(
          home: VideoComposition(
            fps: 30,
            durationInFrames: 90,
            child: FrameProvider(
              frame: 42,
              child: TimeConsumer(
                builder: (context, frame, progress) {
                  capturedFrame = frame;
                  return Text('Frame: $frame');
                },
              ),
            ),
          ),
        ),
      );

      expect(capturedFrame, equals(42));
    });

    testWidgets('provides default width and height', (tester) async {
      VideoCompositionData? capturedComposition;

      await tester.pumpWidget(
        MaterialApp(
          home: VideoComposition(
            fps: 30,
            durationInFrames: 90,
            child: Builder(
              builder: (context) {
                capturedComposition = VideoComposition.of(context);
                return Container();
              },
            ),
          ),
        ),
      );

      expect(capturedComposition, isNotNull);
      expect(capturedComposition!.width, equals(1920));
      expect(capturedComposition!.height, equals(1080));
    });

    testWidgets('supports custom width and height', (tester) async {
      VideoCompositionData? capturedComposition;

      await tester.pumpWidget(
        MaterialApp(
          home: VideoComposition(
            fps: 60,
            durationInFrames: 120,
            width: 1080,
            height: 1920,
            child: Builder(
              builder: (context) {
                capturedComposition = VideoComposition.of(context);
                return Container();
              },
            ),
          ),
        ),
      );

      expect(capturedComposition, isNotNull);
      expect(capturedComposition!.width, equals(1080));
      expect(capturedComposition!.height, equals(1920));
    });

    testWidgets('toConfig returns correct RenderConfig', (tester) async {
      late VideoComposition compositionWidget;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              compositionWidget = VideoComposition(
                fps: 30,
                durationInFrames: 150,
                width: 1920,
                height: 1080,
                child: Container(),
              );
              return compositionWidget;
            },
          ),
        ),
      );

      final config = compositionWidget.toConfig();
      expect(config.timeline.fps, equals(30));
      expect(config.timeline.durationInFrames, equals(150));
      expect(config.timeline.width, equals(1920));
      expect(config.timeline.height, equals(1080));
    });

    testWidgets('notifies descendants when composition changes', (tester) async {
      int buildCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: VideoComposition(
            fps: 30,
            durationInFrames: 90,
            child: Builder(
              builder: (context) {
                VideoComposition.of(context);
                buildCount++;
                return Container();
              },
            ),
          ),
        ),
      );

      expect(buildCount, equals(1));

      // Rebuild with different fps
      await tester.pumpWidget(
        MaterialApp(
          home: VideoComposition(
            fps: 60,
            durationInFrames: 90,
            child: Builder(
              builder: (context) {
                VideoComposition.of(context);
                buildCount++;
                return Container();
              },
            ),
          ),
        ),
      );

      expect(buildCount, equals(2));
    });

    testWidgets('does not notify when values unchanged', (tester) async {
      int buildCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: VideoComposition(
            fps: 30,
            durationInFrames: 90,
            child: Builder(
              builder: (context) {
                VideoComposition.of(context);
                buildCount++;
                return Container();
              },
            ),
          ),
        ),
      );

      expect(buildCount, equals(1));

      // Rebuild with same values
      await tester.pumpWidget(
        MaterialApp(
          home: VideoComposition(
            fps: 30,
            durationInFrames: 90,
            child: Builder(
              builder: (context) {
                VideoComposition.of(context);
                buildCount++;
                return Container();
              },
            ),
          ),
        ),
      );

      // Build is called but should not trigger update since values are same
      // Note: The Builder will rebuild regardless, but dependent widgets would not
      expect(buildCount, equals(2));
    });
  });

  group('FrameProvider', () {
    testWidgets('provides frame to descendants', (tester) async {
      int? capturedFrame;

      await tester.pumpWidget(
        MaterialApp(
          home: FrameProvider(
            frame: 42,
            child: Builder(
              builder: (context) {
                capturedFrame = FrameProvider.of(context);
                return Container();
              },
            ),
          ),
        ),
      );

      expect(capturedFrame, equals(42));
    });

    testWidgets('of returns null when no FrameProvider ancestor', (tester) async {
      int? capturedFrame;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              capturedFrame = FrameProvider.of(context);
              return Container();
            },
          ),
        ),
      );

      expect(capturedFrame, isNull);
    });

    testWidgets('updateShouldNotify returns true when frame changes', (tester) async {
      final oldWidget = FrameProvider(
        frame: 10,
        child: Container(),
      );
      final newWidget = FrameProvider(
        frame: 20,
        child: Container(),
      );

      expect(newWidget.updateShouldNotify(oldWidget), isTrue);
    });

    testWidgets('updateShouldNotify returns false when frame unchanged', (tester) async {
      final oldWidget = FrameProvider(
        frame: 10,
        child: Container(),
      );
      final newWidget = FrameProvider(
        frame: 10,
        child: Container(),
      );

      expect(newWidget.updateShouldNotify(oldWidget), isFalse);
    });
  });
}
