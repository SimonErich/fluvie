part of 'time.dart';

// Private composite Time variants produced by `+`, `-`, and `*` when units
// mix. They stay symbolic and defer all arithmetic to resolved frame counts,
// so every operand keeps its own unit semantics until resolution. They are
// structurally value-equal so value semantics survive inside Tween, Defaults,
// TimeRange, and future content-hash caching.

/// The sum of two times of different units: resolves each, then adds.
final class _SumTime extends Time {
  const _SumTime(this._a, this._b);

  final Time _a;
  final Time _b;

  @override
  int resolveFrames(TimeScope scope) => _a.resolveFrames(scope) + _b.resolveFrames(scope);

  @override
  bool operator ==(Object other) => other is _SumTime && other._a == _a && other._b == _b;

  @override
  int get hashCode => Object.hash(_SumTime, _a, _b);

  @override
  String toString() => '($_a + $_b)';
}

/// The difference of two times of different units: resolves each, subtracts.
final class _DiffTime extends Time {
  const _DiffTime(this._a, this._b);

  final Time _a;
  final Time _b;

  @override
  int resolveFrames(TimeScope scope) => _a.resolveFrames(scope) - _b.resolveFrames(scope);

  @override
  bool operator ==(Object other) => other is _DiffTime && other._a == _a && other._b == _b;

  @override
  int get hashCode => Object.hash(_DiffTime, _a, _b);

  @override
  String toString() => '($_a - $_b)';
}

/// A time scaled by a numeric factor: scales the resolved frame count and
/// rounds once at the end (`(inner.resolveFrames(scope) * factor).round()`).
final class _ScaledTime extends Time {
  const _ScaledTime(this._inner, this._factor);

  final Time _inner;
  final num _factor;

  @override
  int resolveFrames(TimeScope scope) => (_inner.resolveFrames(scope) * _factor).round();

  @override
  bool operator ==(Object other) =>
      other is _ScaledTime && other._inner == _inner && other._factor == _factor;

  @override
  int get hashCode => Object.hash(_ScaledTime, _inner, _factor);

  @override
  String toString() => '($_inner * $_factor)';
}
