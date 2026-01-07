import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/encoding/video_probe_service.dart';

void main() {
  group('VideoProbeService', () {
    group('construction', () {
      test('creates with default ffprobe path', () {
        final service = VideoProbeService();

        expect(service.ffprobePath, isNull);
      });

      test('creates with custom ffprobe path', () {
        final service = VideoProbeService(ffprobePath: '/custom/ffprobe');

        expect(service.ffprobePath, '/custom/ffprobe');
      });
    });

    // Note: Most probe tests require real ffprobe and files
    // These are marked for integration tests
  });

  group('VideoMetadata', () {
    group('construction', () {
      test('creates with required values', () {
        const metadata = VideoMetadata(
          width: 1920,
          height: 1080,
          fps: 30.0,
          duration: Duration(seconds: 60),
          frameCount: 1800,
          hasAudio: true,
        );

        expect(metadata.width, 1920);
        expect(metadata.height, 1080);
        expect(metadata.fps, 30.0);
        expect(metadata.duration, const Duration(seconds: 60));
        expect(metadata.frameCount, 1800);
        expect(metadata.hasAudio, isTrue);
      });

      test('creates with optional values', () {
        const metadata = VideoMetadata(
          width: 1920,
          height: 1080,
          fps: 29.97,
          duration: Duration(minutes: 2),
          frameCount: 3594,
          hasAudio: true,
          audioCodec: 'aac',
          audioBitrate: 128000,
          audioChannels: 2,
          audioSampleRate: 44100,
          videoCodec: 'h264',
          bitrate: 5000000,
        );

        expect(metadata.audioCodec, 'aac');
        expect(metadata.audioBitrate, 128000);
        expect(metadata.audioChannels, 2);
        expect(metadata.audioSampleRate, 44100);
        expect(metadata.videoCodec, 'h264');
        expect(metadata.bitrate, 5000000);
      });

      test('optional values default to null', () {
        const metadata = VideoMetadata(
          width: 1920,
          height: 1080,
          fps: 30.0,
          duration: Duration(seconds: 60),
          frameCount: 1800,
          hasAudio: false,
        );

        expect(metadata.audioCodec, isNull);
        expect(metadata.audioBitrate, isNull);
        expect(metadata.audioChannels, isNull);
        expect(metadata.audioSampleRate, isNull);
        expect(metadata.videoCodec, isNull);
        expect(metadata.bitrate, isNull);
      });
    });

    group('aspectRatio', () {
      test('calculates 16:9 correctly', () {
        const metadata = VideoMetadata(
          width: 1920,
          height: 1080,
          fps: 30.0,
          duration: Duration(seconds: 60),
          frameCount: 1800,
          hasAudio: false,
        );

        expect(metadata.aspectRatio, closeTo(16 / 9, 0.001));
      });

      test('calculates 4:3 correctly', () {
        const metadata = VideoMetadata(
          width: 1024,
          height: 768,
          fps: 30.0,
          duration: Duration(seconds: 60),
          frameCount: 1800,
          hasAudio: false,
        );

        expect(metadata.aspectRatio, closeTo(4 / 3, 0.001));
      });

      test('calculates 1:1 correctly', () {
        const metadata = VideoMetadata(
          width: 1080,
          height: 1080,
          fps: 30.0,
          duration: Duration(seconds: 60),
          frameCount: 1800,
          hasAudio: false,
        );

        expect(metadata.aspectRatio, 1.0);
      });

      test('returns 1.0 for zero width', () {
        const metadata = VideoMetadata(
          width: 0,
          height: 1080,
          fps: 30.0,
          duration: Duration(seconds: 60),
          frameCount: 1800,
          hasAudio: false,
        );

        expect(metadata.aspectRatio, 1.0);
      });

      test('returns 1.0 for zero height', () {
        const metadata = VideoMetadata(
          width: 1920,
          height: 0,
          fps: 30.0,
          duration: Duration(seconds: 60),
          frameCount: 1800,
          hasAudio: false,
        );

        expect(metadata.aspectRatio, 1.0);
      });
    });

    group('durationSeconds', () {
      test('converts duration to seconds', () {
        const metadata = VideoMetadata(
          width: 1920,
          height: 1080,
          fps: 30.0,
          duration: Duration(minutes: 2, seconds: 30),
          frameCount: 4500,
          hasAudio: false,
        );

        expect(metadata.durationSeconds, 150.0);
      });

      test('handles sub-second precision', () {
        const metadata = VideoMetadata(
          width: 1920,
          height: 1080,
          fps: 30.0,
          duration: Duration(milliseconds: 1500),
          frameCount: 45,
          hasAudio: false,
        );

        expect(metadata.durationSeconds, 1.5);
      });

      test('handles zero duration', () {
        const metadata = VideoMetadata(
          width: 1920,
          height: 1080,
          fps: 30.0,
          duration: Duration.zero,
          frameCount: 0,
          hasAudio: false,
        );

        expect(metadata.durationSeconds, 0.0);
      });
    });

    group('toString', () {
      test('includes all relevant info', () {
        const metadata = VideoMetadata(
          width: 1920,
          height: 1080,
          fps: 29.97,
          duration: Duration(minutes: 2),
          frameCount: 3594,
          hasAudio: true,
        );

        final str = metadata.toString();

        expect(str, contains('1920'));
        expect(str, contains('1080'));
        expect(str, contains('29.97'));
        expect(str, contains('3594'));
        expect(str, contains('hasAudio: true'));
      });
    });

    group('common video formats', () {
      test('represents 1080p 30fps video', () {
        const metadata = VideoMetadata(
          width: 1920,
          height: 1080,
          fps: 30.0,
          duration: Duration(minutes: 5),
          frameCount: 9000,
          hasAudio: true,
          videoCodec: 'h264',
          audioCodec: 'aac',
        );

        expect(metadata.width, 1920);
        expect(metadata.height, 1080);
        expect(metadata.fps, 30.0);
        expect(metadata.frameCount, 9000);
      });

      test('represents 4K 60fps video', () {
        const metadata = VideoMetadata(
          width: 3840,
          height: 2160,
          fps: 60.0,
          duration: Duration(minutes: 2),
          frameCount: 7200,
          hasAudio: true,
          videoCodec: 'hevc',
          audioCodec: 'aac',
        );

        expect(metadata.width, 3840);
        expect(metadata.height, 2160);
        expect(metadata.fps, 60.0);
        expect(metadata.aspectRatio, closeTo(16 / 9, 0.001));
      });

      test('represents NTSC 29.97fps video', () {
        const metadata = VideoMetadata(
          width: 1920,
          height: 1080,
          fps: 29.97,
          duration: Duration(seconds: 60),
          frameCount: 1798, // 60 * 29.97 ≈ 1798
          hasAudio: true,
        );

        expect(metadata.fps, closeTo(29.97, 0.01));
        expect(metadata.frameCount, 1798);
      });

      test('represents vertical/portrait video', () {
        const metadata = VideoMetadata(
          width: 1080,
          height: 1920,
          fps: 30.0,
          duration: Duration(seconds: 15),
          frameCount: 450,
          hasAudio: true,
        );

        expect(metadata.aspectRatio, closeTo(9 / 16, 0.001));
        expect(metadata.aspectRatio, lessThan(1.0));
      });
    });

    group('edge cases', () {
      test('handles very long video', () {
        const metadata = VideoMetadata(
          width: 1920,
          height: 1080,
          fps: 24.0,
          duration: Duration(hours: 3),
          frameCount: 259200, // 3 hours at 24fps
          hasAudio: true,
        );

        expect(metadata.durationSeconds, 3 * 60 * 60);
        expect(metadata.frameCount, 259200);
      });

      test('handles very high fps', () {
        const metadata = VideoMetadata(
          width: 1920,
          height: 1080,
          fps: 240.0,
          duration: Duration(seconds: 10),
          frameCount: 2400,
          hasAudio: false,
        );

        expect(metadata.fps, 240.0);
        expect(metadata.frameCount, 2400);
      });

      test('handles no audio stream', () {
        const metadata = VideoMetadata(
          width: 1920,
          height: 1080,
          fps: 30.0,
          duration: Duration(seconds: 60),
          frameCount: 1800,
          hasAudio: false,
        );

        expect(metadata.hasAudio, isFalse);
        expect(metadata.audioCodec, isNull);
        expect(metadata.audioChannels, isNull);
      });

      test('handles high bitrate', () {
        const metadata = VideoMetadata(
          width: 3840,
          height: 2160,
          fps: 60.0,
          duration: Duration(minutes: 5),
          frameCount: 18000,
          hasAudio: true,
          bitrate: 100000000, // 100 Mbps
        );

        expect(metadata.bitrate, 100000000);
      });

      test('handles surround sound', () {
        const metadata = VideoMetadata(
          width: 1920,
          height: 1080,
          fps: 24.0,
          duration: Duration(hours: 2),
          frameCount: 172800,
          hasAudio: true,
          audioCodec: 'ac3',
          audioChannels: 6, // 5.1 surround
          audioSampleRate: 48000,
        );

        expect(metadata.audioChannels, 6);
        expect(metadata.audioSampleRate, 48000);
      });
    });
  });

  group('Frame rate parsing helpers', () {
    // Test the metadata calculation accuracy
    test('frame count matches duration and fps', () {
      const metadata = VideoMetadata(
        width: 1920,
        height: 1080,
        fps: 30.0,
        duration: Duration(seconds: 100),
        frameCount: 3000,
        hasAudio: false,
      );

      final calculatedFrames =
          (metadata.durationSeconds * metadata.fps).round();
      expect(calculatedFrames, metadata.frameCount);
    });

    test('duration matches frame count and fps', () {
      const metadata = VideoMetadata(
        width: 1920,
        height: 1080,
        fps: 24.0,
        duration: Duration(seconds: 125),
        frameCount: 3000,
        hasAudio: false,
      );

      final calculatedDuration = metadata.frameCount / metadata.fps;
      expect(calculatedDuration, closeTo(metadata.durationSeconds, 0.1));
    });
  });
}
