import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:fluvie/src/animation/effect_kind.dart';
import 'package:fluvie/src/animation/runtime/sampled_shader_view.dart';
import 'package:fluvie/src/core/color/tone_curve.dart';

/// The effect behind `kind: "curves"`: a master tone curve and one per
/// channel, applied through a warm fragment shader that samples the
/// rendered child.
///
/// The curves are baked to a 256-sample strip on the CPU ([bakeBytes], one
/// channel's curve per colour channel, the master composed in) and the
/// shader reads the strip — evaluation happens once at bake, not per pixel
/// per frame. The colour-space contract: input and output are non-linear
/// sRGB; the curves index on encoded values and answer encoded values.
///
/// [intensity] mixes toward the untouched child. At exactly zero, and when
/// every curve is the identity, the child mounts unwrapped — an exact
/// no-op, not a near one.
final class CurvesEffect implements PixelAnimationEffect {
  /// Creates the effect; every curve defaults to the identity.
  const CurvesEffect({
    this.master = ToneCurve.identity,
    this.red = ToneCurve.identity,
    this.green = ToneCurve.identity,
    this.blue = ToneCurve.identity,
    this.intensity = 1,
  });

  /// The curve every channel passes through first.
  final ToneCurve master;

  /// The red channel's own curve, after [master].
  final ToneCurve red;

  /// The green channel's own curve, after [master].
  final ToneCurve green;

  /// The blue channel's own curve, after [master].
  final ToneCurve blue;

  /// How far toward the curved frame to move, `0` to `1`.
  final double intensity;

  /// The bundled shader this effect paints with.
  static const String shaderAsset = 'shaders/color_curves.frag';

  /// Whether nothing would change: zero intensity or all-identity curves.
  bool get isNoOp =>
      intensity == 0 ||
      (master.isIdentity && red.isIdentity && green.isIdentity && blue.isIdentity);

  /// The 256x1 RGBA strip the shader samples: each colour channel holds its
  /// own curve composed after the master; alpha stays opaque.
  Uint8List bakeBytes() {
    final bytes = Uint8List(256 * 4);
    for (var i = 0; i < 256; i++) {
      final x = master.at(i / 255);
      bytes[i * 4] = (red.at(x) * 255).round();
      bytes[i * 4 + 1] = (green.at(x) * 255).round();
      bytes[i * 4 + 2] = (blue.at(x) * 255).round();
      bytes[i * 4 + 3] = 255;
    }
    return bytes;
  }

  /// The content key the baked strip publishes under — a pure digest of the
  /// bytes, so two elements with the same curves share one image.
  String get lookupKey {
    // 32-bit FNV-1a: stays exact under JavaScript number semantics, which
    // the web build compiles to.
    var hash = 0x811c9dc5;
    for (final byte in bakeBytes()) {
      hash = ((hash ^ byte) * 0x01000193) & 0xFFFFFFFF;
    }
    return 'curves:${hash.toRadixString(16)}';
  }

  @override
  Widget build(Widget child, double progress) {
    if (isNoOp) return child;
    return SampledShaderView(
      shaderAsset: shaderAsset,
      lookupKey: lookupKey,
      floats: (_) => [intensity.clamp(0.0, 1.0)],
      child: child,
    );
  }

  @override
  String toString() => 'CurvesEffect(intensity: $intensity)';
}
