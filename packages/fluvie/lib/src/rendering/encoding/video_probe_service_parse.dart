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
  Future<VideoProbeResult> _parse(String stdout, String filePath) async {
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
    final rawFrames = video['nb_frames'];
    final rawDuration = _rawDuration(video, report['format']);
    final seconds = rawDuration == null ? null : double.tryParse(rawDuration);
    final nbFrames =
        (rawFrames is String ? int.tryParse(rawFrames) : null) ??
        await _deriveFrameCount(filePath, fps: fps, seconds: seconds) ??
        _unusable(filePath, field: 'nb_frames', raw: rawFrames);
    return VideoProbeResult(
      codec: codec,
      width: width,
      height: height,
      nbFrames: nbFrames,
      durationSeconds:
          seconds ??
          _deriveDuration(nbFrames, fps) ??
          _unusable(filePath, field: 'duration', raw: rawDuration),
      declaredFps: fps,
      hasAudio: hasAudio,
      hasAlpha: _hasAlpha(video),
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

/// The ffprobe report as a JSON object, or a typed error naming [filePath].
Map<String, Object?> _decodeReport(String stdout, String filePath) {
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
  return decoded;
}

/// The duration string ffprobe reported, preferring the stream's own over the
/// container's (Matroska carries only the container's).
String? _rawDuration(Map<String, Object?> video, Object? format) {
  final stream = video['duration'];
  if (stream is String) return stream;
  final container = format is Map<String, Object?> ? format['duration'] : null;
  return container is String ? container : null;
}

/// The seconds a [nbFrames]-long stream runs for at [fps], or null when the
/// frame rate is unknown.
double? _deriveDuration(int nbFrames, double? fps) =>
    fps != null && fps > 0 ? nbFrames / fps : null;

/// The stream's frame rate, or null when ffprobe reports none.
///
/// `avg_frame_rate` is asked first because `r_frame_rate` is the lowest rate
/// that can represent every timestamp exactly, which for a variable-rate source
/// (a screen capture, phone footage) is a multiple of the real rate: 600/1 for a
/// clip that runs at 30. The average is the honest rate there, and for a
/// constant-rate source the two agree.
double? _frameRate(Map<String, Object?> video) =>
    _parseRational(video['avg_frame_rate']) ?? _parseRational(video['r_frame_rate']);

/// Parses an ffprobe frame rate, written as a rational string (`30/1`,
/// `30000/1001`). A zero denominator is ffprobe for "unknown", so it reads as
/// null rather than as an error.
double? _parseRational(Object? raw) {
  if (raw is! String) return null;
  final parts = raw.split('/');
  if (parts.length != 2) return double.tryParse(raw);
  final numerator = double.tryParse(parts[0]);
  final denominator = double.tryParse(parts[1]);
  if (numerator == null || denominator == null || denominator == 0) return null;
  return numerator / denominator;
}

/// Whether the stream is tagged as carrying a coded alpha layer.
///
/// Matroska writes the tag as `ALPHA_MODE`; the lookup is case-insensitive
/// because ffprobe echoes back whatever spelling the muxer wrote.
bool _hasAlpha(Map<String, Object?> video) {
  final tags = video['tags'];
  if (tags is! Map<String, Object?>) return false;
  for (final entry in tags.entries) {
    if (entry.key.toLowerCase() == 'alpha_mode') return entry.value == '1';
  }
  return false;
}

/// Reports a [field] that is neither reported nor derivable: the field-naming
/// error when ffprobe reported garbage, the missing-fields error when it
/// reported nothing at all.
Never _unusable(String filePath, {required String field, required Object? raw}) {
  if (raw is String) {
    throw FluvieRenderException(
      'ffprobe reported a non-numeric $field ("$raw") for "$filePath".',
    );
  }
  throw _missingFields(filePath);
}

FluvieRenderException _missingFields(String filePath) => FluvieRenderException(
  'ffprobe report for "$filePath" is missing video-stream fields '
  '(codec_name/width/height/nb_frames/duration).',
);
