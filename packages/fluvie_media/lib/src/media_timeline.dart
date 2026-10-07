/// Display timing of decoded source frames, independent of Flutter and IO.
///
/// Constant-rate sources need no timestamp array. Variable-rate sources retain
/// normalized presentation timestamps, never packet decode timestamps.
final class MediaTimeline {
  MediaTimeline._(this.frameCount, this.durationSeconds, this._fps, this._timesUs);

  /// Creates a compact, constant-rate timeline.
  factory MediaTimeline.constant({required double fps, required int frameCount}) {
    if (!fps.isFinite || fps <= 0 || frameCount <= 0) {
      throw ArgumentError('A timeline needs a positive finite fps and frame count.');
    }
    return MediaTimeline._(frameCount, frameCount / fps, fps, null);
  }

  /// Creates a timeline from ordered display timestamps in microseconds.
  ///
  /// The first timestamp becomes zero. Equal timestamps are allowed; the last
  /// picture at that instant wins. [endTimeUs] uses the original timestamp clock
  /// and must follow the final picture. When omitted, the last positive interval
  /// is repeated; a single instant requires an explicit end.
  factory MediaTimeline.fromTimestamps(List<int> presentationTimesUs, {int? endTimeUs}) {
    if (presentationTimesUs.isEmpty) throw ArgumentError('The timeline has no frames.');
    final first = presentationTimesUs.first;
    final times = <int>[];
    var previous = first;
    int? lastInterval;
    for (final time in presentationTimesUs) {
      if (time < previous) throw ArgumentError('Presentation timestamps must be ordered.');
      if (time > previous) lastInterval = time - previous;
      times.add(time - first);
      previous = time;
    }
    final end = endTimeUs ?? (lastInterval == null ? null : previous + lastInterval);
    if (end == null || end <= previous) {
      throw ArgumentError('The timeline end must follow its final presentation timestamp.');
    }
    return MediaTimeline._(times.length, (end - first) / 1000000, null, List.unmodifiable(times));
  }

  /// Restores the versioned timeline carried by native and browser bridges.
  factory MediaTimeline.fromJson(Map<String, Object?> json) {
    if (json['schemaVersion'] != 1) {
      throw const FormatException('Unsupported media timeline schema.');
    }
    try {
      if (json['presentationTimesUs'] case final List<Object?> times) {
        final duration = json['durationUs'];
        if (duration is! int || times.any((time) => time is! int)) {
          throw const FormatException('Expected integer presentation times and duration.');
        }
        return MediaTimeline.fromTimestamps(times.cast<int>(), endTimeUs: duration);
      }
      final fps = json['fps'];
      final count = json['frameCount'];
      if (fps is! num || count is! int) throw const FormatException('Expected fps and frameCount.');
      return MediaTimeline.constant(fps: fps.toDouble(), frameCount: count);
      // Constructor validation is translated at the untrusted serialization seam.
      // ignore: avoid_catching_errors
    } on ArgumentError catch (error) {
      throw FormatException('Invalid media timeline: ${error.message}');
    }
  }

  /// Number of decoded pictures in presentation order.
  final int frameCount;

  /// Complete source duration, including the final picture's interval.
  final double durationSeconds;
  final double? _fps;
  final List<int>? _timesUs;

  /// Whether this timeline uses an explicit source timestamp index.
  bool get isVariable => _timesUs != null;

  /// A compact versioned value, with variable timestamps in microseconds.
  Map<String, Object?> toJson() => {
    'schemaVersion': 1,
    if (_timesUs == null) ...{
      'fps': _fps,
      'frameCount': frameCount,
    } else ...{
      'presentationTimesUs': _timesUs,
      'durationUs': (durationSeconds * 1000000).round(),
    },
  };

  /// Normalized display time of a source frame, in seconds.
  double timeForFrame(int index) {
    RangeError.checkValidIndex(index, this, 'index', frameCount);
    return _timesUs == null ? index / _fps! : _timesUs[index] / 1000000;
  }

  /// Picture visible at [seconds], holding the endpoints outside the source.
  int frameAt(double seconds) {
    if (!seconds.isFinite) throw ArgumentError.value(seconds, 'seconds', 'must be finite');
    if (seconds < 0) return 0;
    if (seconds <= 0) {
      if (_timesUs == null) return 0;
      // A source can have several pictures sharing its first display instant.
      return _upperBound(seconds) - 1;
    }
    if (_timesUs == null) return (seconds * _fps!).floor().clamp(0, frameCount - 1);
    return (_upperBound(seconds) - 1).clamp(0, frameCount - 1);
  }

  /// Neighboring source pictures and their true display-time blend fraction.
  ({int index, int nextIndex, double fraction}) interpolationAt(double seconds) {
    final index = frameAt(seconds);
    if (index == frameCount - 1 || seconds < 0) {
      return (index: index, nextIndex: index, fraction: 0);
    }
    final next = index + 1;
    final start = timeForFrame(index);
    final end = timeForFrame(next);
    return (
      index: index,
      nextIndex: next,
      fraction: ((seconds - start) / (end - start)).clamp(0, 1),
    );
  }

  int _upperBound(double seconds) {
    var low = 0;
    var high = frameCount;
    while (low < high) {
      final middle = low + ((high - low) ~/ 2);
      if (_timesUs![middle] / 1000000 <= seconds) {
        low = middle + 1;
      } else {
        high = middle;
      }
    }
    return low;
  }
}
