import 'package:fluvie/src/animation/animation_effect.dart';
import 'package:fluvie/src/animation/effect_kind.dart';
import 'package:fluvie/src/animation/keyframed_number.dart';
import 'package:meta/meta.dart';

/// One entry of an effect stack: the effect this frame calls for, and which
/// half of the stack it belongs to.
///
/// A still layer answers with the same instance every frame; a keyframed one
/// reads its numbers off the frame. Either way the answer is a pure function
/// of the frame, so capture stays synchronous and two pumps of one frame paint
/// the same pixels.
///
/// [isPixel] travels with the layer rather than being read back off the
/// resolved effect, because a keyframed layer has no effect to ask until it is
/// handed a frame, and ordering has to be settled before that.
@immutable
final class EffectLayer {
  /// Creates a layer that resolves through [resolve] and orders by
  /// [isPixel]. [varies] defaults to true, because a resolver the layer
  /// cannot see into may answer differently per frame, and a pre-pass that
  /// assumed otherwise would skip warming something a later frame needs.
  const EffectLayer({required this.resolve, required this.isPixel, this.varies = true});

  /// A layer that is [effect] at every frame, classified by its own type.
  EffectLayer.of(AnimationEffect effect)
    : resolve = ((_) => effect),
      isPixel = effect is PixelAnimationEffect,
      varies = false;

  /// The effect at a frame.
  final AnimationEffect Function(EffectFrame frame) resolve;

  /// Whether the resolved effect can differ between frames. A pre-pass may
  /// trust a still layer's start-frame resolution outright; a varying one
  /// it must warm for the whole element life.
  final bool varies;

  /// Whether this layer post-processes pixels, so it mounts outside every
  /// transform-class layer.
  final bool isPixel;
}
