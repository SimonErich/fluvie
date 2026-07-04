import 'dart:ui' as ui;

import 'package:flutter_svg/svg.dart';
import 'package:fluvie/src/core/errors/fluvie_render_exception.dart';

/// Rasterizes an SVG string to a `ui.Image` in-process, deterministically.
///
/// This is Fluvie's own pixel step for `Mermaid`: a headless Chromium computes
/// the diagram *layout* (the SVG string), but the *pixels* are produced here by
/// `flutter_svg`'s `vg.loadPicture` and a `Picture.toImage`, so the same SVG and
/// size always yield a byte-identical raster (no Chromium GPU, no wall-clock).
/// The result is decoded-ready: it feeds the snapshot cache and the synchronous
/// `decodedSnapshotFor` paint path like any other resolved media.
///
/// By default the raster is sized to the SVG's own view box; pass `targetWidth`
/// and `targetHeight` to scale it to a fixed pixel box. Invalid or empty SVG is
/// a typed [FluvieRenderException] naming the failure, never a blank image.
final class MermaidSvgRasterizer {
  /// Creates the rasterizer; it is stateless and const.
  const MermaidSvgRasterizer();

  /// Rasterizes [svg] to a `ui.Image`, scaled to [targetWidth]x[targetHeight]
  /// when both are given (otherwise the SVG's view box size, rounded).
  Future<ui.Image> rasterize(String svg, {int? targetWidth, int? targetHeight}) async {
    if (svg.trim().isEmpty) {
      throw FluvieRenderException('Cannot rasterize an empty SVG string.');
    }
    final picture = await _loadPicture(svg);
    final source = picture.size;
    final width = targetWidth ?? source.width.round();
    final height = targetHeight ?? source.height.round();
    if (width <= 0 || height <= 0) {
      // coverage:ignore-start defensive guard a parsed picture always has a positive size so this arm cannot run with valid SVG input
      throw FluvieRenderException(
        'SVG rasterize produced a non-positive size (${width}x$height).',
      );
      // coverage:ignore-end
    }
    return _paint(picture.picture, source, width, height);
  }

  /// Loads [svg] to a vector-graphics picture, mapping any parse/decode fault to
  /// a typed error.
  Future<PictureInfo> _loadPicture(String svg) async {
    try {
      return await vg.loadPicture(SvgStringLoader(svg), null);
    } on Object catch (error) {
      throw FluvieRenderException('Failed to parse SVG: $error.');
    }
  }

  /// Paints [picture] (sized [source]) into a [width]x[height] `ui.Image`,
  /// scaling to fill the target box.
  Future<ui.Image> _paint(ui.Picture picture, ui.Size source, int width, int height) async {
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    if (source.width > 0 && source.height > 0) {
      canvas.scale(width / source.width, height / source.height);
    }
    canvas.drawPicture(picture);
    final composited = recorder.endRecording();
    try {
      return await composited.toImage(width, height);
    } finally {
      composited.dispose();
      picture.dispose();
    }
  }
}
