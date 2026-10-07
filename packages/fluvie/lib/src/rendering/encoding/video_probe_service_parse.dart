part of 'video_probe_service.dart';

/// The report-reading half of [FfprobeVideoProbeService]: turns one ffprobe
/// JSON report into a [VideoProbeResult], deriving the facts a container does
/// not store.
///
/// Matroska/WebM keeps no frame-count header and no per-stream duration, so its
/// report carries neither `nb_frames` nor a stream `duration`. The frame count
/// is then counted exactly with a second `-count_frames` pass, or failing that
/// derived from duration x frame rate; the duration falls back to the container's
/// and then to frame count over frame rate. A container that reports its own
/// values pays for none of this.
extension _ProbeParsing on FfprobeVideoProbeService {
  Future<VideoProbeResult> _parse(String stdout, String filePath, {MediaTimeline? timeline}) async {
    final report = _decodeReport(stdout, filePath);
    final streams = report['streams'];
    final video = streams is List<Object?>
        ? streams.whereType<Map<String, Object?>>().firstWhere(
            (s) => s['codec_type'] == 'video',
            orElse: () => const {},
          )
        : const <String, Object?>{};
    final hasAudio =
        streams is List<Object?> &&
        streams.whereType<Map<String, Object?>>().any((s) => s['codec_type'] == 'audio');
    final codec = video['codec_name'];
    final width = video['width'];
    final height = video['height'];
    if (codec is! String || width is! int || height is! int) {
      throw _missingFields(filePath);
    }
    final fps = _frameRate(video);
    final rotation = _rotation(video);
    final rawFrames = video['nb_frames'];
    final rawDuration = _rawDuration(video, report['format']);
    final seconds = rawDuration == null ? null : double.tryParse(rawDuration);
    final nbFrames =
        timeline?.frameCount ??
        (rawFrames is String ? int.tryParse(rawFrames) : null) ??
        await _deriveFrameCount(filePath, fps: fps, seconds: seconds) ??
        _unusable(filePath, field: 'nb_frames', raw: rawFrames);
    return VideoProbeResult(
      codec: codec,
      width: rotation == 90 || rotation == 270 ? height : width,
      height: rotation == 90 || rotation == 270 ? width : height,
      nbFrames: nbFrames,
      durationSeconds:
          timeline?.durationSeconds ??
          seconds ??
          _deriveDuration(nbFrames, fps) ??
          _unusable(filePath, field: 'duration', raw: rawDuration),
      declaredFps: fps,
      hasAudio: hasAudio,
      hasAlpha: _hasAlpha(video),
      rotationDegrees: rotation,
      timeline: timeline,
    );
  }

  /// The frame count for a stream that reported none: exact when a
  /// `-count_frames` pass produces one, else duration x frame rate, else null.
  Future<int?> _deriveFrameCount(String filePath, {double? fps, double? seconds}) async {
    final counted = await _countFrames(filePath);
    if (counted != null) return counted;
    if (fps == null || fps <= 0 || seconds == null || seconds <= 0) return null;
    return (seconds * fps).round();
  }

  /// The exact frame count from a second `-count_frames` ffprobe pass, or null
  /// when it cannot report one.
  ///
  /// The pass decodes every video packet, so it only ever runs for a container
  /// that stored no frame count of its own. A failure here is not fatal: the
  /// caller still has the duration x frame rate fallback.
  Future<int?> _countFrames(String filePath) async {
    final result = await _runner.run(_binaryPath, [
      '-v',
      'error',
      '-count_frames',
      '-select_streams',
      'v:0',
      '-print_format',
      'json',
      '-show_entries',
      'stream=nb_read_frames',
      filePath,
    ]);
    if (result.exitCode != 0) return null;
    final Object? decoded;
    try {
      decoded = jsonDecode(result.stdout);
    } on FormatException {
      return null;
    }
    if (decoded is! Map<String, Object?>) return null;
    final streams = decoded['streams'];
    if (streams is! List<Object?>) return null;
    for (final stream in streams.whereType<Map<String, Object?>>()) {
      final read = stream['nb_read_frames'];
      final count = read is String ? int.tryParse(read) : null;
      if (count != null) return count;
    }
    return null;
  }
}
