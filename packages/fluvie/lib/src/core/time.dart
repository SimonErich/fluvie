import 'dart:math' as math;

import 'package:fluvie/src/core/time_scope.dart';
import 'package:meta/meta.dart';

part 'time_composites.dart';

/// The single currency for every duration, delay, offset, and trim.
///
/// A [Time] is a unit-tagged value — frames, seconds, milliseconds, or a
/// fraction of the enclosing window — that stays symbolic until Fluvie
/// resolves it against a [TimeScope]:
///
/// ```dart
/// 20.frames        // exact frame count (fps-independent)
/// 2.5.seconds      // real time
/// 500.ms           // milliseconds
/// 0.3.relative     // fraction of the nearest enclosing window
/// ```
///
/// Times combine with `+`, `-`, and `*`, so call sites never do frame math.
@immutable
sealed class Time {
  /// Const base constructor shared by all variants.
  const Time();

  /// An exact, fps-independent count of [frames]; see [FrameTime].
  const factory Time.frames(int frames) = FrameTime;

  /// Wall-clock [seconds]; see [SecondTime].
  const factory Time.seconds(double seconds) = SecondTime;

  /// Wall-clock [milliseconds]; see [MsTime].
  const factory Time.ms(int milliseconds) = MsTime;

  /// A [fraction] of the enclosing window, optionally capped at [max];
  /// see [RelativeTime].
  const factory Time.relative(double fraction, {Time? max}) = RelativeTime;

  /// The zero time: resolves to frame `0` in every scope.
  static const Time zero = FrameTime(0);

  /// Resolves this time to a whole number of frames within [scope].
  ///
  /// Fluvie calls this for you during timing resolution; call sites keep
  /// passing symbolic [Time] values around instead of frame numbers.
  int resolveFrames(TimeScope scope);

  /// The sum of this time and [other].
  ///
  /// Same-variant operands combine in their own unit (`10.frames + 5.frames`
  /// is `Time.frames(15)`); mixed variants resolve each operand against the
  /// scope first and add the resolved frame counts. Capped relatives never
  /// merge fractions — each cap applies before the addition.
  Time operator +(Time other) => switch ((this, other)) {
    (final FrameTime a, final FrameTime b) => FrameTime(a.frames + b.frames),
    (final SecondTime a, final SecondTime b) => SecondTime(a.seconds + b.seconds),
    (final MsTime a, final MsTime b) => MsTime(a.milliseconds + b.milliseconds),
    (final RelativeTime a, final RelativeTime b) when a.max == null && b.max == null =>
      RelativeTime(a.fraction + b.fraction),
    _ => _SumTime(this, other),
  };

  /// The difference between this time and [other].
  ///
  /// Combination rules mirror `+`: same-variant operands subtract in their
  /// own unit; mixed variants subtract the resolved frame counts.
  Time operator -(Time other) => switch ((this, other)) {
    (final FrameTime a, final FrameTime b) => FrameTime(a.frames - b.frames),
    (final SecondTime a, final SecondTime b) => SecondTime(a.seconds - b.seconds),
    (final MsTime a, final MsTime b) => MsTime(a.milliseconds - b.milliseconds),
    (final RelativeTime a, final RelativeTime b) when a.max == null && b.max == null =>
      RelativeTime(a.fraction - b.fraction),
    _ => _DiffTime(this, other),
  };

  /// This time scaled by [factor].
  ///
  /// An exact frame count scales directly (`20.frames * 1.5` is
  /// `Time.frames(30)`). Every other variant scales its *resolved* frame
  /// count — `(resolveFrames(scope) * factor).round()` — so rounding happens
  /// once, at the end.
  Time operator *(num factor) => switch (this) {
    final FrameTime t => FrameTime((t.frames * factor).round()),
    _ => _ScaledTime(this, factor),
  };
}

/// A [Time] computed from the resolving scope — the internal variant behind
/// schedule-derived durations (a `Timeline` resolves at the enclosing
/// `Video`'s fps, so its times cannot be eager).
///
/// Deliberately not on the public barrel, and the spec codecs reject it: a
/// schedule-derived time has no serial form.
@internal
final class ComputedTime extends Time {
  /// Creates a time that resolves to `compute(scope)` frames.
  const ComputedTime(this.compute);

  /// Computes the resolved frame count for [scope].
  final int Function(TimeScope scope) compute;

  @override
  int resolveFrames(TimeScope scope) => compute(scope);

  @override
  String toString() => 'Time.computed(<schedule>)';
}

/// A [Time] expressed as an exact number of frames, independent of fps.
final class FrameTime extends Time {
  /// Creates a time of exactly [frames] frames.
  const FrameTime(this.frames);

  /// The frame count this time resolves to in any scope.
  final int frames;

  @override
  int resolveFrames(TimeScope scope) => frames;

  @override
  bool operator ==(Object other) => other is FrameTime && other.frames == frames;

  @override
  int get hashCode => Object.hash(FrameTime, frames);

  @override
  String toString() => 'Time.frames($frames)';
}

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
