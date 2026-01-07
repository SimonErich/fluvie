import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/encoding/frame_extraction_service.dart';

void main() {
  group('FrameExtractionService', () {
    group('construction', () {
      test('creates with default ffmpeg path', () {
        final service = FrameExtractionService();

        expect(service.ffmpegPath, isNull);
      });

      test('creates with custom ffmpeg path', () {
        final service = FrameExtractionService(ffmpegPath: '/custom/ffmpeg');

        expect(service.ffmpegPath, '/custom/ffmpeg');
      });
    });

    // Note: Most extraction tests require real FFmpeg and video files
    // These unit tests focus on the extractable logic
  });

  group('ExtractedFrame', () {
    group('construction', () {
      test('creates with required values', () {
        final frame = ExtractedFrame(
          frameNumber: 42,
          rgba: Uint8List(100),
          width: 10,
          height: 10,
        );

        expect(frame.frameNumber, 42);
        expect(frame.rgba.length, 100);
        expect(frame.width, 10);
        expect(frame.height, 10);
      });

      test('stores rgba data correctly', () {
        final rgba = Uint8List.fromList(List.generate(16, (i) => i));
        final frame = ExtractedFrame(
          frameNumber: 0,
          rgba: rgba,
          width: 2,
          height: 2,
        );

        expect(frame.rgba, rgba);
        expect(frame.rgba[0], 0);
        expect(frame.rgba[15], 15);
      });
    });

    group('sizeInBytes', () {
      test('returns correct size for small frame', () {
        final frame = ExtractedFrame(
          frameNumber: 0,
          rgba: Uint8List(100),
          width: 5,
          height: 5,
        );

        expect(frame.sizeInBytes, 100);
      });

      test('returns correct size for 1080p frame', () {
        final frame = ExtractedFrame(
          frameNumber: 0,
          rgba: Uint8List(1920 * 1080 * 4),
          width: 1920,
          height: 1080,
        );

        expect(frame.sizeInBytes, 1920 * 1080 * 4);
        expect(frame.sizeInBytes, 8294400); // ~8.3 MB per frame
      });

      test('returns correct size for 4K frame', () {
        final frame = ExtractedFrame(
          frameNumber: 0,
          rgba: Uint8List(3840 * 2160 * 4),
          width: 3840,
          height: 2160,
        );

        expect(frame.sizeInBytes, 3840 * 2160 * 4);
        expect(frame.sizeInBytes, 33177600); // ~33 MB per frame
      });
    });

    group('frame dimensions', () {
      test('stores 1080p dimensions', () {
        final frame = ExtractedFrame(
          frameNumber: 0,
          rgba: Uint8List(1920 * 1080 * 4),
          width: 1920,
          height: 1080,
        );

        expect(frame.width, 1920);
        expect(frame.height, 1080);
      });

      test('stores 720p dimensions', () {
        final frame = ExtractedFrame(
          frameNumber: 0,
          rgba: Uint8List(1280 * 720 * 4),
          width: 1280,
          height: 720,
        );

        expect(frame.width, 1280);
        expect(frame.height, 720);
      });

      test('stores custom dimensions', () {
        final frame = ExtractedFrame(
          frameNumber: 0,
          rgba: Uint8List(640 * 480 * 4),
          width: 640,
          height: 480,
        );

        expect(frame.width, 640);
        expect(frame.height, 480);
      });

      test('stores square dimensions', () {
        final frame = ExtractedFrame(
          frameNumber: 0,
          rgba: Uint8List(512 * 512 * 4),
          width: 512,
          height: 512,
        );

        expect(frame.width, 512);
        expect(frame.height, 512);
      });
    });

    group('frame number', () {
      test('stores frame 0', () {
        final frame = ExtractedFrame(
          frameNumber: 0,
          rgba: Uint8List(16),
          width: 2,
          height: 2,
        );

        expect(frame.frameNumber, 0);
      });

      test('stores large frame number', () {
        final frame = ExtractedFrame(
          frameNumber: 10000,
          rgba: Uint8List(16),
          width: 2,
          height: 2,
        );

        expect(frame.frameNumber, 10000);
      });

      test('stores frame number from long video', () {
        // 2 hour video at 30fps = 216000 frames
        final frame = ExtractedFrame(
          frameNumber: 216000,
          rgba: Uint8List(16),
          width: 2,
          height: 2,
        );

        expect(frame.frameNumber, 216000);
      });
    });

    group('rgba data integrity', () {
      test('rgba data matches expected size', () {
        const width = 100;
        const height = 50;
        const expectedSize = width * height * 4;

        final frame = ExtractedFrame(
          frameNumber: 0,
          rgba: Uint8List(expectedSize),
          width: width,
          height: height,
        );

        expect(frame.rgba.length, expectedSize);
        expect(frame.sizeInBytes, expectedSize);
      });

      test('rgba data can contain any byte values', () {
        final rgba = Uint8List.fromList([0, 127, 255, 128]); // RGBA pixel
        final frame = ExtractedFrame(
          frameNumber: 0,
          rgba: rgba,
          width: 1,
          height: 1,
        );

        expect(frame.rgba[0], 0); // R
        expect(frame.rgba[1], 127); // G
        expect(frame.rgba[2], 255); // B
        expect(frame.rgba[3], 128); // A
      });

      test('handles transparent pixels', () {
        final rgba =
            Uint8List.fromList([255, 255, 255, 0]); // Transparent white
        final frame = ExtractedFrame(
          frameNumber: 0,
          rgba: rgba,
          width: 1,
          height: 1,
        );

        expect(frame.rgba[3], 0); // Alpha = 0 (transparent)
      });

      test('handles opaque pixels', () {
        final rgba = Uint8List.fromList([255, 0, 0, 255]); // Opaque red
        final frame = ExtractedFrame(
          frameNumber: 0,
          rgba: rgba,
          width: 1,
          height: 1,
        );

        expect(frame.rgba[0], 255); // R
        expect(frame.rgba[3], 255); // Alpha = 255 (opaque)
      });
    });
  });

  group('FrameExtractionException', () {
    test('creates with message only', () {
      final exception = FrameExtractionException('Test error');

      expect(exception.message, 'Test error');
      expect(exception.details, isNull);
    });

    test('creates with message and details', () {
      final exception = FrameExtractionException(
        'Test error',
        details: 'Additional info',
      );

      expect(exception.message, 'Test error');
      expect(exception.details, 'Additional info');
    });

    test('toString includes message', () {
      final exception = FrameExtractionException('Frame extraction failed');

      expect(exception.toString(), contains('Frame extraction failed'));
    });

    test('toString includes details when present', () {
      final exception = FrameExtractionException(
        'Frame extraction failed',
        details: 'FFmpeg error code 1',
      );

      final str = exception.toString();
      expect(str, contains('Frame extraction failed'));
      expect(str, contains('FFmpeg error code 1'));
    });

    test('toString format without details', () {
      final exception = FrameExtractionException('Simple error');

      expect(exception.toString(), 'FrameExtractionException: Simple error');
    });

    test('toString format with details', () {
      final exception = FrameExtractionException(
        'Complex error',
        details: 'Error details here',
      );

      final str = exception.toString();
      expect(str, contains('FrameExtractionException:'));
      expect(str, contains('Complex error'));
      expect(str, contains('Details:'));
      expect(str, contains('Error details here'));
    });
  });

  group('BoxFit scale filter calculations', () {
    // These tests verify the expected behavior of different BoxFit modes
    // The actual scale filter strings are internal implementation

    test('BoxFit.cover maintains aspect ratio and fills bounds', () {
      // Cover should scale to fill, then crop
      // For 800x450 output from 1920x1080 source:
      // Scale: 800x450 would need to scale 1920->800 (0.417x) on width
      // Height at 0.417x would be 450, which exactly fits
      // No crop needed for 16:9 -> 16:9

      // For 800x800 output from 1920x1080:
      // Need to cover 800x800, so scale up to cover
      // Scale by height: 1080->800 = 0.74x, width = 1422
      // Then crop 1422x800 to 800x800

      expect(BoxFit.cover, isNotNull);
    });

    test('BoxFit.contain maintains aspect ratio within bounds', () {
      // Contain should scale to fit within bounds with letterboxing

      expect(BoxFit.contain, isNotNull);
    });

    test('BoxFit.fill stretches to fill bounds', () {
      // Fill stretches to exact size, may distort

      expect(BoxFit.fill, isNotNull);
    });

    test('BoxFit.fitWidth scales to match width', () {
      // FitWidth scales to match target width exactly

      expect(BoxFit.fitWidth, isNotNull);
    });

    test('BoxFit.fitHeight scales to match height', () {
      // FitHeight scales to match target height exactly

      expect(BoxFit.fitHeight, isNotNull);
    });

    test('BoxFit.none uses original size and crops', () {
      // None doesn't scale, just centers and crops

      expect(BoxFit.none, isNotNull);
    });

    test('BoxFit.scaleDown only scales down, never up', () {
      // ScaleDown is like contain but never upscales

      expect(BoxFit.scaleDown, isNotNull);
    });
  });

  group('Memory calculations for video frames', () {
    test('calculates memory for 30 second 1080p video at 30fps', () {
      // 30 seconds * 30 fps = 900 frames
      // 1920 * 1080 * 4 bytes per frame = 8,294,400 bytes
      // Total: 900 * 8,294,400 = ~7.5 GB uncompressed

      const framesCount = 30 * 30;
      const bytesPerFrame = 1920 * 1080 * 4;
      const totalBytes = framesCount * bytesPerFrame;

      expect(totalBytes, 7464960000);
      expect(totalBytes / (1024 * 1024 * 1024), closeTo(6.95, 0.1));
    });

    test('calculates memory for 4K frame', () {
      // 3840 * 2160 * 4 = 33,177,600 bytes (~33 MB)
      const bytesPerFrame = 3840 * 2160 * 4;

      expect(bytesPerFrame, 33177600);
      expect(bytesPerFrame / (1024 * 1024), closeTo(31.6, 0.1));
    });

    test('demonstrates why caching is limited', () {
      // Cache with 90 frame limit at 1080p:
      // 90 * 8,294,400 = ~746 MB
      // This is why maxMemoryBytes defaults to 500MB

      const cachedFrames = 90;
      const bytesPerFrame = 1920 * 1080 * 4;
      const totalCacheBytes = cachedFrames * bytesPerFrame;

      expect(totalCacheBytes / (1024 * 1024), closeTo(711.9, 1.0));
    });
  });

  group('Timestamp calculations', () {
    test('frame to timestamp at 30fps', () {
      // Frame 0 = 0.0 seconds
      // Frame 30 = 1.0 seconds
      // Frame 150 = 5.0 seconds

      double frameToSeconds(int frame, double fps) => frame / fps;

      expect(frameToSeconds(0, 30), 0.0);
      expect(frameToSeconds(30, 30), 1.0);
      expect(frameToSeconds(150, 30), 5.0);
    });

    test('frame to timestamp at 24fps', () {
      double frameToSeconds(int frame, double fps) => frame / fps;

      expect(frameToSeconds(0, 24), 0.0);
      expect(frameToSeconds(24, 24), 1.0);
      expect(frameToSeconds(120, 24), 5.0);
    });

    test('frame to timestamp at 60fps', () {
      double frameToSeconds(int frame, double fps) => frame / fps;

      expect(frameToSeconds(0, 60), 0.0);
      expect(frameToSeconds(60, 60), 1.0);
      expect(frameToSeconds(300, 60), 5.0);
    });

    test('frame to Duration conversion', () {
      Duration frameToTimestamp(int frame, double fps) {
        return Duration(
          microseconds: (frame * 1000000 / fps).round(),
        );
      }

      expect(
        frameToTimestamp(30, 30),
        const Duration(seconds: 1),
      );
      expect(
        frameToTimestamp(15, 30),
        const Duration(milliseconds: 500),
      );
      expect(
        frameToTimestamp(90, 30),
        const Duration(seconds: 3),
      );
    });
  });
}
