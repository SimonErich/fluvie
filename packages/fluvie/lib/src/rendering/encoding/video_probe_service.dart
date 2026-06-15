import 'dart:convert';
import 'dart:io';

import 'package:fluvie/src/core/errors/fluvie_encode_exception.dart';
import 'package:fluvie/src/core/errors/fluvie_render_exception.dart';
import 'package:fluvie/src/rendering/platform/process_runner.dart';
import 'package:riverpod/riverpod.dart';

/// Reads the stream facts of an encoded video file (codec, size, frame
/// count, duration) — what the determinism tests assert against.
// One member by design: the seam is the *type* — the ffprobe-backed service
// is mocked behind its provider (new-service house pattern).
// ignore: one_member_abstracts
abstract interface class VideoProbeService {
  /// Probes the video at [filePath].
  ///
  /// Throws a `FluvieRenderException` when the file is missing or the probe
  /// output cannot be parsed, and a `FluvieEncodeException` when the probe
  /// process exits non-zero.
  Future<VideoProbeResult> probe(String filePath);
}

/// The probed facts of one video stream.
final class VideoProbeResult {
  /// Creates a result from the probed stream and container facts.
  const VideoProbeResult({
    required this.codec,
    required this.width,
    required this.height,
    required this.nbFrames,
    required this.durationSeconds,
  });

  /// The codec name of the first video stream (for example `h264`).
  final String codec;

  /// Stream width in pixels.
  final int width;

  /// Stream height in pixels.
  final int height;

  /// The container-reported frame count of the video stream.
  final int nbFrames;

  /// The container-reported duration in seconds.
  final double durationSeconds;
}

/// The real [VideoProbeService]: spawns `ffprobe` through a [ProcessRunner]
/// with an argument array and parses its JSON report.
final class FfprobeVideoProbeService implements VideoProbeService {
  /// Creates a probe service running `binaryPath` (default: `ffprobe` on
  /// `PATH`) through `runner`.
  const FfprobeVideoProbeService({
    this._runner = const IoProcessRunner(),
    this._binaryPath = 'ffprobe',
  });

  final ProcessRunner _runner;
  final String _binaryPath;

  @override
  Future<VideoProbeResult> probe(String filePath) async {
    if (!File(filePath).existsSync()) {
      throw FluvieRenderException('Cannot probe "$filePath": the file does not exist.');
    }
    final result = await _runner.run(_binaryPath, [
      '-v',
      'error',
      '-print_format',
      'json',
      '-show_streams',
      '-show_format',
      filePath,
    ]);
    if (result.exitCode != 0) {
      throw FluvieEncodeException(
        'ffprobe ("$_binaryPath") exited non-zero while probing "$filePath".',
        exitCode: result.exitCode,
        stderrTail: result.stderr,
      );
    }
    return _parse(result.stdout, filePath);
  }

  static VideoProbeResult _parse(String stdout, String filePath) {
    final Object? decoded;
    try {
      decoded = jsonDecode(stdout);
    } on FormatException catch (error) {
      throw FluvieRenderException(
        'ffprobe produced unparsable JSON for "$filePath": ${error.message}',
      );
    }
    if (decoded is! Map<String, Object?>) {
      throw FluvieRenderException('ffprobe produced no JSON object for "$filePath".');
    }
    final streams = decoded['streams'];
    final video = streams is List<Object?>
        ? streams.whereType<Map<String, Object?>>().firstWhere(
            (s) => s['codec_type'] == 'video',
            orElse: () => const {},
          )
        : const <String, Object?>{};
    final format = decoded['format'];
    final duration = format is Map<String, Object?> ? format['duration'] : null;
    final codec = video['codec_name'];
    final width = video['width'];
    final height = video['height'];
    final nbFrames = video['nb_frames'];
    if (codec is! String ||
        width is! int ||
        height is! int ||
        nbFrames is! String ||
        duration is! String) {
      throw FluvieRenderException(
        'ffprobe report for "$filePath" is missing video-stream fields '
        '(codec_name/width/height/nb_frames/duration).',
      );
    }
    return VideoProbeResult(
      codec: codec,
      width: width,
      height: height,
      nbFrames: _parseNumeric(nbFrames, field: 'nb_frames', parse: int.parse, filePath: filePath),
      durationSeconds: _parseNumeric(
        duration,
        field: 'duration',
        parse: double.parse,
        filePath: filePath,
      ),
    );
  }

  /// Parses a numeric ffprobe string field, surfacing garbage as a
  /// [FluvieRenderException] naming [field] instead of a raw [FormatException].
  static T _parseNumeric<T>(
    String raw, {
    required String field,
    required T Function(String) parse,
    required String filePath,
  }) {
    try {
      return parse(raw);
    } on FormatException {
      throw FluvieRenderException(
        'ffprobe reported a non-numeric $field ("$raw") for "$filePath".',
      );
    }
  }
}

/// The video probe used by determinism checks and tooling; defaults to
/// [FfprobeVideoProbeService] over [processRunnerProvider] and is overridable
/// in tests.
final videoProbeServiceProvider = Provider<VideoProbeService>(
  (ref) => FfprobeVideoProbeService(runner: ref.watch(processRunnerProvider)),
);
