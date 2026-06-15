import 'package:flutter/widgets.dart';
import 'package:fluvie/src/composition/camera/camera.dart';
import 'package:fluvie/src/rendering/runtime/frame_provider.dart';
import 'package:fluvie/src/timing/time_scope_provider.dart';

/// The scene-wide camera transform: a [Transform.scale] driven
/// by the scene clock, sitting *outside* every element transform but inside the
/// compositor's blend chain.
///
/// `Video` mounts one of these per scene (only when the scene carries a
/// [Camera]) between the scene's [TimeScopeProvider] and its element subtree, so
/// the move scales the whole scene image without disturbing per-element motion.
///
/// The layer reads the nearest [FrameProvider] for the current frame and the
/// nearest [TimeScopeProvider] for the scene scope, computes the eased progress
///
/// ```text
/// q = ease.transform(((frame - startFrame) / overFrames).clamp(0, 1))
/// ```
///
/// with `overFrames = camera.over.resolveFrames(scope)` (so a relative `over`
/// is a fraction of the *scene*), and mounts the [Camera.poseAt] pose. It is
/// **always mounted** — the shape never changes, and a [Camera.still] resolves
/// to the identity transform — so the constant-shape invariant the registrar
/// relies on holds. Because the frame comes from the nearest provider, the
/// boundary freeze freezes the camera too.
final class CameraLayer extends StatelessWidget {
  /// Wraps [child] in the scene-wide move [camera] describes.
  const CameraLayer({required this.camera, required this.child, super.key});

  /// The move to apply across the scene.
  final Camera camera;

  /// The scene subtree the camera scales.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scope = TimeScopeProvider.of(context);
    final frame = FrameProvider.of(context).frame;
    final overFrames = camera.over.resolveFrames(scope);
    // A zero-length move snaps straight to the end pose (q = 1); the clamp keeps
    // q in [0, 1] so the pose holds before the start and after `over`.
    final raw = overFrames <= 0 ? 1.0 : (frame - scope.startFrame) / overFrames;
    final q = camera.ease.transform(raw.clamp(0.0, 1.0));
    final pose = camera.poseAt(q);
    return Transform.scale(scale: pose.scale, alignment: pose.focal, child: child);
  }
}
