import 'package:flutter/widgets.dart';
import 'package:fluvie/src/animation/effect_kind.dart';
import 'package:fluvie/src/animation/runtime/sampled_shader_view.dart';

/// The effect behind `kind: "lut"`: a `.cube` 3D LUT applied through a warm
/// fragment shader that samples the rendered child.
///
/// The cube is loaded, validated and flattened by the render pre-pass
/// (`CubeLut` owns the parse and the security bounds), published as a tiled
/// 2D image, and sampled with trilinear filtering in the shader. The
/// colour-space contract is the parser's: non-linear sRGB in, non-linear
/// sRGB out, unit domain only.
///
/// [intensity] mixes toward the untouched child. At exactly zero the child
/// mounts unwrapped — an exact no-op, not a near one.
final class LutEffect implements PixelAnimationEffect {
  /// Creates the effect for the `.cube` file at [asset].
  const LutEffect({this.asset = '', this.cube, this.intensity = 1});

  /// The `.cube` asset the pre-pass loads and bakes.
  final String asset;

  /// Embedded, validated .cube text for portable imported looks.
  final String? cube;

  /// How far toward the graded frame to move, `0` to `1`.
  final double intensity;

  /// The bundled shader this effect paints with.
  static const String shaderAsset = 'shaders/color_lut.frag';

  /// The content key the baked cube publishes under.
  String get lookupKey => cube == null ? 'lut:$asset' : 'lut:inline:$cube';

  @override
  Widget build(Widget child, double progress) {
    if (intensity == 0 || (asset.isEmpty && cube == null)) return child;
    return SampledShaderView(
      shaderAsset: shaderAsset,
      lookupKey: lookupKey,
      // The tiled image is size*size wide and size tall, so its height IS
      // the cube size the shader needs.
      floats: (lookup) => [intensity.clamp(0.0, 1.0), lookup.height.toDouble()],
      child: child,
    );
  }

  @override
  String toString() => 'LutEffect(asset: $asset, intensity: $intensity)';
}
