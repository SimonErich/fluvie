import 'dart:math' as math;

import 'package:fluvie/src/core/time_scope.dart';
import 'package:meta/meta.dart';

part 'time_composites.dart';
part 'computed_time.dart';
part 'frame_time.dart';
part 'second_time.dart';
part 'ms_time.dart';
part 'relative_time.dart';

/// Resolves an imported source's clock without rounding its fractional fps.
/// Composition scopes remain integer-fps; source trims use this shared helper
/// so seconds, milliseconds, relative caps and composite times agree for both
/// picture and audio. Computed composition schedules are not source trims.
@internal
int resolveSourceTimeFrames(Time time, {required double fps, required int durationFrames}) {
  int resolve(Time value) =>
      resolveSourceTimeFrames(value, fps: fps, durationFrames: durationFrames);
  return switch (time) {
    FrameTime(:final frames) => frames,
    SecondTime(:final seconds) => (seconds * fps).round(),
    MsTime(:final milliseconds) => (milliseconds / 1000 * fps).round(),
    RelativeTime(:final fraction, :final max) =>
      max == null
          ? (fraction * durationFrames).round()
          : math.min((fraction * durationFrames).round(), resolve(max)),
    _SumTime(:final _a, :final _b) => resolve(_a) + resolve(_b),
    _DiffTime(:final _a, :final _b) => resolve(_a) - resolve(_b),
    _ScaledTime(:final _inner, :final _factor) => (resolve(_inner) * _factor).round(),
    ComputedTime() => throw ArgumentError(
      'A computed composition schedule cannot be used as a source trim',
    ),
  };
}

/// Exact source-frame coordinate for source trims and fractional cut phases.
@internal
double resolveSourceTimeOffset(Time time, {required double fps, required int durationFrames}) {
  double resolve(Time value) =>
      resolveSourceTimeOffset(value, fps: fps, durationFrames: durationFrames);
  return switch (time) {
    FrameTime(:final frames) => frames.toDouble(),
    SecondTime(:final seconds) => seconds * fps,
    MsTime(:final milliseconds) => milliseconds / 1000 * fps,
    RelativeTime(:final fraction, :final max) =>
      max == null ? fraction * durationFrames : math.min(fraction * durationFrames, resolve(max)),
    _SumTime(:final _a, :final _b) => resolve(_a) + resolve(_b),
    _DiffTime(:final _a, :final _b) => resolve(_a) - resolve(_b),
    _ScaledTime(:final _inner, :final _factor) => resolve(_inner) * _factor,
    ComputedTime() => throw ArgumentError(
      'A computed composition schedule cannot be used as a source trim',
    ),
  };
}

/// Resolves a source trim on its actual display clock without frame rounding.
/// [frameTime] maps authored frame ordinals when presentation timestamps exist.
@internal
double resolveSourceTimeSeconds(
  Time time, {
  required double fps,
  required int durationFrames,
  double? durationSeconds,
  double Function(int frame)? frameTime,
}) {
  double resolve(Time value) => resolveSourceTimeSeconds(
    value,
    fps: fps,
    durationFrames: durationFrames,
    durationSeconds: durationSeconds,
    frameTime: frameTime,
  );
  return switch (time) {
    FrameTime(:final frames) => frameTime?.call(frames) ?? frames / fps,
    SecondTime(:final seconds) => seconds,
    MsTime(:final milliseconds) => milliseconds / 1000,
    RelativeTime(:final fraction, :final max) =>
      max == null
          ? fraction * (durationSeconds ?? durationFrames / fps)
          : math.min(fraction * (durationSeconds ?? durationFrames / fps), resolve(max)),
    _SumTime(:final _a, :final _b) => resolve(_a) + resolve(_b),
    _DiffTime(:final _a, :final _b) => resolve(_a) - resolve(_b),
    _ScaledTime(:final _inner, :final _factor) => resolve(_inner) * _factor,
    ComputedTime() => throw ArgumentError(
      'A computed composition schedule cannot be used as a source trim',
    ),
  };
}

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
