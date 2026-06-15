/// @docImport 'package:fluvie/src/timing/resolver/composition_resolver.dart';
library;

import 'package:flutter/widgets.dart';
import 'package:fluvie/src/timing/schedule/element_schedule.dart';

/// Carries one element's resolved [ElementSchedule] down the tree — the
/// boundary between composition-level resolution and the animation
/// runtime.
///
/// Under `Video` the registrar injects schedules by lookup (the lib default);
/// this scope survives as the explicit test/override channel that wins over
/// the registrar in the consult order. When **absent**,
/// [maybeOf] returns `null` and the target consults the registrar, then
/// self-resolves a window-local schedule — the supported fallback for
/// standalone subtrees, so absence is a signal, never an error.
final class ResolvedScheduleScope extends InheritedWidget {
  /// Provides [schedule] to every descendant of [child].
  const ResolvedScheduleScope({required this.schedule, required super.child, super.key});

  /// The resolved schedule visible to this subtree's element.
  final ElementSchedule schedule;

  /// The nearest schedule above [context], or `null` when none is mounted —
  /// the signal to fall back to local resolution.
  static ElementSchedule? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ResolvedScheduleScope>()?.schedule;

  @override
  bool updateShouldNotify(ResolvedScheduleScope oldWidget) => oldWidget.schedule != schedule;
}
