part of 'time.dart';

/// A [Time] expressed as wall-clock milliseconds.
final class MsTime extends Time {
  /// Creates a time of [milliseconds] wall-clock milliseconds.
  const MsTime(this.milliseconds);

  /// The duration in ms; resolves to `(milliseconds / 1000 * fps).round()`.
  final int milliseconds;

  @override
  int resolveFrames(TimeScope scope) => (milliseconds / 1000 * scope.fps).round();

  @override
  bool operator ==(Object other) => other is MsTime && other.milliseconds == milliseconds;

  @override
  int get hashCode => Object.hash(MsTime, milliseconds);

  @override
  String toString() => 'Time.ms($milliseconds)';
}
