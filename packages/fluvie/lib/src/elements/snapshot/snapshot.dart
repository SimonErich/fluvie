import 'package:flutter/widgets.dart' show BoxFit, BuildContext, Key, StatelessWidget, Widget;
import 'package:flutter/widgets.dart' as flutter;
import 'package:fluvie/src/composition/runtime/collectible_children.dart';
import 'package:fluvie/src/core/anchor.dart';
import 'package:fluvie/src/core/errors/fluvie_render_exception.dart';
import 'package:fluvie/src/elements/runtime/element_shared.dart';
import 'package:fluvie/src/elements/snapshot/runtime/snapshot_capture_scope.dart';
import 'package:fluvie/src/rendering/runtime/render_mode_context.dart';

/// Rasterizes an arbitrary Flutter subtree once before the frame loop and paints
/// the cached still every frame.
///
/// This is the in-process subtree-capture path — a separate path from the
/// external `SnapshotService`/`SnapshotSource` pipeline that `Mermaid`,
/// `WebView`, and `Html` ride. No browser, no network, fully deterministic: the
/// captured pixels are a pure function of the [child], so the same subtree always
/// yields a byte-identical raster. Reach for `Snapshot` to freeze a busy or
/// expensive subtree (or one that cannot be captured live) into a single image
/// you then `.animate()` like any element.
///
/// ```dart
/// Snapshot(child: const ComplexChart()).animate([Animation.slideIn()])
/// ```
///
/// In **capture** a [SnapshotCaptureScope] mounted by the render pre-pass holds
/// this `Snapshot`'s pre-captured `ui.Image`; `build` paints it through a
/// capture-safe `RawImage` and never rebuilds the [child] (capture once, paint
/// the still — that is the whole point). The image is found by this `Snapshot`'s
/// [Key] when one is given, else by its stable build-order index (the same index
/// the pre-pass assigned). A capture with no pre-captured image for this
/// `Snapshot` is a determinism violation and throws a [FluvieRenderException]
/// naming the situation and the pre-pass.
///
/// In capture with **no scope at all** the render shell never ran the Snapshot
/// pre-pass, so painting the live [child] every frame would re-rasterize the
/// subtree per frame — a silent determinism-contract violation. `build` consults
/// [RenderModeContext.isCapture] and throws a [FluvieRenderException] naming the
/// missing pre-pass rather than render the live subtree.
///
/// In **preview** there is no scope and the mode is not capture, so `build`
/// passes the [child] through live — the running app shows the real subtree,
/// only a capture freezes it.
///
/// An optional [shared] anchor wraps the result in a `SharedElement` for a hero
/// morph across a scene boundary. Transforms and effects come
/// through `.animate()` only, like every element.
final class Snapshot extends StatelessWidget implements CollectibleChildren {
  /// Captures [child] and paints it scaled by [fit] (default [BoxFit.contain]),
  /// optionally tied to a [shared] hero anchor.
  const Snapshot({required this.child, this.shared, this.fit = BoxFit.contain, super.key});

  /// The subtree to rasterize once before the frame loop. Live in preview, a
  /// cached still in capture.
  final Widget child;

  /// An optional hero anchor: when non-null the snapshot morphs across the
  /// boundary it shares with the same anchor in the adjacent scene. `null`
  /// mounts no `SharedElement`.
  final Anchor? shared;

  /// How the captured raster scales into its box (default [BoxFit.contain] so
  /// the subtree is never cropped).
  final BoxFit fit;

  /// The captured subtree, so any `MediaCarrier` inside it is pre-resolved
  /// before the capture pre-pass mounts and rasterizes the [child].
  @override
  Iterable<Widget> get collectibleChildren => [child];

  @override
  Widget build(BuildContext context) {
    final scope = SnapshotCaptureScope.maybeOf(context);
    if (scope == null) {
      // A capture with no scope means the render shell never ran the Snapshot
      // pre-pass. Painting the live child would re-rasterize the subtree every
      // frame (a silent determinism-contract violation), so fail loud instead.
      // Only a true preview (not a capture) shows the live child.
      if (RenderModeContext.isCapture(context)) {
        throw FluvieRenderException(
          'Snapshot cannot render in capture without a SnapshotCaptureScope. The '
          'render pre-pass rasterizes every Snapshot subtree once before frame 0 '
          'and mounts a scope; this composition was captured without that '
          'pre-pass, so the live subtree would be re-rasterized every frame.',
        );
      }
      return child;
    }
    final captureKey = key != null
        ? SnapshotCaptureKey.keyed(key!)
        : SnapshotCaptureKey.index(scope.nextOrderIndex());
    final image = scope.imageFor(captureKey);
    if (image == null) {
      throw FluvieRenderException(
        'Snapshot has no pre-captured raster for this instance. The render '
        'pre-pass captures every Snapshot subtree once before frame 0 and mounts '
        'a SnapshotCaptureScope; this Snapshot was not captured (give it a stable '
        'Key so the pre-pass can find it, or ensure the pre-pass walked it).',
      );
    }
    return wrapShared(shared, flutter.RawImage(image: image, fit: fit));
  }
}
