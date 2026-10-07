import 'package:fluvie/fluvie.dart'
    show AudioVolumePoint, audioVolumeAt, decodeAudioAutomation, decodeTime;
import 'package:fluvie/rendering.dart' show TimeScopeData;

/// Splits authored clip audio at an output-frame offset, keeping source-clock
/// volume and fades continuous across the cut. Apply each returned map as a
/// patch: null fade fields remove the old fade because its gain is now baked
/// into the ordinary volume envelope. Unedited audio yields empty patches.
({Map<String, Object?> head, Map<String, Object?> tail}) splitClipAudio({
  required Map<String, Object?> element,
  required int cutFrame,
  required int windowFrames,
  required int fps,
}) {
  if (fps <= 0 || cutFrame <= 0 || cutFrame >= windowFrames) {
    throw ArgumentError('A clip audio cut must lie inside a positive frame window');
  }
  final raw = element['automation'];
  final points = raw == null
      ? const <AudioVolumePoint>[]
      : decodeAudioAutomation(raw).resolve(fps: fps, windowFrames: windowFrames);
  final scope = TimeScopeData(fps: fps, startFrame: 0, durationFrames: windowFrames);
  int fade(String key) => element[key] == null ? 0 : decodeTime(element[key]).resolveFrames(scope);
  final fadeIn = fade('fadeIn');
  final fadeOut = fade('fadeOut');
  final hasFade = fadeIn > 0 || fadeOut > 0;
  if (points.isEmpty && !hasFade) return (head: const {}, tail: const {});

  Map<String, Object?> slice(int from, int to) {
    final frames = <int>{from, to};
    if (hasFade) {
      frames.addAll([for (var frame = from + 1; frame < to; frame++) frame]);
    } else {
      for (final point in points) {
        final frame = (point.seconds * fps).round();
        if (frame > from && frame < to) frames.add(frame);
      }
    }
    final ordered = frames.toList()..sort();
    double gain(int frame) {
      var value = audioVolumeAt(points, frame / fps);
      if (fadeIn > 0) value *= (frame / fadeIn).clamp(0.0, 1.0);
      if (fadeOut > 0) {
        final start = (windowFrames - fadeOut).clamp(0, windowFrames);
        value *= (1 - (frame - start) / fadeOut).clamp(0.0, 1.0);
      }
      return value;
    }

    return {
      'automation': {
        'volume': {
          'values': [for (final frame in ordered) gain(frame)],
          'positions': [for (final frame in ordered) '${frame - from}f'],
        },
      },
      if (element.containsKey('fadeIn')) 'fadeIn': null,
      if (element.containsKey('fadeOut')) 'fadeOut': null,
    };
  }

  return (head: slice(0, cutFrame), tail: slice(cutFrame, windowFrames));
}
