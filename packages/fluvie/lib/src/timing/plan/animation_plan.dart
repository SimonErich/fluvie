/// @docImport 'package:fluvie/src/core/defaults.dart';
/// @docImport 'package:fluvie/src/timing/plan/element_plan.dart';
library;

import 'package:fluvie/src/core/animation_phase.dart';
import 'package:fluvie/src/core/repeat.dart';
import 'package:fluvie/src/core/stagger.dart';
import 'package:fluvie/src/core/time.dart';
import 'package:fluvie/src/core/timing.dart';
import 'package:fluvie/src/core/trigger.dart';
import 'package:meta/meta.dart';

/// One animation in the plan model: the pure-data description the timing
/// resolver turns into an absolute `[start, end]` frame span.
///
/// The plan model mirrors what `.animate()` declares, stripped of widgets so
/// the resolver stays a pure function. [stagger] and [repeat] ride along as
/// pass-through data the resolver **ignores**: the resolved span is the
/// chaining contract (`previous`/`after` read it), so repeat loops *inside*
/// the span at the runner level and stagger shifts per-child copies at the
/// widget level.
@immutable
final class AnimationPlan {
  /// Creates the plan for one animation; only [phase] is required.
  const AnimationPlan({
    required this.phase,
    this.timing,
    this.delay = Time.zero,
    this.at = Trigger.auto,
    this.stagger,
    this.repeat,
    this.label,
  });

  /// When the animation plays within its element's window (enter/exit/during).
  final AnimationPhase phase;

  /// Explicit timing — a `Tween` or `Spring` — or `null` to fall back to the
  /// merged [Defaults] duration.
  final Timing? timing;

  /// Offset applied after the trigger fires; resolves against the element's
  /// nearest scope. Defaults to [Time.zero].
  final Time delay;

  /// Relative to what the animation starts; defaults to [Trigger.auto] (the
  /// element's own window edge).
  final Trigger at;

  /// Multi-child start-offset distribution. Pass-through data: the widget
  /// layer distributes per-child spans; the resolver keeps the un-staggered
  /// base span.
  final Stagger? stagger;

  /// Looping inside the resolved span. Pass-through data: the runner replays
  /// cycles within the span; the resolver never widens it.
  final Repeat? repeat;

  /// An optional diagnostic label, shown in timeline dumps; carries no
  /// semantic weight.
  final String? label;

  @override
  String toString() =>
      'AnimationPlan($phase, timing: $timing, delay: $delay, at: $at, '
      'stagger: $stagger, repeat: $repeat, label: $label)';
}
