part of 'time.dart';

/// A [Time] expressed as wall-clock seconds.
final class SecondTime extends Time {
  /// Creates a time of [seconds] wall-clock seconds.
  const SecondTime(this.seconds);

  /// The duration in seconds; resolves to `(seconds * fps).round()`.
  final double seconds;

  @override
  int resolveFrames(TimeScope scope) => (seconds * scope.fps).round();

  @override
  bool operator ==(Object other) => other is SecondTime && other.seconds == seconds;

  @override
  int get hashCode => Object.hash(SecondTime, seconds);

  @override
  String toString() => 'Time.seconds($seconds)';
}
