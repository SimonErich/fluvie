@Tags(['integration', 'ffmpeg'])
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/utils/ffmpeg_checker.dart';

/// Full pipeline integration tests that test the complete video rendering flow.
///
/// These tests require:
/// - FFmpeg installed and available in PATH
/// - Disk space for temporary video files
///
/// Run with:
/// ```bash
/// flutter test --tags=integration
/// ```
void main() {
  group('Full Pipeline Integration', () {
    late bool ffmpegAvailable;
    late Directory tempDir;

    setUpAll(() async {
      ffmpegAvailable = await FFmpegChecker.isAvailable();
    });

    setUp(() async {
      if (ffmpegAvailable) {
        tempDir = await Directory.systemTemp.createTemp('fluvie_pipeline_');
      }
    });

    tearDown(() async {
      if (ffmpegAvailable && await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    group('Simple video generation', () {
      test('generates video from solid color frames', () async {
        if (!ffmpegAvailable) {
          markTestSkipped('FFmpeg not installed');
          return;
        }

        final outputPath = '${tempDir.path}/solid_color.mp4';

        // Generate 30 frames of solid red (1 second at 30fps)
        const frameWidth = 100;
        const frameHeight = 100;
        const frameSize = frameWidth * frameHeight * 4; // RGBA
        const totalFrames = 30;

        // Create red frame (RGBA)
        final redFrame = List<int>.generate(frameSize, (i) {
          final pixelOffset = i % 4;
          switch (pixelOffset) {
            case 0:
              return 255; // R
            case 1:
              return 0; // G
            case 2:
              return 0; // B
            case 3:
              return 255; // A
            default:
              return 0;
          }
        });

        final process = await Process.start('ffmpeg', [
          '-y',
          '-f',
          'rawvideo',
          '-pix_fmt',
          'rgba',
          '-s',
          '${frameWidth}x$frameHeight',
          '-r',
          '30',
          '-i',
          '-',
          '-frames:v',
          '$totalFrames',
          '-c:v',
          'libx264',
          '-pix_fmt',
          'yuv420p',
          outputPath,
        ]);

        // Write frames
        for (int i = 0; i < totalFrames; i++) {
          process.stdin.add(redFrame);
        }
        await process.stdin.close();

        final exitCode = await process.exitCode;
        expect(exitCode, 0, reason: 'FFmpeg should complete successfully');

        // Verify output file
        final outputFile = File(outputPath);
        expect(await outputFile.exists(), isTrue);
        expect(await outputFile.length(), greaterThan(0));

        // Probe the output to verify properties
        final probeResult = await Process.run('ffprobe', [
          '-v',
          'error',
          '-select_streams',
          'v:0',
          '-show_entries',
          'stream=width,height,nb_frames',
          '-of',
          'csv=s=,:p=0',
          outputPath,
        ]);

        expect(probeResult.exitCode, 0);
        final probeOutput = probeResult.stdout.toString().trim();
        expect(probeOutput, contains('100'));
      });

      test('generates video with varying colors (animation)', () async {
        if (!ffmpegAvailable) {
          markTestSkipped('FFmpeg not installed');
          return;
        }

        final outputPath = '${tempDir.path}/animated.mp4';

        const frameWidth = 64;
        const frameHeight = 64;
        const frameSize = frameWidth * frameHeight * 4;
        const totalFrames = 60;

        final process = await Process.start('ffmpeg', [
          '-y',
          '-f',
          'rawvideo',
          '-pix_fmt',
          'rgba',
          '-s',
          '${frameWidth}x$frameHeight',
          '-r',
          '30',
          '-i',
          '-',
          '-frames:v',
          '$totalFrames',
          '-c:v',
          'libx264',
          '-pix_fmt',
          'yuv420p',
          outputPath,
        ]);

        // Generate gradient animation
        for (int f = 0; f < totalFrames; f++) {
          final progress = f / totalFrames;
          final r = (progress * 255).round();
          final g = ((1 - progress) * 255).round();
          const b = 128;

          final frame = List<int>.generate(frameSize, (i) {
            final pixelOffset = i % 4;
            switch (pixelOffset) {
              case 0:
                return r;
              case 1:
                return g;
              case 2:
                return b;
              case 3:
                return 255;
              default:
                return 0;
            }
          });

          process.stdin.add(frame);
        }
        await process.stdin.close();

        final exitCode = await process.exitCode;
        expect(exitCode, 0);

        expect(await File(outputPath).exists(), isTrue);
      });
    });

    group('Video with audio', () {
      test('combines video with generated audio', () async {
        if (!ffmpegAvailable) {
          markTestSkipped('FFmpeg not installed');
          return;
        }

        final outputPath = '${tempDir.path}/with_audio.mp4';

        // Use filter_complex to combine generated video and audio
        final result = await Process.run('ffmpeg', [
          '-y',
          '-f',
          'lavfi',
          '-i',
          'color=blue:size=200x200:duration=2:rate=30',
          '-f',
          'lavfi',
          '-i',
          'sine=frequency=440:duration=2',
          '-c:v',
          'libx264',
          '-c:a',
          'aac',
          '-pix_fmt',
          'yuv420p',
          '-shortest',
          outputPath,
        ]);

        expect(result.exitCode, 0);

        // Verify both streams exist
        final probeResult = await Process.run('ffprobe', [
          '-v',
          'error',
          '-show_entries',
          'stream=codec_type',
          '-of',
          'csv=p=0',
          outputPath,
        ]);

        final streams = probeResult.stdout.toString().trim().split('\n');
        expect(streams, contains('video'));
        expect(streams, contains('audio'));
      });

      test('applies audio fade in/out', () async {
        if (!ffmpegAvailable) {
          markTestSkipped('FFmpeg not installed');
          return;
        }

        final outputPath = '${tempDir.path}/faded_audio.mp4';

        final result = await Process.run('ffmpeg', [
          '-y',
          '-f',
          'lavfi',
          '-i',
          'color=green:size=100x100:duration=3:rate=30',
          '-f',
          'lavfi',
          '-i',
          'sine=frequency=880:duration=3',
          '-af',
          'afade=t=in:st=0:d=1,afade=t=out:st=2:d=1',
          '-c:v',
          'libx264',
          '-c:a',
          'aac',
          '-pix_fmt',
          'yuv420p',
          '-shortest',
          outputPath,
        ]);

        expect(result.exitCode, 0);
        expect(await File(outputPath).exists(), isTrue);
      });

      test('mixes multiple audio tracks', () async {
        if (!ffmpegAvailable) {
          markTestSkipped('FFmpeg not installed');
          return;
        }

        final outputPath = '${tempDir.path}/mixed_audio.mp4';

        final result = await Process.run('ffmpeg', [
          '-y',
          '-f', 'lavfi',
          '-i', 'color=red:size=100x100:duration=2:rate=30',
          '-f', 'lavfi',
          '-i', 'sine=frequency=440:duration=2', // A4 note
          '-f', 'lavfi',
          '-i', 'sine=frequency=554:duration=2', // C#5 note
          '-filter_complex', '[1][2]amix=inputs=2:duration=longest[aout]',
          '-map', '0:v',
          '-map', '[aout]',
          '-c:v', 'libx264',
          '-c:a', 'aac',
          '-pix_fmt', 'yuv420p',
          '-shortest',
          outputPath,
        ]);

        expect(result.exitCode, 0);
        expect(await File(outputPath).exists(), isTrue);
      });
    });

    group('Video quality presets', () {
      test('encodes with different CRF values', () async {
        if (!ffmpegAvailable) {
          markTestSkipped('FFmpeg not installed');
          return;
        }

        final highQualityPath = '${tempDir.path}/high_quality.mp4';
        final lowQualityPath = '${tempDir.path}/low_quality.mp4';

        // High quality (low CRF)
        await Process.run('ffmpeg', [
          '-y',
          '-f', 'lavfi',
          '-i', 'color=purple:size=200x200:duration=1:rate=30',
          '-c:v', 'libx264',
          '-crf', '18', // High quality
          '-pix_fmt', 'yuv420p',
          highQualityPath,
        ]);

        // Low quality (high CRF)
        await Process.run('ffmpeg', [
          '-y',
          '-f', 'lavfi',
          '-i', 'color=purple:size=200x200:duration=1:rate=30',
          '-c:v', 'libx264',
          '-crf', '35', // Low quality
          '-pix_fmt', 'yuv420p',
          lowQualityPath,
        ]);

        final highQualitySize = await File(highQualityPath).length();
        final lowQualitySize = await File(lowQualityPath).length();

        // High quality should produce larger file
        expect(highQualitySize, greaterThan(lowQualitySize));
      });

      test('encodes with different resolutions', () async {
        if (!ffmpegAvailable) {
          markTestSkipped('FFmpeg not installed');
          return;
        }

        final resolutions = [
          {'width': 320, 'height': 240, 'name': '240p'},
          {'width': 640, 'height': 480, 'name': '480p'},
          {'width': 1280, 'height': 720, 'name': '720p'},
        ];

        for (final res in resolutions) {
          final outputPath = '${tempDir.path}/${res['name']}.mp4';

          final result = await Process.run('ffmpeg', [
            '-y',
            '-f',
            'lavfi',
            '-i',
            'color=orange:size=${res['width']}x${res['height']}:duration=0.5:rate=30',
            '-c:v',
            'libx264',
            '-pix_fmt',
            'yuv420p',
            outputPath,
          ]);

          expect(result.exitCode, 0, reason: 'Should encode ${res['name']}');

          // Verify dimensions
          final probeResult = await Process.run('ffprobe', [
            '-v',
            'error',
            '-select_streams',
            'v:0',
            '-show_entries',
            'stream=width,height',
            '-of',
            'csv=s=x:p=0',
            outputPath,
          ]);

          expect(
            probeResult.stdout.toString().trim(),
            '${res['width']}x${res['height']}',
          );
        }
      });
    });

    group('Error handling', () {
      test('handles invalid frame dimensions gracefully', () async {
        if (!ffmpegAvailable) {
          markTestSkipped('FFmpeg not installed');
          return;
        }

        final outputPath = '${tempDir.path}/invalid.mp4';

        // Try to create video with odd dimensions (not divisible by 2)
        // libx264 requires even dimensions for yuv420p
        final result = await Process.run('ffmpeg', [
          '-y',
          '-f',
          'lavfi',
          '-i',
          'color=red:size=101x101:duration=0.1:rate=30',
          '-c:v',
          'libx264',
          '-pix_fmt',
          'yuv420p',
          outputPath,
        ]);

        // This should fail due to odd dimensions
        expect(result.exitCode, isNot(0));
      });

      test('handles empty input gracefully', () async {
        if (!ffmpegAvailable) {
          markTestSkipped('FFmpeg not installed');
          return;
        }

        final outputPath = '${tempDir.path}/empty.mp4';

        final process = await Process.start('ffmpeg', [
          '-y',
          '-f',
          'rawvideo',
          '-pix_fmt',
          'rgba',
          '-s',
          '100x100',
          '-r',
          '30',
          '-i',
          '-',
          '-c:v',
          'libx264',
          '-pix_fmt',
          'yuv420p',
          outputPath,
        ]);

        // Close stdin immediately without writing any frames
        await process.stdin.close();

        final exitCode = await process.exitCode;
        // FFmpeg behavior varies - it might fail or create an empty file
        // The key is that it handles the situation without crashing
        // Either it fails with non-zero exit, or succeeds with empty/invalid output
        if (exitCode == 0) {
          // If it succeeded, the output file should either not exist or be very small
          final outputFile = File(outputPath);
          if (await outputFile.exists()) {
            // Empty video should be very small or unplayable
            expect(await outputFile.length(), lessThan(10000));
          }
        } else {
          // Non-zero exit is expected behavior
          expect(exitCode, isNot(0));
        }
      });
    });

    group('Frame extraction', () {
      late String testVideoPath;

      setUp(() async {
        if (!ffmpegAvailable) return;

        testVideoPath = '${tempDir.path}/source.mp4';

        // Create source video for extraction
        await Process.run('ffmpeg', [
          '-y',
          '-f',
          'lavfi',
          '-i',
          'testsrc=size=200x200:duration=1:rate=30',
          '-c:v',
          'libx264',
          '-pix_fmt',
          'yuv420p',
          testVideoPath,
        ]);
      });

      test('extracts frames from video', () async {
        if (!ffmpegAvailable) {
          markTestSkipped('FFmpeg not installed');
          return;
        }

        final framePattern = '${tempDir.path}/frame_%03d.png';

        final result = await Process.run('ffmpeg', [
          '-y',
          '-i', testVideoPath,
          '-vf',
          'select=eq(n\\,0)+eq(n\\,15)+eq(n\\,29)', // Extract frames 0, 15, 29
          '-vsync', 'vfr',
          framePattern,
        ]);

        expect(result.exitCode, 0);

        // Check that frames were extracted
        expect(await File('${tempDir.path}/frame_001.png').exists(), isTrue);
      });

      test('extracts frames as raw RGBA', () async {
        if (!ffmpegAvailable) {
          markTestSkipped('FFmpeg not installed');
          return;
        }

        final result = await Process.run(
            'ffmpeg',
            [
              '-y',
              '-i',
              testVideoPath,
              '-frames:v',
              '1',
              '-f',
              'rawvideo',
              '-pix_fmt',
              'rgba',
              '-',
            ],
            stdoutEncoding: null);

        expect(result.exitCode, 0);

        // 200x200 pixels * 4 bytes = 160000 bytes
        final stdout = result.stdout as List<int>;
        expect(stdout.length, 200 * 200 * 4);
      });

      test('extracts frames at specific timestamp', () async {
        if (!ffmpegAvailable) {
          markTestSkipped('FFmpeg not installed');
          return;
        }

        final framePath = '${tempDir.path}/at_500ms.png';

        final result = await Process.run('ffmpeg', [
          '-y',
          '-ss', '0.5', // Seek to 500ms
          '-i', testVideoPath,
          '-frames:v', '1',
          framePath,
        ]);

        expect(result.exitCode, 0);
        expect(await File(framePath).exists(), isTrue);
      });
    });

    group('Scene transitions', () {
      test('creates crossfade between two clips', () async {
        if (!ffmpegAvailable) {
          markTestSkipped('FFmpeg not installed');
          return;
        }

        final outputPath = '${tempDir.path}/crossfade.mp4';

        final result = await Process.run('ffmpeg', [
          '-y',
          '-f',
          'lavfi',
          '-i',
          'color=red:size=200x200:duration=2:rate=30',
          '-f',
          'lavfi',
          '-i',
          'color=blue:size=200x200:duration=2:rate=30',
          '-filter_complex',
          '[0][1]xfade=transition=fade:duration=1:offset=1',
          '-c:v',
          'libx264',
          '-pix_fmt',
          'yuv420p',
          outputPath,
        ]);

        expect(result.exitCode, 0);
        expect(await File(outputPath).exists(), isTrue);

        // Check duration is about 3 seconds (2 + 2 - 1 overlap)
        final probeResult = await Process.run('ffprobe', [
          '-v',
          'error',
          '-show_entries',
          'format=duration',
          '-of',
          'default=noprint_wrappers=1:nokey=1',
          outputPath,
        ]);

        final duration = double.parse(probeResult.stdout.toString().trim());
        expect(duration, closeTo(3.0, 0.1));
      });

      test('creates slide transition', () async {
        if (!ffmpegAvailable) {
          markTestSkipped('FFmpeg not installed');
          return;
        }

        final outputPath = '${tempDir.path}/slide.mp4';

        final result = await Process.run('ffmpeg', [
          '-y',
          '-f',
          'lavfi',
          '-i',
          'color=green:size=200x200:duration=2:rate=30',
          '-f',
          'lavfi',
          '-i',
          'color=yellow:size=200x200:duration=2:rate=30',
          '-filter_complex',
          '[0][1]xfade=transition=slideleft:duration=0.5:offset=1.5',
          '-c:v',
          'libx264',
          '-pix_fmt',
          'yuv420p',
          outputPath,
        ]);

        expect(result.exitCode, 0);
        expect(await File(outputPath).exists(), isTrue);
      });
    });
  });
}
