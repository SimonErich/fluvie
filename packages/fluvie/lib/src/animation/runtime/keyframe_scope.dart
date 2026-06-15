import 'package:flutter/widgets.dart';
import 'package:fluvie/src/core/keyframe.dart';

/// Publishes the per-frame composed [Keyframe] to an element's subtree —
/// the data channel for keyframe state the generic applier cannot paint.
///
/// The animation pipeline mounts one around every animated element. The
/// applier handles transforms, blur, and opacity itself; [Keyframe.color]
/// travels here as pure data and is painted by the color-capable elements
/// that read [maybeOf] — `Background.color`, text, and shapes.
final class KeyframeScope extends InheritedWidget {
  /// Provides [keyframe] to every descendant of [child].
  const KeyframeScope({required this.keyframe, required super.child, super.key});

  /// The composed keyframe of the enclosing element at the current frame.
  final Keyframe keyframe;

  /// The nearest composed keyframe above [context], or `null` outside any
  /// animated element — color-capable elements then keep their own color.
  static Keyframe? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<KeyframeScope>()?.keyframe;

  @override
  bool updateShouldNotify(KeyframeScope oldWidget) => oldWidget.keyframe != keyframe;
}
