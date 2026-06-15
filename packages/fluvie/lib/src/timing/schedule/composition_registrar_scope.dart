import 'package:flutter/widgets.dart';
import 'package:fluvie/src/timing/schedule/composition_registrar.dart';

/// Carries the nearest [CompositionRegistrar] down the tree — how elements
/// find the composition that owns their schedule.
///
/// `Video` mounts one per scene around the scene's subtree. Absence is a
/// signal, never an error: with no registrar (and no explicit
/// `ResolvedScheduleScope`) an element falls back to local resolution — the
/// documented standalone mode.
final class CompositionRegistrarScope extends InheritedWidget {
  /// Provides [registrar] to every descendant of [child].
  const CompositionRegistrarScope({required this.registrar, required super.child, super.key});

  /// The registrar visible to this subtree's elements.
  final CompositionRegistrar registrar;

  /// The nearest registrar above [context], or `null` when none is mounted —
  /// the signal to fall back to local resolution.
  static CompositionRegistrar? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<CompositionRegistrarScope>()?.registrar;

  @override
  bool updateShouldNotify(CompositionRegistrarScope oldWidget) =>
      !identical(oldWidget.registrar, registrar);
}
