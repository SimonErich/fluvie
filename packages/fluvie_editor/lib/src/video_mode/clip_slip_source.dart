import 'package:fluvie/fluvie.dart' show KeyframedNumber;
import 'package:fluvie/rendering.dart' show integrateClipSpeedRamp;
import 'package:fluvie_editor/src/video_mode/clip_trim_seconds.dart';

/// The source clock captured at the start of a slip gesture. Translating the
/// source range never moves its timeline window or restarts an authored ramp.
final class ClipSlipSource {
  /// Resolves the same integrated source clock used by picture and audio.
  ClipSlipSource(Map<String, Object?> element, ClipTrimSeconds trim, int frames, int fps)
    : from = trim.from,
      _secondsPerFrame = clipSpeedOf(element).abs() / fps {
    final ramp = KeyframedNumber.maybeFromJson(element['speed']);
    _map = ramp == null ? null : integrateClipSpeedRamp(ramp, fps: fps, windowFrames: frames);
    to = trim.toOpen ? from + offset(frames.toDouble()) : trim.to;
  }

  /// The original source in point, in seconds.
  final double from;

  /// The original source out point, materialized for an open trim.
  late final double to;
  final double _secondsPerFrame;
  late final List<double>? _map;

  /// Earliest pointer travel before the source in point would become negative.
  double get earliest => -from / (_map == null ? _secondsPerFrame : _map[1]);

  /// Source displacement at [frames] of pointer travel. Past either end of a
  /// ramp, its boundary rate continues; inside it, its integrated frame map
  /// provides the same interpolation used by preview and audio.
  double offset(double frames) {
    final map = _map;
    if (map == null) return frames * _secondsPerFrame;
    if (frames <= 0) return frames * map[1];
    final last = map.length - 1;
    if (frames >= last) {
      return map.last + (frames - last) * (map.last - map[last - 1]);
    }
    final index = frames.floor();
    return map[index] + (map[index + 1] - map[index]) * (frames - index);
  }
}
