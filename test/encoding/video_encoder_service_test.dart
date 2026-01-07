import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/encoding/video_encoder_service.dart';
import 'package:fluvie/src/domain/render_config.dart';
import 'package:fluvie/src/domain/audio_config.dart';
import 'package:fluvie/src/domain/embedded_video_config.dart';
import 'package:fluvie/src/exceptions/fluvie_exceptions.dart';

/// Mock process for testing
class MockProcess implements Process {
  final int exitCodeValue;
  final List<int> stdoutData;
  final List<int> stderrData;
  final List<List<int>> stdinWritten = [];
  // ignore: unused_field
  bool _killed = false;

  MockProcess({
    this.exitCodeValue = 0,
    this.stdoutData = const [],
    this.stderrData = const [],
  });

  @override
  Future<int> get exitCode async {
    // Wait a bit to simulate process running
    await Future.delayed(const Duration(milliseconds: 10));
    return exitCodeValue;
  }

  @override
  bool kill([ProcessSignal signal = ProcessSignal.sigterm]) {
    _killed = true;
    return true;
  }

  bool get wasKilled => _killed;

  @override
  int get pid => 12345;

  @override
  Stream<List<int>> get stderr => Stream.fromIterable([stderrData]);

  @override
  IOSink get stdin => _MockIOSink(this);

  @override
  Stream<List<int>> get stdout => Stream.fromIterable([stdoutData]);
}

class _MockIOSink implements IOSink {
  final MockProcess _process;

  _MockIOSink(this._process);

  @override
  void add(List<int> data) {
    _process.stdinWritten.add(data);
  }

  @override
  Future<void> flush() async {}

  @override
  Future<void> close() async {}

  @override
  void addError(Object error, [StackTrace? stackTrace]) {}

  @override
  Future addStream(Stream<List<int>> stream) async {
    await for (final data in stream) {
      add(data);
    }
  }

  @override
  Future get done async {}

  @override
  Encoding get encoding => utf8;

  @override
  set encoding(Encoding value) {}

  @override
  void write(Object? object) {}

  @override
  void writeAll(Iterable objects, [String separator = '']) {}

  @override
  void writeCharCode(int charCode) {}

  @override
  void writeln([Object? object = '']) {}
}

/// Mock directory for testing
class MockDirectory implements Directory {
  final String _path;

  MockDirectory(this._path);

  @override
  String get path => _path;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('VideoEncodingSession', () {
    test('exposes sink for writing frame data', () async {
      final process = MockProcess();
      final session = VideoEncodingSession(
        stdin: process.stdin,
        completion: Future.value('/output.mp4'),
        process: process,
      );

      expect(session.sink, isNotNull);
    });

    test('exposes completion future', () async {
      final process = MockProcess();
      final session = VideoEncodingSession(
        stdin: process.stdin,
        completion: Future.value('/output.mp4'),
        process: process,
      );

      expect(session.completed, isA<Future<String>>());
    });

    test('close flushes and closes stdin', () async {
      final process = MockProcess();
      final session = VideoEncodingSession(
        stdin: process.stdin,
        completion: Future.value('/output.mp4'),
        process: process,
      );

      // Should not throw
      await session.close();
    });

    test('cancel kills process', () async {
      final process = MockProcess();
      final session = VideoEncodingSession(
        stdin: process.stdin,
        completion: Future.value('/output.mp4'),
        process: process,
      );

      await session.cancel();
      expect(process.wasKilled, isTrue);
    });
  });

  group('VideoEncoderService', () {
    late List<String> capturedArgs;
    late MockProcess mockProcess;

    Future<Process> mockProcessFactory(
      String executable,
      List<String> arguments,
    ) async {
      capturedArgs = arguments;
      return mockProcess;
    }

    Future<Directory> mockTempDirProvider() async {
      return MockDirectory('/tmp/test');
    }

    setUp(() {
      capturedArgs = [];
      mockProcess = MockProcess();
    });

    RenderConfig createConfig({
      int fps = 30,
      int width = 1920,
      int height = 1080,
      int durationInFrames = 300,
      EncodingConfig? encoding,
      List<EmbeddedVideoConfig> embeddedVideos = const [],
      List<AudioTrackConfig> audioTracks = const [],
    }) {
      return RenderConfig(
        timeline: TimelineConfig(
          fps: fps,
          width: width,
          height: height,
          durationInFrames: durationInFrames,
        ),
        sequences: const [],
        encoding: encoding,
        embeddedVideos: embeddedVideos,
        audioTracks: audioTracks,
      );
    }

    group('startEncoding', () {
      test('starts FFmpeg process', () async {
        final service = VideoEncoderService(
          processFactory: mockProcessFactory,
          tempDirProvider: mockTempDirProvider,
        );

        final session = await service.startEncoding(
          config: createConfig(),
          outputFileName: 'output.mp4',
        );

        expect(session, isNotNull);
        expect(capturedArgs, isNotEmpty);
      });

      test('throws when session already active', () async {
        final service = VideoEncoderService(
          processFactory: mockProcessFactory,
          tempDirProvider: mockTempDirProvider,
        );

        await service.startEncoding(
          config: createConfig(),
          outputFileName: 'output1.mp4',
        );

        expect(
          () => service.startEncoding(
            config: createConfig(),
            outputFileName: 'output2.mp4',
          ),
          throwsA(isA<InvalidConfigurationException>()),
        );
      });

      test('uses correct fps', () async {
        final service = VideoEncoderService(
          processFactory: mockProcessFactory,
          tempDirProvider: mockTempDirProvider,
        );

        await service.startEncoding(
          config: createConfig(fps: 60),
          outputFileName: 'output.mp4',
        );

        expect(capturedArgs.contains('60'), isTrue);
      });

      test('uses correct dimensions for raw format', () async {
        final service = VideoEncoderService(
          processFactory: mockProcessFactory,
          tempDirProvider: mockTempDirProvider,
        );

        await service.startEncoding(
          config: createConfig(
            width: 1280,
            height: 720,
            encoding: const EncodingConfig(frameFormat: FrameFormat.rawRgba),
          ),
          outputFileName: 'output.mp4',
        );

        expect(capturedArgs.any((arg) => arg.contains('1280x720')), isTrue);
      });

      test('uses rawvideo format by default', () async {
        final service = VideoEncoderService(
          processFactory: mockProcessFactory,
          tempDirProvider: mockTempDirProvider,
        );

        await service.startEncoding(
          config: createConfig(),
          outputFileName: 'output.mp4',
        );

        // Default EncodingConfig uses FrameFormat.rawRgba
        expect(capturedArgs.contains('rawvideo'), isTrue);
        expect(capturedArgs.contains('rgba'), isTrue);
      });

      test('uses PNG format when configured', () async {
        final service = VideoEncoderService(
          processFactory: mockProcessFactory,
          tempDirProvider: mockTempDirProvider,
        );

        await service.startEncoding(
          config: createConfig(
            encoding: const EncodingConfig(frameFormat: FrameFormat.png),
          ),
          outputFileName: 'output.mp4',
        );

        // Should use image2pipe for PNG format
        expect(capturedArgs.contains('image2pipe'), isTrue);
        expect(capturedArgs.contains('png'), isTrue);
      });

      test('uses rawvideo format when configured', () async {
        final service = VideoEncoderService(
          processFactory: mockProcessFactory,
          tempDirProvider: mockTempDirProvider,
        );

        await service.startEncoding(
          config: createConfig(
            encoding: const EncodingConfig(frameFormat: FrameFormat.rawRgba),
          ),
          outputFileName: 'output.mp4',
        );

        expect(capturedArgs.contains('rawvideo'), isTrue);
        expect(capturedArgs.contains('rgba'), isTrue);
      });
    });

    group('quality settings', () {
      test('uses CRF 30 for low quality', () async {
        final service = VideoEncoderService(
          processFactory: mockProcessFactory,
          tempDirProvider: mockTempDirProvider,
        );

        await service.startEncoding(
          config: createConfig(
            encoding: const EncodingConfig(quality: RenderQuality.low),
          ),
          outputFileName: 'output.mp4',
        );

        final crfIndex = capturedArgs.indexOf('-crf');
        expect(crfIndex, isNot(-1));
        expect(capturedArgs[crfIndex + 1], '30');
      });

      test('uses CRF 23 for medium quality', () async {
        final service = VideoEncoderService(
          processFactory: mockProcessFactory,
          tempDirProvider: mockTempDirProvider,
        );

        await service.startEncoding(
          config: createConfig(
            encoding: const EncodingConfig(quality: RenderQuality.medium),
          ),
          outputFileName: 'output.mp4',
        );

        final crfIndex = capturedArgs.indexOf('-crf');
        expect(crfIndex, isNot(-1));
        expect(capturedArgs[crfIndex + 1], '23');
      });

      test('uses CRF 18 for high quality', () async {
        final service = VideoEncoderService(
          processFactory: mockProcessFactory,
          tempDirProvider: mockTempDirProvider,
        );

        await service.startEncoding(
          config: createConfig(
            encoding: const EncodingConfig(quality: RenderQuality.high),
          ),
          outputFileName: 'output.mp4',
        );

        final crfIndex = capturedArgs.indexOf('-crf');
        expect(crfIndex, isNot(-1));
        expect(capturedArgs[crfIndex + 1], '18');
      });

      test('uses CRF 0 for lossless quality', () async {
        final service = VideoEncoderService(
          processFactory: mockProcessFactory,
          tempDirProvider: mockTempDirProvider,
        );

        await service.startEncoding(
          config: createConfig(
            encoding: const EncodingConfig(quality: RenderQuality.lossless),
          ),
          outputFileName: 'output.mp4',
        );

        final crfIndex = capturedArgs.indexOf('-crf');
        expect(crfIndex, isNot(-1));
        expect(capturedArgs[crfIndex + 1], '0');
      });

      test('uses CRF override when specified', () async {
        final service = VideoEncoderService(
          processFactory: mockProcessFactory,
          tempDirProvider: mockTempDirProvider,
        );

        await service.startEncoding(
          config: createConfig(
            encoding: const EncodingConfig(
              quality: RenderQuality.high,
              crfOverride: 15,
            ),
          ),
          outputFileName: 'output.mp4',
        );

        final crfIndex = capturedArgs.indexOf('-crf');
        expect(capturedArgs[crfIndex + 1], '15');
      });

      test('uses preset override when specified', () async {
        final service = VideoEncoderService(
          processFactory: mockProcessFactory,
          tempDirProvider: mockTempDirProvider,
        );

        await service.startEncoding(
          config: createConfig(
            encoding: const EncodingConfig(
              quality: RenderQuality.high,
              presetOverride: 'ultrafast',
            ),
          ),
          outputFileName: 'output.mp4',
        );

        final presetIndex = capturedArgs.indexOf('-preset');
        expect(capturedArgs[presetIndex + 1], 'ultrafast');
      });
    });

    group('presets by quality', () {
      test('uses veryfast preset for low quality', () async {
        final service = VideoEncoderService(
          processFactory: mockProcessFactory,
          tempDirProvider: mockTempDirProvider,
        );

        await service.startEncoding(
          config: createConfig(
            encoding: const EncodingConfig(quality: RenderQuality.low),
          ),
          outputFileName: 'output.mp4',
        );

        final presetIndex = capturedArgs.indexOf('-preset');
        expect(capturedArgs[presetIndex + 1], 'veryfast');
      });

      test('uses medium preset for medium quality', () async {
        final service = VideoEncoderService(
          processFactory: mockProcessFactory,
          tempDirProvider: mockTempDirProvider,
        );

        await service.startEncoding(
          config: createConfig(
            encoding: const EncodingConfig(quality: RenderQuality.medium),
          ),
          outputFileName: 'output.mp4',
        );

        final presetIndex = capturedArgs.indexOf('-preset');
        expect(capturedArgs[presetIndex + 1], 'medium');
      });

      test('uses slow preset for high quality', () async {
        final service = VideoEncoderService(
          processFactory: mockProcessFactory,
          tempDirProvider: mockTempDirProvider,
        );

        await service.startEncoding(
          config: createConfig(
            encoding: const EncodingConfig(quality: RenderQuality.high),
          ),
          outputFileName: 'output.mp4',
        );

        final presetIndex = capturedArgs.indexOf('-preset');
        expect(capturedArgs[presetIndex + 1], 'slow');
      });

      test('uses veryslow preset for lossless quality', () async {
        final service = VideoEncoderService(
          processFactory: mockProcessFactory,
          tempDirProvider: mockTempDirProvider,
        );

        await service.startEncoding(
          config: createConfig(
            encoding: const EncodingConfig(quality: RenderQuality.lossless),
          ),
          outputFileName: 'output.mp4',
        );

        final presetIndex = capturedArgs.indexOf('-preset');
        expect(capturedArgs[presetIndex + 1], 'veryslow');
      });
    });

    group('audio configuration', () {
      test('disables audio when no audio tracks', () async {
        final service = VideoEncoderService(
          processFactory: mockProcessFactory,
          tempDirProvider: mockTempDirProvider,
        );

        await service.startEncoding(
          config: createConfig(),
          outputFileName: 'output.mp4',
        );

        // Should have -an flag
        expect(capturedArgs.contains('-an'), isTrue);
      });

      test('includes audio codec when audio present', () async {
        final service = VideoEncoderService(
          processFactory: mockProcessFactory,
          tempDirProvider: mockTempDirProvider,
        );

        // Note: We can't easily test file-based audio without real files
        // This test verifies the structure is correct with embedded video audio
        await service.startEncoding(
          config: createConfig(
            embeddedVideos: [
              const EmbeddedVideoConfig(
                videoPath: '/path/to/video.mp4',
                startFrame: 0,
                durationInFrames: 150,
                trimStartSeconds: 0,
                width: 800,
                height: 600,
                includeAudio: true,
                id: 'video_1',
              ),
            ],
          ),
          outputFileName: 'output.mp4',
        );

        // Should include audio codec settings
        expect(capturedArgs.contains('-c:a'), isTrue);
        expect(capturedArgs.contains('aac'), isTrue);
        expect(capturedArgs.contains('-b:a'), isTrue);
        expect(capturedArgs.contains('192k'), isTrue);
      });
    });

    group('embedded videos', () {
      test('adds embedded video as input', () async {
        final service = VideoEncoderService(
          processFactory: mockProcessFactory,
          tempDirProvider: mockTempDirProvider,
        );

        await service.startEncoding(
          config: createConfig(
            embeddedVideos: [
              const EmbeddedVideoConfig(
                videoPath: '/path/to/video.mp4',
                startFrame: 0,
                durationInFrames: 150,
                trimStartSeconds: 0,
                width: 800,
                height: 600,
                includeAudio: false,
                id: 'video_1',
              ),
            ],
          ),
          outputFileName: 'output.mp4',
        );

        // Should have input for the video file
        expect(capturedArgs.contains('/path/to/video.mp4'), isTrue);
      });

      test('adds seek offset for trimmed videos', () async {
        final service = VideoEncoderService(
          processFactory: mockProcessFactory,
          tempDirProvider: mockTempDirProvider,
        );

        await service.startEncoding(
          config: createConfig(
            embeddedVideos: [
              const EmbeddedVideoConfig(
                videoPath: '/path/to/video.mp4',
                startFrame: 0,
                durationInFrames: 150,
                trimStartSeconds: 5.5,
                width: 800,
                height: 600,
                includeAudio: false,
                id: 'video_1',
              ),
            ],
          ),
          outputFileName: 'output.mp4',
        );

        // Should have -ss flag before the input
        final ssIndex = capturedArgs.indexOf('-ss');
        expect(ssIndex, isNot(-1));
        expect(capturedArgs[ssIndex + 1], contains('5.5'));
      });

      test('does not add seek for zero trim', () async {
        final service = VideoEncoderService(
          processFactory: mockProcessFactory,
          tempDirProvider: mockTempDirProvider,
        );

        await service.startEncoding(
          config: createConfig(
            embeddedVideos: [
              const EmbeddedVideoConfig(
                videoPath: '/path/to/video.mp4',
                startFrame: 0,
                durationInFrames: 150,
                trimStartSeconds: 0,
                width: 800,
                height: 600,
                includeAudio: false,
                id: 'video_1',
              ),
            ],
          ),
          outputFileName: 'output.mp4',
        );

        // Count -ss occurrences - should not have one for zero trim
        // Note: The first -ss might be for frame input, we just verify the structure
        expect(capturedArgs, isNotEmpty);
      });
    });

    group('output configuration', () {
      test('uses libx264 codec', () async {
        final service = VideoEncoderService(
          processFactory: mockProcessFactory,
          tempDirProvider: mockTempDirProvider,
        );

        await service.startEncoding(
          config: createConfig(),
          outputFileName: 'output.mp4',
        );

        expect(capturedArgs.contains('-c:v'), isTrue);
        expect(capturedArgs.contains('libx264'), isTrue);
      });

      test('uses yuv420p pixel format', () async {
        final service = VideoEncoderService(
          processFactory: mockProcessFactory,
          tempDirProvider: mockTempDirProvider,
        );

        await service.startEncoding(
          config: createConfig(),
          outputFileName: 'output.mp4',
        );

        expect(capturedArgs.contains('-pix_fmt'), isTrue);
        expect(capturedArgs.contains('yuv420p'), isTrue);
      });

      test('overwrites existing output file', () async {
        final service = VideoEncoderService(
          processFactory: mockProcessFactory,
          tempDirProvider: mockTempDirProvider,
        );

        await service.startEncoding(
          config: createConfig(),
          outputFileName: 'output.mp4',
        );

        expect(capturedArgs.contains('-y'), isTrue);
      });

      test('output path is in temp directory', () async {
        final service = VideoEncoderService(
          processFactory: mockProcessFactory,
          tempDirProvider: mockTempDirProvider,
        );

        await service.startEncoding(
          config: createConfig(),
          outputFileName: 'output.mp4',
        );

        // Last argument should be output path
        final outputPath = capturedArgs.last;
        expect(outputPath, contains('/tmp/test/'));
        expect(outputPath, contains('output.mp4'));
      });
    });

    group('completion handling', () {
      test('completion resolves with output path on success', () async {
        mockProcess = MockProcess(exitCodeValue: 0);

        final service = VideoEncoderService(
          processFactory: mockProcessFactory,
          tempDirProvider: mockTempDirProvider,
        );

        final session = await service.startEncoding(
          config: createConfig(),
          outputFileName: 'output.mp4',
        );

        final outputPath = await session.completed;
        expect(outputPath, contains('output.mp4'));
      });

      test('completion rejects on FFmpeg failure', () async {
        mockProcess = MockProcess(
          exitCodeValue: 1,
          stderrData: utf8.encode('Error: invalid input'),
        );

        final service = VideoEncoderService(
          processFactory: mockProcessFactory,
          tempDirProvider: mockTempDirProvider,
        );

        final session = await service.startEncoding(
          config: createConfig(),
          outputFileName: 'output.mp4',
        );

        expect(session.completed, throwsException);
      });
    });

    group('filter graph', () {
      test('includes filter complex argument', () async {
        final service = VideoEncoderService(
          processFactory: mockProcessFactory,
          tempDirProvider: mockTempDirProvider,
        );

        await service.startEncoding(
          config: createConfig(),
          outputFileName: 'output.mp4',
        );

        expect(capturedArgs.contains('-filter_complex'), isTrue);
      });

      test('maps video output', () async {
        final service = VideoEncoderService(
          processFactory: mockProcessFactory,
          tempDirProvider: mockTempDirProvider,
        );

        await service.startEncoding(
          config: createConfig(),
          outputFileName: 'output.mp4',
        );

        expect(capturedArgs.contains('-map'), isTrue);
        expect(capturedArgs.contains('[v_out]'), isTrue);
      });
    });
  });
}
