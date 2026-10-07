/// @docImport 'package:fluvie/src/animation/runtime/local_motion_scope.dart';
library;

import 'package:flutter/widgets.dart';
import 'package:fluvie/src/timing/schedule/composition_registrar.dart';
import 'package:fluvie/src/timing/time_scope_data.dart';
import 'package:fluvie/src/timing/time_scope_provider.dart';

/// Carries the nearest [CompositionRegistrar] down the tree — how elements
/// find the composition that owns their schedule.
///
/// `Video` mounts one per scene around the scene's subtree. Absence is a
/// signal, never an error: with no registrar (and no explicit
/// `ResolvedScheduleScope`) an element falls back to local resolution — the
/// documented standalone mode. The [CompositionRegistrarScope.none] variant
/// makes that absence explicit *inside* a composition: it shadows the
/// enclosing registrar so descendants resolve locally ([LocalMotionScope]
/// mounts it).
final class CompositionRegistrarScope extends InheritedWidget {
  /// Provides [registrar] to every descendant of [child].
  const CompositionRegistrarScope({required this.registrar, required super.child, super.key});

  /// Shadows any enclosing registrar: descendants of [child] see none and
  /// resolve their schedules locally.
  const CompositionRegistrarScope.none({required super.child, super.key}) : registrar = null;

  /// The registrar visible to this subtree's elements, or `null` when this
  /// scope deliberately hides the enclosing one.
  final CompositionRegistrar? registrar;

  /// The nearest registrar above [context], or `null` when none is mounted
  /// (or a [CompositionRegistrarScope.none] shadows it) — the signal to fall
  /// back to local resolution.
  static CompositionRegistrar? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<CompositionRegistrarScope>()?.registrar;

  /// The scene (or overlay root) clock enclosing the nearest registrar.
  /// Nested element windows use this origin when registering their schedule.
  static TimeScopeData? ownerTimeScopeOf(BuildContext context) {
    final owner = context.getElementForInheritedWidgetOfExactType<CompositionRegistrarScope>();
    return owner == null ? null : TimeScopeProvider.maybeOf(owner);
  }

  @override
  bool updateShouldNotify(CompositionRegistrarScope oldWidget) =>
      !identical(oldWidget.registrar, registrar);
}
