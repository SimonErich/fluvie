// WI-31 (Epic 15.4): the all-12-lesson render-smoke. Every gallery lesson is
// captured -> encoded -> ffprobed through the real production render path (the
// same capture shell + manifest + ffmpeg arg array the CLI drives), and the
// encoded file's video frame count is asserted to equal the lesson's
// `video.totalFrames` (== the registry entry's `frameCount`).
//
// Tagged `ffmpeg` so it stays OUT of the default `melos run test`/`gate`: it
// spawns a real ffmpeg/ffprobe (>= 6.0) and renders full-resolution lessons, so
// it is slow. One `test` per lesson keeps a single failing lesson isolated.
//
// Determinism: the harness pre-resolves all media (Image/Clip via ffmpeg,
// Mermaid/WebView/Html via the example's offline fake SnapshotService) before
// frame 0; no DateTime.now() and no unseeded Random() on the path. ffmpeg and
// ffprobe are invoked with argument LISTS, never concatenated shell strings.
@Tags(['ffmpeg'])
@Timeout(Duration(minutes: 30))
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie_example/lessons/lessons.dart';
import 'package:fluvie_example/render/composition_registry.dart';

import 'render_harness.dart';

/// The 12 gallery lesson keys, in order. `demo`/`multi_scene` are covered by the
/// CLI e2e (`packages/fluvie_cli/test/render_e2e_test.dart`); this suite is the
/// exhaustive lesson sweep.
final List<String> _lessonKeys = [for (final lesson in lessons) lesson.id];

/// Counts the encoded video stream's frames in [path] via ffprobe, invoked with
/// an argument LIST (never a shell string). Prefers the muxer's `nb_frames`; for
/// a container that does not store it, falls back to `-count_frames`'
/// `nb_read_frames` (a full decode pass).
Future<int> _probeFrameCount(String path) async {
  final report = await _probeStreams(path, countFrames: false);
  final stream = _videoStream(report, path);
  final declared = stream['nb_frames'];
  if (declared is String && int.tryParse(declared) != null) {
    return int.parse(declared);
  }
  final counted = await _probeStreams(path, countFrames: true);
  final read = _videoStream(counted, path)['nb_read_frames'];
  expect(
    read,
    isA<String>(),
    reason: 'ffprobe reported neither nb_frames nor nb_read_frames for $path',
  );
  return int.parse(read! as String);
}

/// Runs ffprobe over [path] and returns the parsed JSON report. With
/// [countFrames] it adds `-count_frames`, which decodes the whole stream to fill
/// `nb_read_frames` (slower, but exact for containers without `nb_frames`).
Future<Map<String, Object?>> _probeStreams(String path, {required bool countFrames}) async {
  final probe = await Process.run('ffprobe', [
    '-v',
    'error',
    if (countFrames) '-count_frames',
    '-select_streams',
    'v:0',
    '-print_format',
    'json',
    '-show_streams',
    path,
  ]);
  expect(probe.exitCode, 0, reason: 'ffprobe failed for $path: ${probe.stderr}');
  return jsonDecode(probe.stdout as String) as Map<String, Object?>;
}

/// The first (and only, given `-select_streams v:0`) video stream in [report].
Map<String, Object?> _videoStream(Map<String, Object?> report, String path) {
  final streams = (report['streams']! as List<Object?>).cast<Map<String, Object?>>();
  expect(streams, isNotEmpty, reason: 'no video stream in $path');
  return streams.first;
}

void main() {
  setUpAll(() async {
    const hint =
        'The 12-lesson render-smoke needs ffmpeg >= 6.0 and ffprobe on PATH '
        '(e.g. `sudo apt install ffmpeg`).';
    for (final probe in const [
      ['ffmpeg', '-version'],
      ['ffprobe', '-version'],
    ]) {
      final result = await Process.run(probe.first, [probe.last]);
      expect(result.exitCode, 0, reason: '"${probe.join(' ')}" failed. $hint');
    }
  });

  group('12-lesson render-smoke (capture -> encode -> ffprobe)', () {
    for (final key in _lessonKeys) {
      testWidgets('$key renders end-to-end and ffprobe counts video.totalFrames', (tester) async {
        final entry = compositionForKey(key)!;
        expect(entry.key, key);

        final sandbox = Directory.systemTemp.createTempSync('fluvie_smoke_${key}_');
        addTearDown(() {
          if (sandbox.existsSync()) sandbox.deleteSync(recursive: true);
        });
        final cacheRoot = Directory.systemTemp.createTempSync('fluvie_smoke_cache_${key}_');
        addTearDown(() {
          if (cacheRoot.existsSync()) cacheRoot.deleteSync(recursive: true);
        });

        // The production capture path: real media pre-resolution (ffmpeg for
        // Image/Clip, the example's offline fake SnapshotService for lesson 09),
        // the shared capture shell, RenderService, and a manifest carrying the
        // exact ffmpeg encode argument array. cacheRoot is a fresh temp so the
        // run is self-contained.
        final manifest = await runCaptureHarness(
          tester: tester,
          entry: entry,
          outDir: sandbox,
          cacheRoot: cacheRoot,
        );

        // The raw stream holds exactly one RGBA frame per declared frame.
        final framesFile = File('${sandbox.path}/${manifest.framesFileName}');
        expect(framesFile.existsSync(), isTrue, reason: '$key wrote no frames file');
        expect(
          framesFile.lengthSync(),
          entry.frameCount * entry.width * entry.height * 4,
          reason: '$key raw frames file size != frameCount * w * h * 4',
        );

        // Encode with the manifest's own ffmpeg arg array (cwd = sandbox), the
        // exact bytes the CLI would pass. Real IO escapes the fake-async clock.
        final output = File('${sandbox.path}/${manifest.outputFileName}');
        await tester.runAsync(() async {
          final encode = await Process.run(
            'ffmpeg',
            manifest.ffmpegArgs,
            workingDirectory: sandbox.path,
          );
          expect(encode.exitCode, 0, reason: '$key ffmpeg encode failed: ${encode.stderr}');
          expect(
            output.existsSync(),
            isTrue,
            reason: '$key produced no ${manifest.outputFileName}',
          );
          expect(output.lengthSync(), greaterThan(0), reason: '$key output is empty');

          // The encoded file has exactly the lesson's frame count.
          final frames = await _probeFrameCount(output.path);
          stdout.writeln(
            'fluvie-smoke: $key ${entry.width}x${entry.height}@${entry.fps} '
            'frames=$frames expected=${entry.frameCount}',
          );
          expect(
            frames,
            entry.frameCount,
            reason: '$key encoded frame count != video.totalFrames (${entry.frameCount})',
          );
        });
      });
    }
  });
}
