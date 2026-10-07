import 'package:flutter/widgets.dart';
import 'package:fluvie/src/animation/animation_effect.dart';
import 'package:fluvie/src/animation/effects/curves_effect.dart';
import 'package:fluvie/src/animation/effects/lut_effect.dart';
import 'package:fluvie/src/animation/effects/shader_effect.dart';
import 'package:fluvie/src/animation/motion_target.dart';
import 'package:fluvie/src/animation/runtime/effect_layer.dart';
import 'package:fluvie/src/animation/runtime/effect_stack.dart';
import 'package:fluvie/src/composition/runtime/scene_tree_walk.dart';
import 'package:fluvie/src/composition/scene.dart';

/// Every fragment-shader asset [scenes] will paint, deduplicated — the input
/// the shader warm pass loads before frame 0.
///
/// The sibling of `collectMediaSources`, and structural in the same way: it
/// reuses the shared tree walk and never mounts or builds anything, so it runs
/// in the pre-pass. Where the media collectors filter visited *widgets* by a
/// marker interface, this one reads each [MotionTarget]'s animations, because a
/// shader is declared as an effect rather than as an element.
///
/// It inherits the walk's boundary: a shader declared inside a custom
/// `StatelessWidget`'s `build` is invisible here, exactly as a `Clip` inside one
/// is invisible to `collectMediaSources`. Such a shader stays unwarmed and the
/// painter's error names the asset.
Set<String> collectShaderAssets(List<Scene> scenes, {List<Widget> overlays = const []}) {
  final assets = <String>{};
  walkSceneTree(scenes, overlays: overlays, (widget) {
    if (widget is MotionTarget) {
      for (final animation in widget.animations) {
        final effect = animation.effect;
        if (effect is ShaderEffect) assets.add(effect.shaderName);
      }
    }
    if (widget is EffectStack) {
      for (final (layer, effect) in stackLayersAtStart(widget)) {
        // A varying layer's start-frame numbers prove nothing about later
        // frames (a ramp may start at zero), so it always warms.
        if (effect is ShaderEffect) assets.add(effect.shaderName);
        if (effect is CurvesEffect && (layer.varies || !effect.isNoOp)) {
          assets.add(CurvesEffect.shaderAsset);
        }
        if (effect is LutEffect &&
            (effect.asset.isNotEmpty || effect.cube != null) &&
            (layer.varies || effect.intensity != 0)) {
          assets.add(LutEffect.shaderAsset);
        }
      }
    }
  });
  return assets;
}

/// Each of a stack's layers with the effect it resolves to at the start of
/// its element.
///
/// A keyframed layer answers a frame-specific instance, but the parts a
/// pre-pass reads — the shader asset, the curves, the LUT file — never vary
/// with the frame (only numbers do), so the start frame stands for them.
/// The layer rides along because its [EffectLayer.varies] flag is what says
/// whether the start frame's numbers can be trusted for skip decisions.
Iterable<(EffectLayer, AnimationEffect)> stackLayersAtStart(EffectStack stack) sync* {
  const start = (progress: 0.0, fps: 30, windowFrames: 0);
  for (final layer in stack.effects) {
    yield (layer, layer.resolve(start));
  }
}
