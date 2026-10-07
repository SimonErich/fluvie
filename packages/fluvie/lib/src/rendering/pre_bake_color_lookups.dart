import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter/widgets.dart' show Widget;
import 'package:fluvie/src/composition/runtime/color_lookup_collector.dart';
import 'package:fluvie/src/core/color/cube_lut.dart';
import 'package:fluvie/src/core/errors/fluvie_render_exception.dart';
import 'package:fluvie/src/rendering/collect_composition_media.dart';

/// Loads a `.cube` file's text for [preBakeCompositionColorLookups]; tests
/// inject a fake so the unit path never touches the asset bundle.
typedef CubeTextLoader = Future<String> Function(String asset);

/// The default loader: the asset bundle, trying the key as written and then
/// the `packages/fluvie/`-prefixed spelling (what the key becomes when the
/// render runs inside an app that depends on fluvie).
Future<String> bundleCubeText(String asset) async {
  try {
    return await rootBundle.loadString(asset);
  } on Object {
    return rootBundle.loadString('packages/fluvie/$asset');
  }
}

/// Bakes every colour lookup [composition] samples, before the frame loop:
/// curve strips from their pure bytes, `.cube` LUTs loaded through
/// [loadCubeText], validated by [CubeLut.parse] (a LUT file is external
/// input and rides the security rules for one), and flattened for the
/// shader. A no-op returning an empty map when nothing samples colour.
///
/// Building a `ui.Image` is asynchronous, which is exactly why this runs in
/// the pre-pass: capture is synchronous and a lookup cannot decode
/// mid-frame. The result is published through a `ColorLookupScope`.
Future<Map<String, ui.Image>> preBakeCompositionColorLookups({
  required Widget composition,
  CubeTextLoader loadCubeText = bundleCubeText,
}) async {
  final video = compositionVideo(composition);
  if (video == null) return const {};
  final plan = collectColorLookups(video.scenes, overlays: video.overlays);
  final images = <String, ui.Image>{};
  for (final entry in plan.baked.entries) {
    images[entry.key] = await _decode(entry.value, width: 256, height: 1, key: entry.key);
  }
  for (final asset in plan.lutAssets) {
    final String text;
    try {
      text = await loadCubeText(asset);
    } on Object catch (error) {
      throw FluvieRenderException('Could not load LUT "$asset": $error');
    }
    final lut = CubeLut.parse(text);
    images['lut:$asset'] = await _decode(
      lut.toRgbaBytes(),
      width: lut.size * lut.size,
      height: lut.size,
      key: 'lut:$asset',
    );
  }
  for (final entry in plan.inlineLuts.entries) {
    final lut = CubeLut.parse(entry.value);
    images[entry.key] = await _decode(
      lut.toRgbaBytes(),
      width: lut.size * lut.size,
      height: lut.size,
      key: 'inline LUT',
    );
  }
  return images;
}

Future<ui.Image> _decode(
  Uint8List rgba, {
  required int width,
  required int height,
  required String key,
}) {
  final completer = Completer<ui.Image>();
  ui.decodeImageFromPixels(rgba, width, height, ui.PixelFormat.rgba8888, completer.complete);
  return completer.future.timeout(
    const Duration(seconds: 10),
    onTimeout: () => throw FluvieRenderException('Baking colour lookup "$key" timed out'),
  );
}
