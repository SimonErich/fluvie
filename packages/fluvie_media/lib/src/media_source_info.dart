/// Factual video metadata, independent of Flutter and semantic asset analysis.
final class MediaSourceInfo {
  /// Creates metadata, with dimensions after the display rotation is applied.
  const MediaSourceInfo({
    required this.codec,
    required this.width,
    required this.height,
    required this.fps,
    required this.frameCount,
    required this.durationSeconds,
    required this.hasAudio,
    required this.hasAlpha,
    this.rotationDegrees = 0,
    this.frameCountIsEstimated = false,
  });

  /// Parses ffprobe stream/container facts. Optional counted frames are exact.
  factory MediaSourceInfo.fromReport(Map<String, Object?> report, {int? countedFrames}) {
    final reportedStreams = report['streams'];
    final streams = reportedStreams is List<Object?>
        ? reportedStreams.whereType<Map<String, Object?>>().toList()
        : const <Map<String, Object?>>[];
    final video = streams.firstWhere((stream) => stream['codec_type'] == 'video', orElse: () => {});
    if (video.isEmpty) throw const FormatException('The source has no video stream.');
    final format = report['format'];
    final seconds =
        _number(video['duration']) ??
        (format is Map<String, Object?> ? _number(format['duration']) : null);
    final fps = _rate(video['avg_frame_rate']) ?? _rate(video['r_frame_rate']);
    final estimatedFrames = seconds != null && fps != null ? seconds * fps : null;
    final declaredFrames = _number(video['nb_frames'])?.toInt();
    final count =
        countedFrames ??
        declaredFrames ??
        (estimatedFrames != null && estimatedFrames.isFinite ? estimatedFrames.round() : null);
    final duration = seconds ?? (count != null && fps != null ? count / fps : null);
    final width = _number(video['width'])?.toInt();
    final height = _number(video['height'])?.toInt();
    if (fps == null ||
        count == null ||
        duration == null ||
        width == null ||
        height == null ||
        fps <= 0 ||
        count <= 0 ||
        duration <= 0 ||
        width <= 0 ||
        height <= 0) {
      throw const FormatException('The source has no usable dimensions, duration or frame rate.');
    }
    var rotation = 0;
    final sideData = video['side_data_list'];
    if (sideData is List<Object?>) {
      for (final item in sideData.whereType<Map<String, Object?>>()) {
        rotation = _number(item['rotation'])?.round() ?? rotation;
      }
    }
    final tags = video['tags'];
    if (rotation == 0 && tags is Map<String, Object?>) {
      rotation = _number(tags['rotate'])?.round() ?? 0;
    }
    rotation = ((rotation % 360) + 360) % 360;
    final alphaTag =
        tags is Map<String, Object?> &&
        tags.entries.any(
          (entry) => entry.key.toLowerCase() == 'alpha_mode' && entry.value.toString() == '1',
        );
    final pixels = video['pix_fmt']?.toString() ?? '';
    return MediaSourceInfo(
      codec: video['codec_name']?.toString() ?? 'unknown',
      width: rotation == 90 || rotation == 270 ? height : width,
      height: rotation == 90 || rotation == 270 ? width : height,
      fps: fps,
      frameCount: count,
      durationSeconds: duration,
      hasAudio: streams.any((stream) => stream['codec_type'] == 'audio'),
      hasAlpha:
          alphaTag ||
          pixels.startsWith('yuva') ||
          pixels.startsWith('gbrap') ||
          const ['rgba', 'bgra', 'argb', 'abgr', 'ya8', 'ya16'].any(pixels.startsWith),
      rotationDegrees: rotation,
      frameCountIsEstimated: countedFrames == null && declaredFrames == null,
    );
  }

  /// Codec name.
  final String codec;

  /// Display width.
  final int width;

  /// Display height.
  final int height;

  /// Average source frame rate.
  final double fps;

  /// Source frame count, with [frameCountIsEstimated] identifying a rate fallback.
  final int frameCount;

  /// True when duration × average rate supplied the count instead of probing it.
  final bool frameCountIsEstimated;

  /// Video duration in seconds.
  final double durationSeconds;

  /// Whether an audio stream is present.
  final bool hasAudio;

  /// Whether alpha is coded in pixels or an auxiliary layer.
  final bool hasAlpha;

  /// Normalized display rotation.
  final int rotationDegrees;

  /// Facts for local preview, asset inventory and diagnostics.
  Map<String, Object> toJson() => {
    'codec': codec,
    'width': width,
    'height': height,
    'fps': fps,
    'frameCount': frameCount,
    'frameCountIsEstimated': frameCountIsEstimated,
    'durationSeconds': durationSeconds,
    'hasAudio': hasAudio,
    'hasAlpha': hasAlpha,
    'rotationDegrees': rotationDegrees,
  };

  static double? _number(Object? value) {
    final number = value is num ? value.toDouble() : double.tryParse('$value');
    return number != null && number.isFinite ? number : null;
  }

  static double? _rate(Object? value) {
    final parts = '$value'.split('/');
    final numerator = _number(parts.first);
    if (numerator == null || numerator <= 0) return null;
    if (parts.length == 1) return numerator;
    if (parts.length != 2) return null;
    final denominator = _number(parts.last);
    if (denominator == null || denominator <= 0) return null;
    final rate = numerator / denominator;
    return rate.isFinite ? rate : null;
  }
}
