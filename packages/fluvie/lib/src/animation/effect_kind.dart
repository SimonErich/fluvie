import 'package:fluvie/src/animation/animation_effect.dart';

/// The two pipeline classes of the unified `Animation` list: transforms wrap
/// the widget first; pixel effects post-process the result.
enum EffectKind {
  /// Widget-wrapping effects — opacity, transforms, clips. Applied innermost,
  /// in list order.
  transform,

  /// Pixel post-effects — grain, vignette, shaders. Applied outermost, in list
  /// order among themselves, regardless of where they sat in the `.animate()`
  /// list.
  pixel,
}

/// Marker interface classifying an [AnimationEffect] as a pixel post-effect.
///
/// Classification is type-driven so the custom-effect contract stays a
/// two-member interface: a plain `implements AnimationEffect` is a
/// [EffectKind.transform]; implementing this marker opts into
/// [EffectKind.pixel] ordering. Adds no members of its own.
abstract interface class PixelAnimationEffect implements AnimationEffect {}

/// Classifies [effect] for pipeline ordering: pixel iff it implements
/// [PixelAnimationEffect], transform otherwise.
EffectKind effectKindOf(AnimationEffect effect) =>
    effect is PixelAnimationEffect ? EffectKind.pixel : EffectKind.transform;
