import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/declarative.dart';
import 'package:fluvie/src/integration/video_exporter.dart';
import 'package:fluvie/src/domain/render_config.dart';

void main() {
  group('VideoExporter', () {
    Video buildTestVideo({int durationInFrames = 30}) {
      return Video(
        fps: 30,
        width: 640,
        height: 480,
        scenes: [
          Scene(
            durationInFrames: durationInFrames,
            background: const Background.solid(Colors.blue),
            children: const [Center(child: Text('Test'))],
          ),
        ],
      );
    }

    test('builds correct RenderConfig from Video', () {
      final video = buildTestVideo();
      final exporter = VideoExporter(video);

      // Access internal method via reflection-like approach
      // In a real test, we'd expose this or test through render()
      final config = exporter.buildConfig();

      expect(config.timeline.fps, 30);
      expect(config.timeline.width, 640);
      expect(config.timeline.height, 480);
      expect(config.timeline.durationInFrames, 30);
    });

    test('applies quality settings correctly', () {
      final video = buildTestVideo();
      final exporter = VideoExporter(video).withQuality(RenderQuality.high);

      final config = exporter.buildConfig();

      expect(config.encoding?.quality, RenderQuality.high);
    });

    test('applies custom encoding config', () {
      final video = buildTestVideo();
      const customEncoding = EncodingConfig(
        quality: RenderQuality.lossless,
        frameFormat: FrameFormat.png,
      );
      final exporter = VideoExporter(video).withEncoding(customEncoding);

      final config = exporter.buildConfig();

      expect(config.encoding?.quality, RenderQuality.lossless);
      expect(config.encoding?.frameFormat, FrameFormat.png);
    });

    test('custom encoding overrides quality preset', () {
      final video = buildTestVideo();
      final exporter = VideoExporter(video)
          .withQuality(RenderQuality.low)
          .withEncoding(const EncodingConfig(quality: RenderQuality.high));

      final config = exporter.buildConfig();

      // Custom encoding should take precedence
      expect(config.encoding?.quality, RenderQuality.high);
    });

    test('withFileName sets output file name', () {
      final video = buildTestVideo();
      final exporter = VideoExporter(video).withFileName('my_video.mp4');

      expect(exporter.outputFileName, 'my_video.mp4');
    });

    test('builder pattern returns same instance', () {
      final video = buildTestVideo();
      final exporter1 = VideoExporter(video);
      final exporter2 = exporter1.withQuality(RenderQuality.high);
      final exporter3 = exporter2.withFileName('test.mp4');

      expect(identical(exporter1, exporter2), true);
      expect(identical(exporter2, exporter3), true);
    });

    test('extracts embedded video configs from Video', () {
      // Create a video with an embedded video
      const video = Video(
        fps: 30,
        width: 1080,
        height: 1920,
        scenes: [
          Scene(
            durationInFrames: 120,
            background: Background.solid(Colors.black),
            children: [
              EmbeddedVideo(
                assetPath: 'assets/test.mp4',
                width: 400,
                height: 300,
                startFrame: 10,
                durationInFrames: 60,
                includeAudio: true,
              ),
            ],
          ),
        ],
      );

      final exporter = VideoExporter(video);
      final config = exporter.buildConfig();

      expect(config.embeddedVideos.length, 1);
      expect(config.embeddedVideos.first.videoPath, 'assets/test.mp4');
    });
  });

  group('VideoExportProgress', () {
    test('calculates progress correctly', () {
      const progress = VideoExportProgress(
        currentFrame: 50,
        totalFrames: 100,
        phase: VideoExportPhase.capturing,
        elapsed: Duration(seconds: 5),
      );

      expect(progress.progress, 0.5);
    });

    test('progress is 0 when totalFrames is 0', () {
      const progress = VideoExportProgress(
        currentFrame: 0,
        totalFrames: 0,
        phase: VideoExportPhase.initializing,
        elapsed: Duration.zero,
      );

      expect(progress.progress, 0.0);
    });

    test('estimates remaining time during capturing', () {
      const progress = VideoExportProgress(
        currentFrame: 50,
        totalFrames: 100,
        phase: VideoExportPhase.capturing,
        elapsed: Duration(seconds: 10), // 10s for 50 frames = 200ms/frame
      );

      // 50 remaining frames * 200ms = 10 seconds
      expect(progress.estimatedTimeRemaining, isNotNull);
      expect(progress.estimatedTimeRemaining!.inSeconds, closeTo(10, 1));
    });

    test('estimatedTimeRemaining is null when not capturing', () {
      const progress = VideoExportProgress(
        currentFrame: 50,
        totalFrames: 100,
        phase: VideoExportPhase.encoding,
        elapsed: Duration(seconds: 10),
      );

      expect(progress.estimatedTimeRemaining, isNull);
    });

    test('estimatedTimeRemaining is null at frame 0', () {
      const progress = VideoExportProgress(
        currentFrame: 0,
        totalFrames: 100,
        phase: VideoExportPhase.capturing,
        elapsed: Duration.zero,
      );

      expect(progress.estimatedTimeRemaining, isNull);
    });

    test('toString provides useful information', () {
      const progress = VideoExportProgress(
        currentFrame: 30,
        totalFrames: 60,
        phase: VideoExportPhase.capturing,
        elapsed: Duration(seconds: 5),
      );

      final str = progress.toString();

      expect(str, contains('30'));
      expect(str, contains('60'));
      expect(str, contains('capturing'));
      expect(str, contains('50.0%'));
    });
  });

  group('VideoExportPhase', () {
    test('has all expected phases', () {
      expect(VideoExportPhase.values, contains(VideoExportPhase.initializing));
      expect(VideoExportPhase.values, contains(VideoExportPhase.capturing));
      expect(VideoExportPhase.values, contains(VideoExportPhase.encoding));
      expect(VideoExportPhase.values, contains(VideoExportPhase.complete));
      expect(VideoExportPhase.values, contains(VideoExportPhase.failed));
    });
  });
}
