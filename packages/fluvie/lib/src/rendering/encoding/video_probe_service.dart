import 'dart:convert';
import 'dart:io';

import 'package:fluvie/src/core/errors/fluvie_encode_exception.dart';
import 'package:fluvie/src/core/errors/fluvie_render_exception.dart';
import 'package:fluvie/src/media/media_providers_common.dart';
import 'package:fluvie/src/rendering/platform/process_runner.dart';
import 'package:fluvie_media/fluvie_media.dart' show MediaTimeline;
import 'package:fluvie_media/native.dart'
    show FfmpegMediaTools, FfmpegTimelineTools, MediaProcessException, resolveMediaExecutable;
import 'package:riverpod/riverpod.dart';

part 'video_probe_service_parse.dart';
part 'video_probe_report_values.dart';
part 'video_probe_service_native.dart';

/// Reads the stream facts of an encoded video file (codec, size, frame
/// count, duration) — what the determinism tests assert against.
// ignore: one_member_abstracts — new-service seam; ffprobe is mocked behind its provider.
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
  ///
  /// Pass [declaredFps] when the container declares a frame rate of its own; a
  /// probe that cannot read one leaves it null and [fps] derives the rate.
  const VideoProbeResult({
    required this.codec,
    required this.width,
    required this.height,
    required this.nbFrames,
    required this.durationSeconds,
    this.declaredFps,
    this.hasAudio = false,
    this.hasAlpha = false,
    this.rotationDegrees = 0,
    this.timeline,
  });

  /// The codec name of the first video stream (for example `h264`).
  final String codec;

  /// Display width in pixels, after the container's rotation is applied.
  final int width;

  /// Display height in pixels, after the container's rotation is applied.
  final int height;

  /// The frame count of the video stream.
  ///
  /// Containers that store no frame count (Matroska/WebM never do) have it
  /// counted or derived by the probe, so this is always a real count.
  final int nbFrames;

  /// The duration in seconds.
  final double durationSeconds;

  /// The frame rate the container declares, or null when it declares none or
  /// declares it unknown (`0/0`). Read [fps] instead of this: it falls back to
  /// the derived rate.
  final double? declaredFps;

  /// The stream's frame rate: the declared rate when there is one, else the
  /// frame count over the duration.
  ///
  /// Declared wins because the derived rate inherits every inaccuracy in the
  /// duration. A WebM's duration is the container's (it stores no per-stream
  /// one), which spans the audio tail: a true-30fps clip whose audio runs
  /// 17ms past its video derives as 29.86fps and resamples to the wrong source
  /// frames. The rate is a rational for the same reason, so NTSC's 30000/1001
  /// stays 29.97 rather than rounding to 30.
  double get fps {
    final declared = declaredFps;
    if (declared != null && declared > 0) return declared;
    return durationSeconds > 0 ? nbFrames / durationSeconds : nbFrames.toDouble();
  }

  /// Whether the file carries at least one audio stream.
  final bool hasAudio;

  /// Whether the video stream carries a coded alpha layer.
  ///
  /// Matroska/WebM flags this with the `ALPHA_MODE` stream tag. VP9 codes alpha
  /// as a second layer that only the `libvpx-vp9` decoder reads, so the clip
  /// path selects that decoder when this is true.
  final bool hasAlpha;

  /// Display rotation reported by ffprobe, normalized to 0–359 degrees.
  final int rotationDegrees;

  /// Optional exact presentation timing, normalized to the first picture.
  /// Legacy probes can omit it and keep constant-rate resampling.
  final MediaTimeline? timeline;
}

/// The real [VideoProbeService]: spawns `ffprobe` through a [ProcessRunner]
/// with an argument array and parses its JSON report.
final class FfprobeVideoProbeService implements VideoProbeService {
  /// Creates a probe service running `binaryPath` (default: `ffprobe` on
  /// `PATH`) through `runner`.
  const FfprobeVideoProbeService({
    this._runner = const IoProcessRunner(),
    String? binaryPath,
    this.whenCancelled,
  }) : _explicitBinaryPath = binaryPath;

  final ProcessRunner _runner;
  final String? _explicitBinaryPath;

  /// Stops owned native probing when the render session is cancelled.
  final Future<void>? whenCancelled;

  String get _binaryPath => resolveMediaExecutable('ffprobe', explicit: _explicitBinaryPath);

  @override
  Future<VideoProbeResult> probe(String filePath) async {
    if (!File(filePath).existsSync()) {
      throw FluvieRenderException('Cannot probe "$filePath": the file does not exist.');
    }
    if (_runner is IoProcessRunner) return _probeNative(filePath);
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
}

/// The video probe used by determinism checks and tooling; defaults to
/// [FfprobeVideoProbeService] over [processRunnerProvider] and is overridable
/// in tests.
final videoProbeServiceProvider = Provider<VideoProbeService>(
  (ref) => FfprobeVideoProbeService(
    runner: ref.watch(processRunnerProvider),
    whenCancelled: ref.watch(mediaCancellationProvider),
  ),
);
