import 'package:flutter/widgets.dart';
import 'package:fluvie/src/composition/composition_resources.dart';

/// Declares alternatives owned by a reusable frame-dependent Flutter component.
///
/// Ordinary components need no declaration: Fluvie discovers their mounted
/// tree. Use this only for resources that cannot appear during preparation.
final class CompositionResourceScope extends InheritedWidget {
  /// Resolves [resources] against the enclosing Video, Scene or element window.
  const CompositionResourceScope({required this.resources, required super.child, super.key});

  /// Typed alternatives known before the first captured frame.
  final CompositionResources resources;

  /// The nearest component's declarations, when one is mounted.
  static CompositionResources? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<CompositionResourceScope>()?.resources;

  @override
  bool updateShouldNotify(CompositionResourceScope oldWidget) =>
      !identical(resources, oldWidget.resources);
}
