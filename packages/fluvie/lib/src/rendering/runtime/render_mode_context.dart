import 'package:flutter/widgets.dart';
import 'package:fluvie/src/rendering/runtime/render_mode.dart';

/// Tells the subtree whether it is being captured or previewed.
///
/// The render pipeline mounts one of these with [RenderMode.capture] around
/// the composition before the frame loop starts; live apps need no wrapper at
/// all — [modeOf] defaults to [RenderMode.preview] when no context is above.
/// Determinism-sensitive widgets branch on [isCapture] to swap wall-clock
/// behavior for frame-driven behavior.
final class RenderModeContext extends InheritedWidget {
  /// Provides [mode] to every descendant of [child].
  const RenderModeContext({required this.mode, required super.child, super.key});

  /// The mode visible to this subtree.
  final RenderMode mode;

  /// The nearest mode above [context], or [RenderMode.preview] when there is
  /// none — a plain running app is always a preview.
  static RenderMode modeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<RenderModeContext>()?.mode ?? RenderMode.preview;

  /// Whether the subtree around [context] is being captured for encoding.
  static bool isCapture(BuildContext context) => modeOf(context) == RenderMode.capture;

  @override
  bool updateShouldNotify(RenderModeContext oldWidget) => oldWidget.mode != mode;
}
