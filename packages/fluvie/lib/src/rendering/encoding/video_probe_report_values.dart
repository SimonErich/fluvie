part of 'video_probe_service.dart';

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
  final pixels = video['pix_fmt']?.toString() ?? '';
  if (pixels.startsWith('yuva') ||
      pixels.startsWith('gbrap') ||
      pixels.contains('rgba') ||
      pixels.contains('bgra')) {
    return true;
  }
  final tags = video['tags'];
  if (tags is! Map<String, Object?>) return false;
  for (final entry in tags.entries) {
    if (entry.key.toLowerCase() == 'alpha_mode') return entry.value == '1';
  }
  return false;
}

int _rotation(Map<String, Object?> video) {
  var rotation = 0;
  final sideData = video['side_data_list'];
  if (sideData is List<Object?>) {
    for (final item in sideData.whereType<Map<String, Object?>>()) {
      rotation = (item['rotation'] as num?)?.round() ?? rotation;
    }
  }
  final tags = video['tags'];
  if (rotation == 0 && tags is Map<String, Object?>) {
    rotation = int.tryParse('${tags['rotate']}') ?? 0;
  }
  return ((rotation % 360) + 360) % 360;
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
