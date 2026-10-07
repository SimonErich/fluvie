part of 'output_verification.dart';

Map<String, Object?> _mediaFacts(Map<String, Object?> report) {
  final reported = report['streams'];
  final streams = reported is List<Object?>
      ? reported.whereType<Map<String, Object?>>().toList()
      : const <Map<String, Object?>>[];
  final video = streams.firstWhere((stream) => stream['codec_type'] == 'video', orElse: () => {});
  final width = int.tryParse('${video['width']}') ?? 0;
  final height = int.tryParse('${video['height']}') ?? 0;
  final format = report['format'] is Map<String, Object?>
      ? report['format']! as Map<String, Object?>
      : const <String, Object?>{};
  final tags = video['tags'] is Map<String, Object?>
      ? video['tags']! as Map<String, Object?>
      : const <String, Object?>{};
  final pixelFormat = video['pix_fmt']?.toString() ?? '';
  final duration = double.tryParse('${video['duration'] ?? format['duration']}');
  final frameCount = int.tryParse('${video['nb_frames']}');
  final audio = <Map<String, Object?>>[
    for (final stream in streams.where((stream) => stream['codec_type'] == 'audio'))
      {
        'codec': ?stream['codec_name'],
        'channels': ?stream['channels'],
        'channelLayout': ?stream['channel_layout'],
        'sampleRate': ?stream['sample_rate'],
      },
  ];
  return {
    'container': ?format['format_name'],
    'codec': ?video['codec_name'],
    if (width > 0 && height > 0) 'width': width,
    if (width > 0 && height > 0) 'height': height,
    'pixelFormat': pixelFormat,
    'hasAlpha':
        pixelFormat.startsWith('yuva') ||
        pixelFormat.startsWith('gbrap') ||
        const ['rgba', 'bgra', 'argb', 'abgr', 'ya8', 'ya16'].any(pixelFormat.startsWith) ||
        tags.entries.any(
          (entry) => entry.key.toLowerCase() == 'alpha_mode' && '${entry.value}' == '1',
        ),
    'hasAudio': audio.isNotEmpty,
    if (duration != null && duration.isFinite && duration >= 0) 'durationSeconds': duration,
    if (frameCount != null && frameCount >= 0) 'declaredFrameCount': frameCount,
    if (frameCount != null && frameCount >= 0) 'frameCount': frameCount,
    'averageFrameRate': ?video['avg_frame_rate'],
    'nominalFrameRate': ?video['r_frame_rate'],
    'fps': ?(_rate(video['avg_frame_rate']) ?? _rate(video['r_frame_rate'])),
    'audio': audio,
  };
}

double? _rate(Object? value) {
  final parts = '$value'.split('/');
  final numerator = double.tryParse(parts.first);
  final denominator = parts.length == 2 ? double.tryParse(parts.last) : 1.0;
  if (numerator == null || denominator == null || denominator == 0) return null;
  final rate = numerator / denominator;
  return rate.isFinite && rate > 0 ? rate : null;
}
