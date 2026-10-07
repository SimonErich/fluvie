part of 'ffmpeg_media_tools.dart';

/// Exact display-time probing for native media tools.
extension FfmpegTimelineTools on FfmpegMediaTools {
  /// Indexes decoded display timestamps, including the final frame interval.
  ///
  /// This requires one source decode. Reuse the timeline for subsequent seeks;
  /// neither average frame rate nor packet decode timestamps replace this index.
  Future<MediaTimeline> probeTimeline(String path, {Future<void>? whenCancelled}) async =>
      (await _probeFrameIndex(path, whenCancelled: whenCancelled)).timeline;

  Future<_SourceFrameIndex> _probeFrameIndex(String path, {Future<void>? whenCancelled}) async {
    final result = await run(ffprobePath, [
      '-v', 'error', '-select_streams', 'v:0', '-show_frames', '-show_streams', '-show_format',
      '-show_entries',
      // ignore: no_adjacent_strings_in_list, one bounded ffprobe field selector.
      'frame=best_effort_timestamp_time,pts_time,duration_time,pkt_duration_time,key_frame:'
          'stream=duration,start_time,avg_frame_rate:format=start_time',
      '-of', 'json', ...FfmpegMediaTools._localInputProtocols, FfmpegMediaTools._path(path),
    ], whenCancelled: whenCancelled);
    if (result.exitCode != 0) throw FfmpegMediaTools._failure('Indexing "$path"', result);
    try {
      final report = jsonDecode(result.stdout);
      if (report is! Map<String, Object?> || report['frames'] is! List<Object?>) {
        throw const FormatException('No decoded display frames.');
      }
      final records = report['frames']! as List<Object?>;
      if (records.any((frame) => frame is! Map<String, Object?>)) {
        throw const FormatException('A decoded display frame is not an object.');
      }
      final frames = records.cast<Map<String, Object?>>();
      final times = <int>[];
      final keys = <int>[];
      for (final frame in frames) {
        final time = _secondsUs(frame['best_effort_timestamp_time'] ?? frame['pts_time']);
        if (time == null) throw const FormatException('A frame has no display timestamp.');
        if (times.isNotEmpty && time < times.last) {
          throw const FormatException('Decoded display timestamps are out of order.');
        }
        if (frame['key_frame'] == 1) keys.add(times.length);
        times.add(time);
      }
      if (times.isEmpty) throw const FormatException('No decoded display frames.');
      final lastDuration = _secondsUs(
        frames.last['duration_time'] ?? frames.last['pkt_duration_time'],
      );
      var end = lastDuration != null && lastDuration > 0 ? times.last + lastDuration : null;
      final streams = report['streams'];
      if (end == null && streams is List<Object?>) {
        for (final stream in streams.whereType<Map<String, Object?>>()) {
          final duration = _secondsUs(stream['duration']);
          final origin = _secondsUs(stream['start_time']) ?? times.first;
          if (duration != null && origin + duration > times.last) end = origin + duration;
        }
      }
      if (end == null && times.every((time) => time == times.first)) {
        throw const FormatException('The source has no positive display interval.');
      }
      return _SourceFrameIndex(
        MediaTimeline.fromTimestamps(times, endTimeUs: end),
        times,
        keys,
        report['format'] is Map<String, Object?>
            ? _secondsUs((report['format']! as Map<String, Object?>)['start_time']) ?? times.first
            : times.first,
      );
    } on FormatException catch (error) {
      throw MediaProcessException('Cannot index display timing of "$path": ${error.message}');
    }
  }
}

final class _SourceFrameIndex {
  const _SourceFrameIndex(this.timeline, this.timesUs, this.keyFrames, this.seekOriginUs);
  final MediaTimeline timeline;
  final List<int> timesUs;
  final List<int> keyFrames;
  final int seekOriginUs;
}

int? _secondsUs(Object? value) {
  final seconds = double.tryParse('$value');
  return seconds != null && seconds.isFinite ? (seconds * 1000000).round() : null;
}
