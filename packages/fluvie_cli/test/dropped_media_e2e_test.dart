@Tags(['ffmpeg'])
@Timeout(Duration(minutes: 8))
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

const _composition = '''
import 'package:flutter/widgets.dart' hide Animation, Clip, Image, Tween;
import 'package:fluvie/fluvie.dart';

// Ordinary Flutter widgets can hide media until the composition is mounted.
class CatMoments extends StatelessWidget {
  const CatMoments({super.key});

  @override
  Widget build(BuildContext context) => Center(
    child: SizedBox(
      width: 64,
      height: 48,
      child: Clip.asset(
        'assets/cat/chapter1/first_steps.mp4',
        audio: const ClipAudio.included(volume: 0.8),
      ).show(from: 6.frames, to: 30.frames),
    ),
  );
}

Video build() => Video(
  width: 96,
  height: 80,
  fps: 12,
  audio: const [
    Audio.musicSource(
      AudioSource.asset('assets/cat/chapter1/audio/song.wav'),
      volume: 0.4,
    ),
  ],
  scenes: [
    Scene(
      duration: 30.frames,
      background: Background.color(const Color(0xff000000)),
      children: const [CatMoments()],
    ),
  ],
);
''';

void main() {
  test(
    'dropped nested clip and song render through mounted Flutter with exact pictures and sound',
    () async {
      final root = p.normalize(p.join(Directory.current.path, '../..'));
      final project = await Directory.systemTemp.createTemp('fluvie_dropped_media_e2e_');
      if (Platform.environment['FLUVIE_TEST_KEEP_PROJECT'] != '1') {
        addTearDown(() => project.delete(recursive: true));
      }
      final ffmpeg = Platform.environment['FLUVIE_TEST_FFMPEG'] ?? 'ffmpeg';
      final ffprobe = Platform.environment['FLUVIE_TEST_FFPROBE'] ?? 'ffprobe';
      Future<ProcessResult> run(
        String executable,
        List<String> arguments, {
        bool binary = false,
      }) async {
        final process = await Process.start(executable, arguments, workingDirectory: project.path);
        final output = process.stdout.fold<BytesBuilder>(
          BytesBuilder(),
          (bytes, value) => bytes..add(value),
        );
        final errors = utf8.decoder.bind(process.stderr).join();
        final int code;
        try {
          code = await process.exitCode.timeout(const Duration(minutes: 3));
        } on TimeoutException {
          process.kill(ProcessSignal.sigkill);
          rethrow;
        }
        final bytes = (await output).takeBytes();
        final stderr = await errors;
        expect(
          code,
          0,
          reason:
              '$executable ${arguments.join(' ')}\n'
              '${binary ? '${bytes.length} output bytes' : utf8.decode(bytes, allowMalformed: true)}\n$stderr',
        );
        return ProcessResult(process.pid, code, binary ? bytes : utf8.decode(bytes), stderr);
      }

      await run('flutter', [
        'create',
        '--empty',
        '--no-pub',
        '--platforms=web',
        '--project-name',
        'fluvie_dropped_media_e2e',
        project.path,
      ]);
      final pubspec = File(p.join(project.path, 'pubspec.yaml'));
      await pubspec.writeAsString(
        jsonEncode({
          'name': 'fluvie_dropped_media_e2e',
          'environment': {'sdk': '^3.12.0'},
          'dependencies': {
            'flutter': {'sdk': 'flutter'},
            'fluvie': {'path': p.join(root, 'packages/fluvie')},
          },
          'dependency_overrides': {
            'fluvie': {'path': p.join(root, 'packages/fluvie')},
            'fluvie_media': {'path': p.join(root, 'packages/fluvie_media')},
          },
          'dev_dependencies': {
            'flutter_test': {'sdk': 'flutter'},
          },
        }),
      );
      await run('flutter', ['pub', 'get']);
      final originalManifest = pubspec.readAsStringSync();
      final originalLock = File(p.join(project.path, 'pubspec.lock')).readAsStringSync();
      final clipPath = p.join(project.path, 'assets/cat/chapter1/first_steps.mp4');
      final songPath = p.join(project.path, 'assets/cat/chapter1/audio/song.wav');
      await File(songPath).parent.create(recursive: true);
      await run(ffmpeg, [
        '-y',
        '-v',
        'error',
        '-f',
        'lavfi',
        '-i',
        'color=c=red:s=64x48:r=12:d=0.5',
        '-f',
        'lavfi',
        '-i',
        'color=c=lime:s=64x48:r=12:d=0.5',
        '-f',
        'lavfi',
        '-i',
        'color=c=blue:s=64x48:r=12:d=0.5',
        '-f',
        'lavfi',
        '-i',
        'sine=frequency=440:sample_rate=48000:duration=1.5',
        '-filter_complex',
        '[0:v][1:v][2:v]concat=n=3:v=1:a=0[v]',
        '-map',
        '[v]',
        '-map',
        '3:a',
        '-c:v',
        'libx264',
        '-pix_fmt',
        'yuv420p',
        '-c:a',
        'aac',
        '-shortest',
        clipPath,
      ]);
      await run(ffmpeg, [
        '-y',
        '-v',
        'error',
        '-f',
        'lavfi',
        '-i',
        'sine=frequency=880:sample_rate=48000:duration=2.5',
        '-c:a',
        'pcm_s16le',
        songPath,
      ]);
      await File(p.join(project.path, 'lib/cat_video.dart')).writeAsString(_composition);
      final rendered = await run('dart', [
        '--packages=${p.join(root, '.dart_tool/package_config.json')}',
        p.join(root, 'packages/fluvie_cli/bin/fluvie.dart'),
        'render',
        'lib/cat_video.dart',
        '--toolchain',
        'system',
        '--ffmpeg',
        ffmpeg,
        '--ffprobe',
        ffprobe,
        '--no-cache',
        '--machine',
      ]);
      final events = const LineSplitter()
          .convert(rendered.stdout as String)
          .map((line) => jsonDecode(line) as Map<String, Object?>)
          .toList();
      final artifact = events.last;
      expect(artifact['event'], 'artifact');
      expect(events.any((event) => event['completed'] == 30 && event['total'] == 30), isTrue);
      final receipt =
          jsonDecode(File(artifact['receiptPath']! as String).readAsStringSync())
              as Map<String, Object?>;
      final output = receipt['output']! as Map<String, Object?>;
      final media = output['media']! as Map<String, Object?>;
      expect(media['codec'], 'h264');
      expect(media['width'], 96);
      expect(media['height'], 80);
      expect(media['declaredFrameCount'], 30);
      final audio = (media['audio']! as List).cast<Map<String, Object?>>();
      expect(audio, hasLength(1));
      expect(audio.single['codec'], 'aac');
      expect(pubspec.readAsStringSync(), originalManifest);
      expect(File(p.join(project.path, 'pubspec.lock')).readAsStringSync(), originalLock);
      expect(originalManifest, isNot(contains('assets')));
      expect(Directory(p.join(project.path, '.fluvie')).existsSync(), isFalse);

      final outputPath = artifact['filePath']! as String;
      final decoded = await run(ffmpeg, [
        '-v',
        'error',
        '-i',
        outputPath,
        '-map',
        '0:v',
        '-f',
        'rawvideo',
        '-pix_fmt',
        'rgb24',
        'pipe:1',
      ], binary: true);
      final pixels = decoded.stdout as Uint8List;
      const frameBytes = 96 * 80 * 3;
      expect(pixels, hasLength(30 * frameBytes));
      List<int> pixel(int frame, int x, int y) {
        final offset = frame * frameBytes + (y * 96 + x) * 3;
        return pixels.sublist(offset, offset + 3);
      }

      for (var frame = 0; frame < 30; frame++) {
        final center = pixel(frame, 48, 40);
        if (frame < 6) {
          expect(
            center.every((channel) => channel < 12),
            isTrue,
            reason: 'future clip at frame $frame: $center',
          );
        } else {
          final expectedChannel = frame < 12
              ? 0
              : frame < 18
              ? 1
              : 2;
          expect(center[expectedChannel], greaterThan(220), reason: 'frame $frame: $center');
          expect(
            [
              for (var channel = 0; channel < 3; channel++)
                if (channel != expectedChannel) center[channel],
            ].every((channel) => channel < 25),
            isTrue,
          );
        }
        expect(pixel(frame, 2, 2).every((channel) => channel < 12), isTrue);
      }
      final pcm = await run(ffmpeg, [
        '-v',
        'error',
        '-i',
        outputPath,
        '-map',
        '0:a',
        '-f',
        'f32le',
        '-ac',
        '1',
        '-ar',
        '48000',
        'pipe:1',
      ], binary: true);
      final samples = Float32List.view((pcm.stdout as Uint8List).buffer);
      expect(
        _toneAmplitude(samples, 880, 0.2),
        greaterThan(0.008),
        reason: 'dropped song plays before the clip',
      );
      expect(
        _toneAmplitude(samples, 440, 0.2),
        lessThan(0.004),
        reason: 'embedded audio respects the future window',
      );
      expect(
        _toneAmplitude(samples, 440, 1),
        greaterThan(0.008),
        reason: 'mounted clip audio reaches the mix',
      );
      expect(
        _toneAmplitude(samples, 880, 1),
        greaterThan(0.008),
        reason: 'song and embedded audio are layered',
      );
      expect(
        _toneAmplitude(samples, 880, 2.3),
        greaterThan(0.008),
        reason: 'song continues over the held last picture',
      );
      expect(
        _toneAmplitude(samples, 440, 2.3),
        lessThan(0.004),
        reason: 'holding the last picture does not repeat embedded audio',
      );
    },
  );
}

double _toneAmplitude(Float32List samples, double frequency, double fromSeconds) {
  const count = 4800;
  final start = (fromSeconds * 48000).round();
  var sine = 0.0;
  var cosine = 0.0;
  for (var index = 0; index < count; index++) {
    final phase = 2 * math.pi * frequency * index / 48000;
    sine += samples[start + index] * math.sin(phase);
    cosine += samples[start + index] * math.cos(phase);
  }
  return 2 * math.sqrt(sine * sine + cosine * cosine) / count;
}
