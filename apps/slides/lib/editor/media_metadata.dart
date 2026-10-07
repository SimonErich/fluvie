/// Metadata from the source container. Audio uses a millisecond marking clock;
/// video uses its measured frame rate. An absent value is never guessed.
final class MediaMetadata {
  const MediaMetadata({this.duration, this.width, this.height, this.fps, this.channels});

  factory MediaMetadata.fromProbe(Map<String, Object?> json, {required bool audio}) {
    final streams = (json['streams'] as List?)?.whereType<Map<String, Object?>>() ?? const [];
    Map<String, Object?>? stream;
    for (final item in streams) {
      if (item['codec_type'] == (audio ? 'audio' : 'video')) {
        stream = item;
        break;
      }
    }
    if (stream == null) return const MediaMetadata();
    double? number(Object? value) {
      final parsed = double.tryParse('$value');
      return parsed != null && parsed.isFinite && parsed > 0 ? parsed : null;
    }

    double? rate(Object? value) {
      final parts = '$value'.split('/');
      if (parts.length != 2) return number(value);
      final a = number(parts[0]);
      final b = number(parts[1]);
      return a != null && b != null ? a / b : null;
    }

    final format = json['format'];
    final seconds =
        number(stream['duration']) ?? (format is Map ? number(format['duration']) : null);
    return MediaMetadata(
      duration: seconds == null ? null : '${seconds}s',
      width: audio ? null : number(stream['width'])?.round(),
      height: audio ? null : number(stream['height'])?.round(),
      channels: number(
        streams.where((item) => item['codec_type'] == 'audio').firstOrNull?['channels'],
      )?.round(),
      fps: audio ? 1000 : rate(stream['avg_frame_rate']) ?? rate(stream['r_frame_rate']),
    );
  }
  final String? duration;
  final int? width;
  final int? height;
  final double? fps;
  final int? channels;
}
