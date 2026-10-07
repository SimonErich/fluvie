part of 'time.dart';

/// A [Time] expressed as a [fraction] of the enclosing window.
///
/// Resolves against the element's own window if it has one, otherwise the
/// enclosing scene: `0.5.relative` on a 4-second element is two seconds; on a
/// bare scene child it is half the scene. The optional [max] caps the
/// resolved value and may be any [Time] variant.
final class RelativeTime extends Time {
  /// Creates a time of [fraction] × the enclosing window, capped at [max].
  const RelativeTime(this.fraction, {this.max});

  /// The fraction of the enclosing window's duration (`1.0` = full window).
  final double fraction;

  /// An optional upper bound applied after scaling; `null` means uncapped.
  final Time? max;

  @override
  int resolveFrames(TimeScope scope) {
    final scaled = (fraction * scope.durationFrames).round();
    final cap = max;
    return cap == null ? scaled : math.min(scaled, cap.resolveFrames(scope));
  }

  @override
  bool operator ==(Object other) =>
      other is RelativeTime && other.fraction == fraction && other.max == max;

  @override
  int get hashCode => Object.hash(RelativeTime, fraction, max);

  @override
  String toString() =>
      max == null ? 'Time.relative($fraction)' : 'Time.relative($fraction, max: $max)';
}
