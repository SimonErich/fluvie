@Tags(['integration', 'ffmpeg'])
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/utils/ffmpeg_checker.dart';

/// Integration tests that require real FFmpeg installation.
///
/// These tests are tagged with 'integration' and 'ffmpeg' and should be run
/// separately from unit tests:
///
/// ```bash
/// flutter test --tags=ffmpeg
/// ```
///
/// Skip these tests in CI if FFmpeg is not available:
///
/// ```bash
/// flutter test --exclude-tags=ffmpeg
/// ```
void main() {
  group('FFmpeg Integration', () {
    late bool ffmpegAvailable;

    setUpAll(() async {
      ffmpegAvailable = await FFmpegChecker.isAvailable();
    });

    group('FFmpegChecker', () {
      test('detects FFmpeg installation', () async {
        // This test will pass if FFmpeg is installed, fail otherwise
        // Skip if not available rather than failing
        if (!ffmpegAvailable) {
          markTestSkipped('FFmpeg not installed');
          return;
        }

        expect(ffmpegAvailable, isTrue);
      });

      test('provides diagnostics', () async {
        final diagnostics = await FFmpegChecker.check();

        expect(diagnostics, isNotNull);
        expect(diagnostics.providerName, isNotEmpty);

        if (ffmpegAvailable) {
          expect(diagnostics.isAvailable, isTrue);
        } else {
          expect(diagnostics.isAvailable, isFalse);
          expect(diagnostics.errorMessage, isNotNull);
          expect(diagnostics.installationInstructions, isNotNull);
        }
      });

      test('detects ffprobe availability', () async {
        if (!ffmpegAvailable) {
          markTestSkipped('FFmpeg not installed');
          return;
        }

        // If FFmpeg is available, ffprobe should also be available
        final result = await Process.run('ffprobe', ['-version']);
        expect(result.exitCode, 0);
      });
    });

    group('FFmpeg process execution', () {
      test('runs FFmpeg with version flag', () async {
        if (!ffmpegAvailable) {
          markTestSkipped('FFmpeg not installed');
          return;
        }

        final result = await Process.run('ffmpeg', ['-version']);

        expect(result.exitCode, 0);
        expect(result.stdout.toString(), contains('ffmpeg version'));
      });

      test('lists available codecs', () async {
        if (!ffmpegAvailable) {
          markTestSkipped('FFmpeg not installed');
          return;
        }

        final result = await Process.run('ffmpeg', ['-codecs']);

        expect(result.exitCode, 0);
        // Should list common codecs
        expect(result.stdout.toString(), contains('h264'));
      });

      test('lists available formats', () async {
        if (!ffmpegAvailable) {
          markTestSkipped('FFmpeg not installed');
          return;
        }

        final result = await Process.run('ffmpeg', ['-formats']);

        expect(result.exitCode, 0);
        // Should list common formats
        expect(result.stdout.toString(), contains('mp4'));
      });

      test('lists available filters', () async {
        if (!ffmpegAvailable) {
          markTestSkipped('FFmpeg not installed');
          return;
        }

        final result = await Process.run('ffmpeg', ['-filters']);

        expect(result.exitCode, 0);
        // Should list common filters we use
        final output = result.stdout.toString();
        expect(output, contains('scale'));
        expect(output, contains('overlay'));
      });
    });

    group('Filter graph validation', () {
      test('validates simple scale filter', () async {
        if (!ffmpegAvailable) {
          markTestSkipped('FFmpeg not installed');
          return;
        }

        // Use FFmpeg to validate a filter graph
        final result = await Process.run('ffmpeg', [
          '-f',
          'lavfi',
          '-i',
          'nullsrc=size=100x100:duration=0.1',
          '-vf',
          'scale=200:200',
          '-f',
          'null',
          '-',
        ]);

        expect(result.exitCode, 0);
      });

      test('validates color filter', () async {
        if (!ffmpegAvailable) {
          markTestSkipped('FFmpeg not installed');
          return;
        }

        final result = await Process.run('ffmpeg', [
          '-f',
          'lavfi',
          '-i',
          'color=black:size=100x100:duration=0.1',
          '-f',
          'null',
          '-',
        ]);

        expect(result.exitCode, 0);
      });

      test('validates overlay filter', () async {
        if (!ffmpegAvailable) {
          markTestSkipped('FFmpeg not installed');
          return;
        }

        final result = await Process.run('ffmpeg', [
          '-f',
          'lavfi',
          '-i',
          'color=red:size=100x100:duration=0.1',
          '-f',
          'lavfi',
          '-i',
          'color=blue:size=50x50:duration=0.1',
          '-filter_complex',
          '[0][1]overlay=25:25',
          '-f',
          'null',
          '-',
        ]);

        expect(result.exitCode, 0);
      });
    });

    group('Audio filter validation', () {
      test('validates volume filter', () async {
        if (!ffmpegAvailable) {
          markTestSkipped('FFmpeg not installed');
          return;
        }

        final result = await Process.run('ffmpeg', [
          '-f',
          'lavfi',
          '-i',
          'anullsrc=sample_rate=44100:channel_layout=stereo:duration=0.1',
          '-af',
          'volume=0.5',
          '-f',
          'null',
          '-',
        ]);

        expect(result.exitCode, 0);
      });

      test('validates afade filter', () async {
        if (!ffmpegAvailable) {
          markTestSkipped('FFmpeg not installed');
          return;
        }

        final result = await Process.run('ffmpeg', [
          '-f',
          'lavfi',
          '-i',
          'anullsrc=sample_rate=44100:channel_layout=stereo:duration=1',
          '-af',
          'afade=t=in:st=0:d=0.5,afade=t=out:st=0.5:d=0.5',
          '-f',
          'null',
          '-',
        ]);

        expect(result.exitCode, 0);
      });

      test('validates atrim filter', () async {
        if (!ffmpegAvailable) {
          markTestSkipped('FFmpeg not installed');
          return;
        }

        final result = await Process.run('ffmpeg', [
          '-f',
          'lavfi',
          '-i',
          'anullsrc=sample_rate=44100:channel_layout=stereo:duration=2',
          '-af',
          'atrim=start=0.5:end=1.5',
          '-f',
          'null',
          '-',
        ]);

        expect(result.exitCode, 0);
      });

      test('validates adelay filter', () async {
        if (!ffmpegAvailable) {
          markTestSkipped('FFmpeg not installed');
          return;
        }

        final result = await Process.run('ffmpeg', [
          '-f',
          'lavfi',
          '-i',
          'anullsrc=sample_rate=44100:channel_layout=stereo:duration=0.5',
          '-af',
          'adelay=500|500',
          '-f',
          'null',
          '-',
        ]);

        expect(result.exitCode, 0);
      });

      test('validates amix filter for audio mixing', () async {
        if (!ffmpegAvailable) {
          markTestSkipped('FFmpeg not installed');
          return;
        }

        final result = await Process.run('ffmpeg', [
          '-f',
          'lavfi',
          '-i',
          'anullsrc=sample_rate=44100:channel_layout=stereo:duration=0.5',
          '-f',
          'lavfi',
          '-i',
          'anullsrc=sample_rate=44100:channel_layout=stereo:duration=0.5',
          '-filter_complex',
          '[0][1]amix=inputs=2:duration=longest',
          '-f',
          'null',
          '-',
        ]);

        expect(result.exitCode, 0);
      });
    });

    group('Rawvideo input handling', () {
      test('accepts rawvideo format from stdin', () async {
        if (!ffmpegAvailable) {
          markTestSkipped('FFmpeg not installed');
          return;
        }

        // Create a simple 2x2 RGBA frame
        final frameData = List.filled(2 * 2 * 4, 255); // White pixels

        final process = await Process.start('ffmpeg', [
          '-y',
          '-f',
          'rawvideo',
          '-pix_fmt',
          'rgba',
          '-s',
          '2x2',
          '-r',
          '1',
          '-i',
          '-',
          '-frames:v',
          '1',
          '-f',
          'null',
          '-',
        ]);

        // CRITICAL: Drain stdout/stderr to prevent blocking on Windows.
        // Without this, the process can hang when output buffers fill up.
        // This matches how the production code handles FFmpeg processes.
        unawaited(process.stdout.drain<void>());
        unawaited(process.stderr.drain<void>());

        process.stdin.add(frameData);
        await process.stdin.close();

        final exitCode = await process.exitCode;
        expect(exitCode, 0);
      });

      test('processes multiple rawvideo frames', () async {
        if (!ffmpegAvailable) {
          markTestSkipped('FFmpeg not installed');
          return;
        }

        const frameSize = 4 * 4 * 4; // 4x4 RGBA
        final frame1 = List.filled(frameSize, 255); // White
        final frame2 = List.filled(frameSize, 0); // Black (with alpha 0)
        final frame3 = List.filled(frameSize, 128); // Gray

        final process = await Process.start('ffmpeg', [
          '-y',
          '-f',
          'rawvideo',
          '-pix_fmt',
          'rgba',
          '-s',
          '4x4',
          '-r',
          '30',
          '-i',
          '-',
          '-frames:v',
          '3',
          '-f',
          'null',
          '-',
        ]);

        // CRITICAL: Drain stdout/stderr to prevent blocking on Windows.
        // Without this, the process can hang when output buffers fill up.
        // This matches how the production code handles FFmpeg processes.
        unawaited(process.stdout.drain<void>());
        unawaited(process.stderr.drain<void>());

        process.stdin.add(frame1);
        process.stdin.add(frame2);
        process.stdin.add(frame3);
        await process.stdin.close();

        final exitCode = await process.exitCode;
        expect(exitCode, 0);
      });
    });

    group('Output format support', () {
      late Directory tempDir;

      setUp(() async {
        tempDir = await Directory.systemTemp.createTemp('fluvie_test_');
      });

      tearDown(() async {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      });

      test('encodes to MP4 with H.264', () async {
        if (!ffmpegAvailable) {
          markTestSkipped('FFmpeg not installed');
          return;
        }

        final outputPath = '${tempDir.path}/test.mp4';

        final result = await Process.run('ffmpeg', [
          '-y',
          '-f',
          'lavfi',
          '-i',
          'color=blue:size=100x100:duration=0.1:rate=30',
          '-c:v',
          'libx264',
          '-pix_fmt',
          'yuv420p',
          outputPath,
        ]);

        expect(result.exitCode, 0);
        expect(await File(outputPath).exists(), isTrue);

        final fileSize = await File(outputPath).length();
        expect(fileSize, greaterThan(0));
      });

      test('encodes to WebM with VP9', () async {
        if (!ffmpegAvailable) {
          markTestSkipped('FFmpeg not installed');
          return;
        }

        // Check if VP9 encoder is available
        final codecCheck = await Process.run('ffmpeg', ['-codecs']);
        if (!codecCheck.stdout.toString().contains('libvpx-vp9')) {
          markTestSkipped('VP9 encoder not available');
          return;
        }

        final outputPath = '${tempDir.path}/test.webm';

        final result = await Process.run('ffmpeg', [
          '-y',
          '-f',
          'lavfi',
          '-i',
          'color=red:size=100x100:duration=0.1:rate=30',
          '-c:v',
          'libvpx-vp9',
          '-b:v',
          '1M',
          outputPath,
        ]);

        expect(result.exitCode, 0);
        expect(await File(outputPath).exists(), isTrue);
      });

      test('encodes to GIF', () async {
        if (!ffmpegAvailable) {
          markTestSkipped('FFmpeg not installed');
          return;
        }

        final outputPath = '${tempDir.path}/test.gif';

        final result = await Process.run('ffmpeg', [
          '-y',
          '-f',
          'lavfi',
          '-i',
          'color=green:size=100x100:duration=0.2:rate=10',
          outputPath,
        ]);

        expect(result.exitCode, 0);
        expect(await File(outputPath).exists(), isTrue);
      });
    });

    group('Video probe', () {
      late Directory tempDir;
      late String testVideoPath;

      setUp(() async {
        if (!ffmpegAvailable) return;

        tempDir = await Directory.systemTemp.createTemp('fluvie_probe_test_');
        testVideoPath = '${tempDir.path}/test_probe.mp4';

        // Create a test video
        await Process.run('ffmpeg', [
          '-y',
          '-f',
          'lavfi',
          '-i',
          'color=blue:size=320x240:duration=1:rate=30',
          '-f',
          'lavfi',
          '-i',
          'anullsrc=sample_rate=44100:channel_layout=stereo:duration=1',
          '-c:v',
          'libx264',
          '-c:a',
          'aac',
          '-pix_fmt',
          'yuv420p',
          '-shortest',
          testVideoPath,
        ]);
      });

      tearDown(() async {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      });

      test('probes video metadata with ffprobe', () async {
        if (!ffmpegAvailable) {
          markTestSkipped('FFmpeg not installed');
          return;
        }

        final result = await Process.run('ffprobe', [
          '-v',
          'quiet',
          '-print_format',
          'json',
          '-show_format',
          '-show_streams',
          testVideoPath,
        ]);

        expect(result.exitCode, 0);

        final output = result.stdout.toString();
        expect(output, contains('"format"'));
        expect(output, contains('"streams"'));
        expect(output, contains('"width"'));
        expect(output, contains('"height"'));
      });

      test('extracts video dimensions', () async {
        if (!ffmpegAvailable) {
          markTestSkipped('FFmpeg not installed');
          return;
        }

        final result = await Process.run('ffprobe', [
          '-v',
          'error',
          '-select_streams',
          'v:0',
          '-show_entries',
          'stream=width,height',
          '-of',
          'csv=s=x:p=0',
          testVideoPath,
        ]);

        expect(result.exitCode, 0);
        expect(result.stdout.toString().trim(), '320x240');
      });

      test('extracts video frame rate', () async {
        if (!ffmpegAvailable) {
          markTestSkipped('FFmpeg not installed');
          return;
        }

        final result = await Process.run('ffprobe', [
          '-v',
          'error',
          '-select_streams',
          'v:0',
          '-show_entries',
          'stream=r_frame_rate',
          '-of',
          'default=noprint_wrappers=1:nokey=1',
          testVideoPath,
        ]);

        expect(result.exitCode, 0);
        // Frame rate should be 30/1
        expect(result.stdout.toString().trim(), contains('30'));
      });

      test('detects audio stream', () async {
        if (!ffmpegAvailable) {
          markTestSkipped('FFmpeg not installed');
          return;
        }

        final result = await Process.run('ffprobe', [
          '-v',
          'error',
          '-select_streams',
          'a:0',
          '-show_entries',
          'stream=codec_type',
          '-of',
          'default=noprint_wrappers=1:nokey=1',
          testVideoPath,
        ]);

        expect(result.exitCode, 0);
        expect(result.stdout.toString().trim(), 'audio');
      });
    });
  });
}
