part of 'ffmpeg_media_tools.dart';

extension _MediaProbing on FfmpegMediaTools {
  Future<MediaSourceInfo> _probeSource(String path, {Future<void>? whenCancelled}) async {
    final report = await probeReport(path, whenCancelled: whenCancelled);
    final streams = report['streams'];
    final video = streams is List<Object?>
        ? streams.whereType<Map<String, Object?>>().firstWhere(
            (stream) => stream['codec_type'] == 'video',
            orElse: () => {},
          )
        : <String, Object?>{};
    int? count;
    if (int.tryParse('${video['nb_frames']}') == null) {
      final result = await run(ffprobePath, [
        '-v',
        'error',
        '-count_frames',
        '-select_streams',
        'v:0',
        '-print_format',
        'json',
        '-show_entries',
        'stream=nb_read_frames',
        ...FfmpegMediaTools._localInputProtocols,
        FfmpegMediaTools._path(path),
      ], whenCancelled: whenCancelled);
      if (result.exitCode == 0) {
        try {
          final decoded = jsonDecode(result.stdout);
          if (decoded is! Map<String, Object?>) {
            throw const FormatException('Expected a frame count object.');
          }
          final countedStreams = decoded['streams'];
          if (countedStreams is List<Object?>) {
            for (final stream in countedStreams.whereType<Map<String, Object?>>()) {
              count = int.tryParse('${stream['nb_read_frames']}') ?? count;
            }
          }
        } on FormatException {
          /* Use the reported duration/rate fallback. */
        }
      }
    }
    return MediaSourceInfo.fromReport(report, countedFrames: count);
  }
}
