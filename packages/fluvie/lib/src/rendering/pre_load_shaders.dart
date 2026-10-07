import 'dart:ui' as ui;

import 'package:flutter/widgets.dart' show Widget;
import 'package:fluvie/src/animation/runtime/shader_loader.dart';
import 'package:fluvie/src/composition/runtime/shader_collector.dart';
import 'package:fluvie/src/rendering/collect_composition_media.dart';

/// Compiles every fragment-shader program [composition] paints, before the
/// frame loop. A no-op returning an empty map when it declares no shader or
/// wraps no `Video`.
///
/// Capture is synchronous, so a shader cannot compile mid-frame: the programs
/// must be ready up front, exactly like media and clip frames. The result is
/// published through a `WarmShaderScope` so each `ShaderEffect` can derive its
/// own shader from the shared program and paint without awaiting anything.
///
/// This is the first pass that hands an author-supplied asset string to the
/// engine's loader, so an asset that a spec supplied has already been narrowed
/// to a plain relative path by the spec decoder. A failure surfaces here, in
/// the pre-pass, as a `FluvieRenderException` naming the asset — not at paint,
/// where a reported paint error is easy to miss.
Future<Map<String, ui.FragmentProgram>> preLoadCompositionShaders({
  required Widget composition,
  ShaderLoader loader = const FragmentProgramShaderLoader(),
}) async {
  final video = compositionVideo(composition);
  if (video == null) return const {};
  return preLoadShaders(
    collectShaderAssets(video.scenes, overlays: video.overlays),
    loader: loader,
  );
}

/// Compiles each asset in [assets] through [loader], keyed by asset.
///
/// Separate from [preLoadCompositionShaders] so a host that already knows its
/// asset set (or a test) can warm without walking a composition. Loading runs
/// in declaration order and an empty set compiles nothing.
Future<Map<String, ui.FragmentProgram>> preLoadShaders(
  Iterable<String> assets, {
  ShaderLoader loader = const FragmentProgramShaderLoader(),
}) async {
  final programs = <String, ui.FragmentProgram>{};
  for (final asset in assets) {
    if (programs.containsKey(asset)) continue;
    programs[asset] = await loader.load(asset);
  }
  return programs;
}
