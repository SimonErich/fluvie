import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:fluvie_cli/src/process_runner.dart';
import 'package:fluvie_media/native.dart';

part 'output_verification_compare.dart';
part 'output_verification_facts.dart';
part 'output_verification_sequence.dart';

/// Checks an encoded file or PNG sequence against the resolved render intent.
///
/// [expected] accepts width, height, fps, frameCount, durationSeconds, codec,
/// container, pixelFormat, hasAudio and hasAlpha. Omitted keys are unconstrained.
/// Frame rate tolerance is 0.1%; duration allows one video frame or 50ms for
/// container rounding and audio padding. [strictDecode] additionally decodes
/// every video picture and audio sample, rejecting corrupt payloads. Returns a
/// versioned JSON report with `ok`, `observed`, `mismatches` and the raw `probe`.
/// Cancellation stops processes owned here; an injected [runner] owns its jobs.
Future<Map<String, Object?>> verifyOutput(
  String path, {
  Map<String, Object?> expected = const {},
  bool strictDecode = false,
  String? ffmpegBinary,
  String? ffprobeBinary,
  ProcessRunner? runner,
  Future<void>? whenCancelled,
}) async {
  _validateIntent(expected);
  final tools = FfmpegMediaTools(
    ffmpegPath: ffmpegBinary,
    ffprobePath: ffprobeBinary,
    timeout: const Duration(minutes: 10),
    runner: runner == null || runner is IoProcessRunner
        ? null
        : (executable, arguments, {workingDirectory}) async {
            final result = await runner.run(
              executable,
              arguments,
              workingDirectory: workingDirectory,
            );
            return (exitCode: result.exitCode, stdout: result.stdout, stderr: result.stderr);
          },
  );
  if (Directory(path).existsSync()) {
    try {
      return await _verifySequence(tools, path, expected, strictDecode, whenCancelled);
    } finally {
      await tools.closeAsync();
    }
  }
  final mismatches = <Map<String, Object?>>[];
  var observed = <String, Object?>{};
  Map<String, Object?>? probe;
  try {
    probe = await tools.probeReport(path, whenCancelled: whenCancelled);
    observed = _mediaFacts(probe);
    if (observed['width'] == null || observed['height'] == null) {
      mismatches.add({'code': 'videoStream', 'expected': 'readable video', 'actual': null});
    } else {
      if (expected.containsKey('frameCount') && observed['frameCount'] == null) {
        final counted = await tools.run(tools.ffprobePath, [
          '-v',
          'error',
          '-select_streams',
          'v:0',
          '-count_frames',
          '-show_entries',
          'stream=nb_read_frames',
          '-of',
          'json',
          path,
        ], whenCancelled: whenCancelled);
        if (counted.exitCode != 0) {
          throw MediaProcessException('Counting encoded frames failed.', stderr: counted.stderr);
        }
        final decoded = jsonDecode(counted.stdout);
        if (decoded is Map<String, Object?> && decoded['streams'] is List<Object?>) {
          final streams = decoded['streams']! as List<Object?>;
          if (streams.isNotEmpty && streams.first is Map<String, Object?>) {
            final count = int.tryParse(
              '${(streams.first! as Map<String, Object?>)['nb_read_frames']}',
            );
            if (count != null) observed['frameCount'] = count;
          }
        }
      }
      mismatches.addAll(_compareIntent(expected, observed));
      if (strictDecode) {
        final decoded = await tools.run(tools.ffmpegPath, [
          '-v',
          'error',
          '-xerror',
          '-nostdin',
          '-i',
          path,
          '-map',
          '0:v:0',
          '-map',
          '0:a?',
          '-f',
          'null',
          '-',
        ], whenCancelled: whenCancelled);
        if (decoded.exitCode != 0) {
          mismatches.add({
            'code': 'decode',
            'expected': 'complete decode',
            'actual': decoded.stderr,
          });
        }
      }
    }
  } on MediaProcessException catch (error) {
    mismatches.add({'code': 'probe', 'expected': 'readable video', 'actual': error.toString()});
  } on FormatException catch (error) {
    mismatches.add({'code': 'probe', 'expected': 'valid probe report', 'actual': error.message});
  } on TimeoutException {
    mismatches.add({'code': 'timeout', 'expected': 'verification completes', 'actual': path});
  } finally {
    await tools.closeAsync();
  }
  return {
    'schemaVersion': 1,
    'ok': mismatches.isEmpty,
    'strictDecode': strictDecode,
    'observed': observed,
    'mismatches': mismatches,
    'probe': ?probe,
  };
}
