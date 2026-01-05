import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/declarative.dart';
import 'package:fluvie/src/presentation/time_consumer.dart';
import 'package:fluvie/src/presentation/video_preview.dart';

void main() {
  group('VideoPreviewController', () {
    test('initial state is correct', () {
      final controller = VideoPreviewController();

      expect(controller.currentFrame, 0);
      expect(controller.totalFrames, 0);
      expect(controller.isPlaying, false);
      expect(controller.isExporting, false);
      expect(controller.exportProgress, 0.0);
      expect(controller.progress, 0.0);

      controller.dispose();
    });

    test('notifies listeners on frame update', () {
      final controller = VideoPreviewController();
      int notifyCount = 0;
      controller.addListener(() => notifyCount++);

      controller.updateFrame(10);

      expect(notifyCount, 1);
      expect(controller.currentFrame, 10);

      controller.dispose();
    });

    test('notifies listeners on playing state change', () {
      final controller = VideoPreviewController();
      int notifyCount = 0;
      controller.addListener(() => notifyCount++);

      controller.updatePlayingState(true);

      expect(notifyCount, 1);
      expect(controller.isPlaying, true);

      controller.updatePlayingState(false);
      expect(notifyCount, 2);
      expect(controller.isPlaying, false);

      controller.dispose();
    });

    test('export progress updates correctly', () {
      final controller = VideoPreviewController();
      int notifyCount = 0;
      controller.addListener(() => notifyCount++);

      controller.setExporting(true);
      expect(controller.isExporting, true);
      expect(notifyCount, 1);

      controller.updateExportProgress(0.5);
      expect(controller.exportProgress, 0.5);
      expect(notifyCount, 2);

      controller.setExporting(false);
      expect(controller.isExporting, false);
      expect(controller.exportProgress, 0.0); // Reset on stop
      expect(notifyCount, 3);

      controller.dispose();
    });

    test('progress clamps to valid range', () {
      final controller = VideoPreviewController();

      controller.updateExportProgress(-0.5);
      expect(controller.exportProgress, 0.0);

      controller.updateExportProgress(1.5);
      expect(controller.exportProgress, 1.0);

      controller.dispose();
    });
  });

  group('VideoPreview', () {
    Video buildTestVideo() {
      return const Video(
        fps: 30,
        width: 640,
        height: 480,
        scenes: [
          Scene(
            durationInFrames: 60,
            background: Background.solid(Colors.blue),
            children: [Center(child: Text('Test'))],
          ),
        ],
      );
    }

    testWidgets('renders video at correct dimensions', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VideoPreview(video: buildTestVideo(), autoPlay: false),
          ),
        ),
      );

      // Find the SizedBox that contains the video
      final sizedBoxes = tester.widgetList<SizedBox>(find.byType(SizedBox));
      final videoSizedBox = sizedBoxes.firstWhere(
        (box) => box.width == 640 && box.height == 480,
        orElse: () => throw Exception('Video SizedBox not found'),
      );

      expect(videoSizedBox.width, 640);
      expect(videoSizedBox.height, 480);
    });

    testWidgets('uses FrameProvider internally', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VideoPreview(video: buildTestVideo(), autoPlay: false),
          ),
        ),
      );

      expect(find.byType(FrameProvider), findsOneWidget);
    });

    testWidgets('does not show controls by default', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VideoPreview(video: buildTestVideo(), autoPlay: false),
          ),
        ),
      );

      // Play button should not be present
      expect(find.byIcon(Icons.play_arrow), findsNothing);
      expect(find.byIcon(Icons.pause), findsNothing);
      expect(find.byType(Slider), findsNothing);
    });

    testWidgets('shows controls when showControls is true', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VideoPreview(
              video: buildTestVideo(),
              autoPlay: false,
              showControls: true,
            ),
          ),
        ),
      );

      // Play button should be present (not playing by default when autoPlay: false)
      expect(find.byIcon(Icons.play_arrow), findsOneWidget);
      expect(find.byType(Slider), findsOneWidget);
    });

    testWidgets('shows export button when showExportButton is true', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VideoPreview(
              video: buildTestVideo(),
              autoPlay: false,
              showExportButton: true,
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.download), findsOneWidget);
    });

    testWidgets('uses provided controller', (tester) async {
      final controller = VideoPreviewController();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VideoPreview(
              video: buildTestVideo(),
              autoPlay: false,
              controller: controller,
            ),
          ),
        ),
      );

      // Controller should be bound
      expect(controller.totalFrames, 60);

      controller.dispose();
    });

    testWidgets('controller.seekTo updates frame', (tester) async {
      final controller = VideoPreviewController();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VideoPreview(
              video: buildTestVideo(),
              autoPlay: false,
              controller: controller,
            ),
          ),
        ),
      );

      expect(controller.currentFrame, 0);

      controller.seekTo(30);
      await tester.pump();

      expect(controller.currentFrame, 30);

      controller.dispose();
    });

    testWidgets('play button toggles to pause when playing', (tester) async {
      final controller = VideoPreviewController();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VideoPreview(
              video: buildTestVideo(),
              autoPlay: false,
              showControls: true,
              controller: controller,
            ),
          ),
        ),
      );

      // Initially shows play button
      expect(find.byIcon(Icons.play_arrow), findsOneWidget);
      expect(find.byIcon(Icons.pause), findsNothing);

      // Start playing
      controller.play();
      await tester.pump();

      // Now shows pause button
      expect(find.byIcon(Icons.pause), findsOneWidget);
      expect(find.byIcon(Icons.play_arrow), findsNothing);

      controller.dispose();
    });

    testWidgets('calls onFrameUpdate callback', (tester) async {
      final controller = VideoPreviewController();
      final frameUpdates = <(int, int)>[];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VideoPreview(
              video: buildTestVideo(),
              autoPlay: false,
              controller: controller,
              onFrameUpdate: (frame, total) {
                frameUpdates.add((frame, total));
              },
            ),
          ),
        ),
      );

      controller.seekTo(15);
      await tester.pump();

      expect(frameUpdates.length, greaterThan(0));
      expect(frameUpdates.last.$1, 15);
      expect(frameUpdates.last.$2, 60);

      controller.dispose();
    });

    testWidgets('applies backgroundColor', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VideoPreview(
              video: buildTestVideo(),
              autoPlay: false,
              backgroundColor: Colors.red,
            ),
          ),
        ),
      );

      final container = tester.widget<Container>(find.byType(Container).first);

      // Container uses color property directly
      expect(container.color, Colors.red);
    });

    testWidgets('disposes internal controller when not provided', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VideoPreview(video: buildTestVideo(), autoPlay: false),
          ),
        ),
      );

      // Just verify it doesn't throw when widget is disposed
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('does not dispose provided controller', (tester) async {
      final controller = VideoPreviewController();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VideoPreview(
              video: buildTestVideo(),
              autoPlay: false,
              controller: controller,
            ),
          ),
        ),
      );

      await tester.pumpWidget(const SizedBox.shrink());

      // Controller should still be usable
      expect(() => controller.currentFrame, returnsNormally);

      controller.dispose();
    });
  });

  group('VideoPreviewControlsStyle', () {
    test('has sensible defaults', () {
      const style = VideoPreviewControlsStyle();

      expect(style.backgroundColor, isNotNull);
      expect(style.iconColor, Colors.white);
      expect(style.height, 56);
    });

    test('can be customized', () {
      const style = VideoPreviewControlsStyle(
        backgroundColor: Colors.blue,
        iconColor: Colors.yellow,
        activeColor: Colors.green,
        height: 80,
      );

      expect(style.backgroundColor, Colors.blue);
      expect(style.iconColor, Colors.yellow);
      expect(style.activeColor, Colors.green);
      expect(style.height, 80);
    });
  });
}
