import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/widgets.dart';
import 'package:fluvie/src/core/keyframe.dart';
import 'package:fluvie/src/rendering/primitives/fade_box.dart';

/// Applies a composed [Keyframe] to [child] as one render-safe widget stack —
/// the single place keyframe state becomes widgets.
///
/// Wrap order, innermost out: child → [Transform] (scale·scaleX/scaleY,
/// rotation and skews in turns, `alignment: origin`) → [FractionalTranslation]
/// (`x`/`y` are fractions of the element's own size) →
/// [ImageFiltered] (gaussian blur) → [FadeBox]. Identity values wrap
/// nothing, so a natural keyframe returns [child] untouched.
///
/// [Keyframe.color] is never painted here — it is published as data for
/// color-capable elements. The outer fade is the [FadeBox] primitive: it
/// clamps, skips the wrap at exactly `1.0`, and is paint-identical to the raw
/// [Opacity] it replaced at every value.
Widget applyKeyframe(Keyframe keyframe, Widget child) {
  var result = child;
  final matrix = _transformMatrix(keyframe);
  if (matrix != null) {
    result = Transform(transform: matrix, alignment: keyframe.origin, child: result);
  }
  final dx = keyframe.x ?? 0;
  final dy = keyframe.y ?? 0;
  if (dx != 0 || dy != 0) {
    result = FractionalTranslation(translation: Offset(dx, dy), child: result);
  }
  final blur = keyframe.blur ?? 0;
  if (blur > 0) {
    result = ImageFiltered(
      imageFilter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
      child: result,
    );
  }
  final opacity = keyframe.opacity;
  if (opacity != null) {
    result = FadeBox(opacity: opacity, child: result);
  }
  return result;
}

/// The combined scale/rotation/skew matrix of [keyframe], or `null` when it
/// is the identity (nothing to mount).
///
/// Composition order is fixed for determinism: rotation ∘ skewX ∘ skewY ∘
/// scale — scale applies to the child first, then skews, then rotation.
Matrix4? _transformMatrix(Keyframe keyframe) {
  final sx = (keyframe.scale ?? 1) * (keyframe.scaleX ?? 1);
  final sy = (keyframe.scale ?? 1) * (keyframe.scaleY ?? 1);
  final rotation = keyframe.rotation ?? 0;
  final skewX = keyframe.skewX ?? 0;
  final skewY = keyframe.skewY ?? 0;
  if (sx == 1 && sy == 1 && rotation == 0 && skewX == 0 && skewY == 0) return null;
  final matrix = Matrix4.identity();
  if (rotation != 0) matrix.rotateZ(rotation * 2 * math.pi);
  if (skewX != 0) matrix.multiply(Matrix4.skewX(skewX * 2 * math.pi));
  if (skewY != 0) matrix.multiply(Matrix4.skewY(skewY * 2 * math.pi));
  if (sx != 1 || sy != 1) matrix.multiply(Matrix4.diagonal3Values(sx, sy, 1));
  return matrix;
}
