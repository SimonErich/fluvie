part of 'video_razor.dart';

/// What splitting a clip's trim produced: the two halves, or the reason it
/// could not be done honestly.
sealed class _TrimOutcome {
  const _TrimOutcome();
}

final class _TrimSplit extends _TrimOutcome {
  const _TrimSplit(this.headTrim, this.tailTrim, {this.headSpeed, this.tailSpeed});
  final Map<String, Object?>? headSpeed;
  final Map<String, Object?>? tailSpeed;
  final Map<String, Object?> headTrim;
  final Map<String, Object?> tailTrim;
}

final class _TrimRefusal extends _TrimOutcome {
  const _TrimRefusal(this.note);
  final String note;
}

/// Splits the clip's trim, [elapsed] composition seconds into its window and
/// [remaining] seconds from the cut to the window's end.
///
/// A clip with no trim end gains one that covers exactly its own window. The
/// source may well be shorter — the resolver clamps a trim to the footage it
/// finds, and the original was already holding its last frame there.
_TrimOutcome _splitTrim(
  Map<String, Object?> element, {
  required int fps,
  required double elapsed,
  required double remaining,
}) {
  final trim = readClipTrimSeconds(element);
  if (trim == null) return const _TrimRefusal(clipTrimUnitNote);
  final ramp = KeyframedNumber.maybeFromJson(element['speed']);
  if (ramp != null) {
    final frames = ((elapsed + remaining) * fps).round();
    final cutFrame = (elapsed * fps).round();
    final scope = OwnerFrameScope(fps, FrameSpan(0, frames));
    final times = [for (final position in ramp.positions) position.resolveFrames(scope)];
    final map = integrateClipSpeedRamp(ramp, fps: fps, windowFrames: frames);
    final cut = trim.toOpen
        ? trim.from + map[cutFrame]
        : _clamp(trim.from + map[cutFrame], trim.from, trim.to);
    final end = trim.toOpen ? trim.from + map.last : trim.to;
    // Preserve out-of-window stops: negative tail positions retain the exact
    // original eased segment, including bounce/elastic, without resampling it.
    Map<String, Object?> speed(int offset) => KeyframedNumber(
      values: ramp.values,
      positions: [for (final time in times) Time.frames(time - offset)],
      easings: ramp.easings,
    ).toJson();
    return _TrimSplit(
      trimSecondsJson(trim.from, cut),
      trimSecondsJson(cut, end),
      headSpeed: speed(0),
      tailSpeed: speed(cutFrame),
    );
  }
  final speed = clipSpeedOf(element);
  final advanced = elapsed * speed.abs();
  if (speed < 0) {
    // Reversed, the window opens on the trim's last frame and walks down, so
    // the head takes the tail of the source and the other way about.
    if (trim.toOpen) {
      return const _TrimRefusal(
        'A reversed clip needs a trim end before it can be razored: without '
        'one there is no far end to cut back from.',
      );
    }
    final cut = _clamp(trim.to - advanced, trim.from, trim.to);
    return _TrimSplit(trimSecondsJson(cut, trim.to), trimSecondsJson(trim.from, cut));
  }
  final cut = trim.toOpen ? trim.from + advanced : _clamp(trim.from + advanced, trim.from, trim.to);
  final end = trim.toOpen ? cut + remaining * speed.abs() : trim.to;
  return _TrimSplit(trimSecondsJson(trim.from, cut), trimSecondsJson(cut, end));
}

double _clamp(double value, double min, double max) => value < min
    ? min
    : value > max
    ? max
    : value;
