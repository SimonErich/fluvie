import 'package:meta/meta.dart';

/// Encoder-neutral mapping from output-frame boundaries to source seconds.
/// Source positions are relative to the beginning of the source trim.
@immutable
final class AudioTimeMap {
  /// Creates a map with the same integrated samples used by the clip painter.
  const AudioTimeMap({required this.fps, required this.sourceSeconds});

  /// Composition frames per second.
  final int fps;

  /// Cumulative source seconds, including the final output-window endpoint.
  final List<double> sourceSeconds;

  /// Output duration represented by the map.
  double get durationSeconds => (sourceSeconds.length - 1) / fps;

  /// Rejects malformed or reversing maps before a backend sees them.
  void validate() {
    if (fps <= 0 || sourceSeconds.length < 2 || sourceSeconds.first != 0) {
      throw ArgumentError(
        'Audio time map needs a positive fps and at least two boundaries starting at zero',
      );
    }
    for (var i = 0; i < sourceSeconds.length; i++) {
      if (!sourceSeconds[i].isFinite || (i > 0 && sourceSeconds[i] <= sourceSeconds[i - 1])) {
        throw ArgumentError('Audio time map must be finite and strictly increasing');
      }
    }
  }

  /// Source offset at an audible output time, using frame-boundary interpolation.
  double sourceSecondsAt(double seconds) {
    final frame = (seconds * fps).clamp(0.0, sourceSeconds.length - 1.0);
    final index = frame.floor();
    if (index == sourceSeconds.length - 1) return sourceSeconds.last;
    return sourceSeconds[index] +
        (sourceSeconds[index + 1] - sourceSeconds[index]) * (frame - index);
  }
}
