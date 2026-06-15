import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:fluvie/src/composition/transition/runtime/shared_element_registry.dart';

/// Paints one shared-element pair's morph for the current frame.
///
/// The destination ([SharedPair] `target`) child is mounted as the morph's
/// own child and laid out loose at the canvas constraints, so it can size to
/// whatever the natural layout gives it. At paint the morph reads both slots'
/// rects **live** off the render tree (`getTransformTo`, never cached), lerps
/// them by [progress], and draws the child transformed (translate + non-uniform
/// scale) onto that rect under the lerped opacity. Because the rects come from
/// the mounted scenes, the morph follows any `Camera` on either scene for free.
final class MorphLayer extends SingleChildRenderObjectWidget {
  /// Morphs [pair] at eased [progress], painting the destination [child].
  const MorphLayer({
    required this.pair,
    required this.progress,
    required Widget super.child,
    super.key,
  });

  /// The matched source/target slots this layer morphs between.
  final SharedPair pair;

  /// The eased blend progress in `[0, 1]`: `0` paints over the source rect,
  /// `1` over the target rect.
  final double progress;

  @override
  RenderMorphLayer createRenderObject(BuildContext context) =>
      RenderMorphLayer(pair: pair, progress: progress);

  @override
  void updateRenderObject(BuildContext context, RenderMorphLayer renderObject) => renderObject
    ..pair = pair
    ..progress = progress;
}

/// The render object behind [MorphLayer].
final class RenderMorphLayer extends RenderProxyBox {
  /// Creates a morph render box over [pair] at [progress].
  RenderMorphLayer({required SharedPair pair, required double progress}) {
    // Body-assigned: the private fields back getter/setter pairs whose setters
    // call markNeedsPaint, so an initializing formal cannot reach them.
    _pair = pair;
    _progress = progress;
  }

  late SharedPair _pair;
  late double _progress;

  /// The pair this layer morphs between.
  SharedPair get pair => _pair;
  set pair(SharedPair value) {
    if (identical(_pair.source, value.source) && identical(_pair.target, value.target)) {
      return;
    }
    _pair = value;
    markNeedsPaint();
  }

  /// The eased blend progress.
  double get progress => _progress;
  set progress(double value) {
    if (_progress == value) return;
    _progress = value;
    markNeedsPaint();
  }

  /// The source slot's rect in this layer's coordinate space, read live; falls
  /// back to [Rect.zero] when the slot is unmounted.
  Rect get sourceRect => _rectOf(_pair.source);

  /// The target slot's rect in this layer's coordinate space, read live.
  Rect get targetRect => _rectOf(_pair.target);

  /// The lerped rect the destination child is painted onto this frame.
  Rect get morphRect => Rect.lerp(sourceRect, targetRect, _progress)!;

  /// The lerped opacity from the two slots' live keyframe opacities.
  double get morphOpacity =>
      ui.lerpDouble(_pair.source.opacity, _pair.target.opacity, _progress)!.clamp(0.0, 1.0);

  Rect _rectOf(SharedSlotHandle handle) {
    final box = handle.box;
    if (box == null || !box.attached || !box.hasSize || !attached) return Rect.zero;
    final transform = box.getTransformTo(this);
    return MatrixUtils.transformRect(transform, Offset.zero & box.size);
  }

  @override
  void performLayout() {
    final loose = constraints.loosen();
    child?.layout(loose, parentUsesSize: true);
    size = constraints.biggest;
  }

  @override
  bool hitTestSelf(Offset position) => false;

  @override
  void paint(PaintingContext context, Offset offset) {
    final morphChild = child;
    if (morphChild == null) return;
    final rect = morphRect;
    final natural = morphChild.size;
    if (natural.isEmpty || rect.isEmpty) return;
    // Place the natural-sized child onto the lerped rect (in layer-local
    // space): translate to the rect origin then non-uniformly scale its
    // natural size up to the rect. The paint `offset` is applied by the
    // pushed layers, not baked into the transform.
    final transform = Matrix4.identity()
      ..translateByDouble(rect.left, rect.top, 0, 1)
      ..scaleByDouble(rect.width / natural.width, rect.height / natural.height, 1, 1);
    final alpha = (morphOpacity * 255).round().clamp(0, 255);
    context.pushOpacity(offset, alpha, (innerContext, innerOffset) {
      innerContext.pushTransform(
        needsCompositing,
        innerOffset,
        transform,
        (paintContext, _) => paintContext.paintChild(morphChild, Offset.zero),
      );
    });
  }
}
