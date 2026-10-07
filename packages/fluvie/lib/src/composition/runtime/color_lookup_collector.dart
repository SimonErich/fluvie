import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:fluvie/src/animation/effects/curves_effect.dart';
import 'package:fluvie/src/animation/effects/lut_effect.dart';
import 'package:fluvie/src/animation/runtime/effect_stack.dart';
import 'package:fluvie/src/composition/runtime/scene_tree_walk.dart';
import 'package:fluvie/src/composition/runtime/shader_collector.dart';
import 'package:fluvie/src/composition/scene.dart';

/// What the colour pre-pass has to bake before frame 0: curve strips whose
/// bytes are already computed (baking a curve is pure), and the `.cube`
/// assets whose files still need loading and validating.
typedef ColorLookupPlan = ({
  Map<String, Uint8List> baked,
  Set<String> lutAssets,
  Map<String, String> inlineLuts,
});

/// Collects every colour lookup [scenes] will sample, deduplicated by
/// content key — the sibling of `collectShaderAssets`, structural in the
/// same way, with the same walk boundary.
ColorLookupPlan collectColorLookups(List<Scene> scenes, {List<Widget> overlays = const []}) {
  final baked = <String, Uint8List>{};
  final lutAssets = <String>{};
  final inlineLuts = <String, String>{};
  walkSceneTree(scenes, overlays: overlays, (widget) {
    if (widget is! EffectStack) return;
    for (final (layer, effect) in stackLayersAtStart(widget)) {
      // A varying layer's start-frame numbers prove nothing about later
      // frames, so it always bakes; the curves content itself never varies.
      if (effect is CurvesEffect && (layer.varies || !effect.isNoOp)) {
        baked.putIfAbsent(effect.lookupKey, effect.bakeBytes);
      }
      if (effect is LutEffect &&
          (effect.asset.isNotEmpty || effect.cube != null) &&
          (layer.varies || effect.intensity != 0)) {
        if (effect.cube case final String cube) {
          inlineLuts[effect.lookupKey] = cube;
        } else {
          lutAssets.add(effect.asset);
        }
      }
    }
  });
  return (baked: baked, lutAssets: lutAssets, inlineLuts: inlineLuts);
}
