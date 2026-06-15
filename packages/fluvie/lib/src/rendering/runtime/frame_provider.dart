/// @docImport 'package:fluvie/src/rendering/runtime/render_controller_scope.dart';
library;

import 'package:flutter/widgets.dart';
import 'package:fluvie/src/core/errors/fluvie_timing_error.dart';

/// Carries the current frame index down the tree — the runtime counterpart to
/// the timing layer's `TimeScopeProvider`.
///
/// A [RenderControllerScope] mounts one of these per frame; widgets read
/// `FrameProvider.of(context).frame` and rebuild exactly when the frame
/// changes. During capture the frame is the only clock, so a missing provider
/// is a hard error, never a silent zero.
final class FrameProvider extends InheritedWidget {
  /// Provides [frame] to every descendant of [child].
  const FrameProvider({required this.frame, required super.child, super.key});

  /// The frame index visible to this subtree.
  final int frame;

  /// The nearest provider above [context].
  ///
  /// Throws a [FluvieTimingError] when there is none — frame-driven widgets
  /// cannot run outside a [RenderControllerScope] (the frame is the clock).
  static FrameProvider of(BuildContext context) {
    final provider = maybeOf(context);
    if (provider == null) {
      throw FluvieTimingError(
        'No FrameProvider found above this context. Wrap the subtree in a '
        'RenderControllerScope so the current frame can reach it — frame-driven '
        'widgets have no other clock.',
      );
    }
    return provider;
  }

  /// The nearest provider above [context], or `null` when there is none.
  static FrameProvider? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<FrameProvider>();

  @override
  bool updateShouldNotify(FrameProvider oldWidget) => oldWidget.frame != frame;
}
