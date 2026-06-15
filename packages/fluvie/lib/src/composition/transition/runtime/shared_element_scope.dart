/// @docImport 'package:fluvie/src/animation/motion_target.dart';
/// @docImport 'package:fluvie/src/composition/transition/shared_element.dart';
library;

import 'package:flutter/widgets.dart';
import 'package:fluvie/src/composition/transition/runtime/shared_element_registry.dart';

/// Provides the per-scene [SharedElementRegistry] and the scene's index to a
/// scene shell's subtree.
///
/// `Video` mounts one of these inside each scene's registrar scope (it knows
/// the scene index there), so every [SharedElement] below registers itself in
/// the right scene against the one registry the whole composition shares for
/// this collect generation. A `SharedElement` outside any scope takes the
/// documented standalone passthrough (the `MotionTarget` precedent).
final class SharedElementScope extends InheritedWidget {
  /// Provides [registry] and [sceneIndex] to every descendant of [child].
  const SharedElementScope({
    required this.registry,
    required this.sceneIndex,
    required super.child,
    super.key,
  });

  /// The composition's shared-element registry for this collect generation.
  final SharedElementRegistry registry;

  /// The index of the scene this scope wraps.
  final int sceneIndex;

  /// The nearest scope above [context], or `null` when a [SharedElement] sits
  /// outside any scene (the standalone passthrough case).
  static SharedElementScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<SharedElementScope>();

  @override
  bool updateShouldNotify(SharedElementScope oldWidget) =>
      !identical(oldWidget.registry, registry) || oldWidget.sceneIndex != sceneIndex;
}
