import 'dart:ui' show lerpDouble;

import 'package:flutter/animation.dart' show Curve;
import 'package:flutter/widgets.dart' show BuildContext, StatelessWidget, Text, TextStyle, Widget;
import 'package:fluvie/src/core/anchor.dart';
import 'package:fluvie/src/core/ease.dart';
import 'package:fluvie/src/core/time.dart';
import 'package:fluvie/src/elements/reveal/reveal_progress.dart';
import 'package:fluvie/src/elements/runtime/element_shared.dart';
import 'package:fluvie/src/rendering/runtime/frame_provider.dart';
import 'package:fluvie/src/timing/time_scope_data.dart';
import 'package:fluvie/src/timing/time_scope_provider.dart';
import 'package:intl/intl.dart' show NumberFormat;

/// The locale every built-in [Counter] format pins, so the grouping and symbol
/// placement are byte-identical across machines (no ambient locale, no
/// `DateTime`).
const String _fixedLocale = 'en_US';

/// Counts a number from [from] to [to] across its window — an intrinsic,
/// frame-driven element formatted by an `intl` `NumberFormat`.
///
/// The displayed value is `lerp(from, to, ease(progress))`, where `progress` is
/// the frames elapsed since the enclosing time scope began over the resolved
/// [duration], clamped to `[0, 1]` ([FrameProvider] is the only clock). [ease]
/// shapes the count (the default [Ease.linear] is the mechanical motion a
/// counter wants); the result is formatted by [format] when given, or a
/// thousands-grouped decimal at a fixed locale.
///
/// ```dart
/// Counter(to: 12500, duration: 2.seconds, format: NumberFormat.compact()) // "12.5K"
/// Counter.currency(to: 4999, symbol: r'$')   Counter.percent(to: 0.87)
/// ```
///
/// Transforms and effects come through `.animate()` only — the constructor
/// takes content parameters and nothing else. [shared] wraps the result in a
/// `SharedElement` for a hero morph across a scene boundary.
final class Counter extends StatelessWidget {
  /// Counts from [from] (default `0`) to [to] over [duration], formatted by
  /// [format] (default: a fixed-locale grouped decimal), in [style].
  const Counter({
    required this.to,
    this.from = 0,
    this.duration = const Time.seconds(1),
    this.ease = Ease.linear,
    this.format,
    this.style,
    this.shared,
    super.key,
  });

  /// Counts up to a currency amount, prefixing [symbol] (default `$`) at a
  /// fixed locale with no fractional digits.
  Counter.currency({
    required this.to,
    String symbol = r'$',
    this.from = 0,
    this.duration = const Time.seconds(1),
    this.ease = Ease.linear,
    this.style,
    this.shared,
    super.key,
  }) : format = NumberFormat.currency(locale: _fixedLocale, symbol: symbol, decimalDigits: 0);

  /// Counts up to a percentage: [to] is a fraction (`0.87` shows as `87%`),
  /// formatted at a fixed locale.
  Counter.percent({
    required this.to,
    this.from = 0,
    this.duration = const Time.seconds(1),
    this.ease = Ease.linear,
    this.style,
    this.shared,
    super.key,
  }) : format = NumberFormat.percentPattern(_fixedLocale);

  /// The value to count up (or down) to.
  final num to;

  /// The value the count starts from; defaults to `0`.
  final num from;

  /// How long the count takes; resolved against the enclosing scope so a
  /// relative or seconds duration scales with fps.
  final Time duration;

  /// The curve shaping the count's progress; the default [Ease.linear] is the
  /// mechanical motion a counter wants (any acceleration reads as a glitch).
  final Curve ease;

  /// The number format, or `null` for a fixed-locale thousands-grouped decimal.
  final NumberFormat? format;

  /// The text style, or `null` to inherit the ambient `DefaultTextStyle`.
  final TextStyle? style;

  /// An optional hero anchor: when non-null the counter morphs across the
  /// boundary it shares with the same anchor in the adjacent scene. `null`
  /// mounts no `SharedElement`.
  final Anchor? shared;

  @override
  Widget build(BuildContext context) {
    final frame = FrameProvider.of(context).frame;
    final scope = TimeScopeProvider.of(context);
    final visible = Text(_formatted(frame, scope), style: style);
    return wrapShared(shared, visible);
  }

  /// The formatted value at [frame] within [scope].
  String _formatted(int frame, TimeScopeData scope) {
    final progress = revealProgress(frame, scope, duration);
    final value = lerpDouble(from, to, ease.transform(progress))!;
    final formatter = format ?? NumberFormat.decimalPattern(_fixedLocale);
    return formatter.format(value);
  }
}
