import 'package:flutter/widgets.dart';
import 'package:fluvie/src/rendering/runtime/frame_provider.dart';
import 'package:fluvie/src/rendering/runtime/render_controller.dart';

/// Binds a [RenderController] to the tree by republishing its frame as a
/// [FrameProvider].
///
/// The render loop seeks the controller, pumps once, and every descendant
/// that read `FrameProvider.of(context).frame` rebuilds with the new index —
/// nothing else does. [child] sits in the listenable builder's child slot, so
/// a frame change rebuilds only the provider; descendants rebuild solely
/// through their inherited-widget dependency.
final class RenderControllerScope extends StatelessWidget {
  /// Exposes [controller]'s current frame to every descendant of [child].
  const RenderControllerScope({required this.controller, required this.child, super.key});

  /// The frame clock driving this subtree.
  final RenderController controller;

  /// The subtree that reads the current frame via [FrameProvider].
  final Widget child;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<int>(
    valueListenable: controller,
    builder: (context, frame, child) => FrameProvider(frame: frame, child: child!),
    child: child,
  );
}
