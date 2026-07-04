import 'dart:io';

import 'package:flutter/widgets.dart' show Directionality, TextDirection;
import 'package:fluvie/src/core/aspect.dart';
import 'package:fluvie/src/core/defaults.dart';
import 'package:fluvie/src/rendering/render_aspect.dart';
import 'package:fluvie/src/rendering/render_service.dart';
import 'package:fluvie/src/templates/video_template.dart';

/// Renders a parameterized [VideoTemplate] for one `Props` value — the
/// data-driven-batch entry.
///
/// It builds `template.build(props)` (a pure function of [props]) and runs the
/// resulting `Video` through the same offline capture path as [render]: it
/// re-derives the canvas size from `aspect.sizeFor(longEdge)`, mounts an
/// `AspectScope`, and drives the production capture shell once through
/// [RenderService.captureToDirectory]. [aspect] defaults to the canonical
/// [Aspect.reels] (the 9:16 format), so a template renders
/// vertical without a per-call aspect; pass another aspect to fan one template
/// out across formats.
///
/// This is distinct from [render], which renders a fixed `Video` widget: Dart
/// has no overloading, so `render(video, aspect:)` and `renderTemplate(template,
/// props:)` are separate free functions. The template form reuses [render]
/// rather than duplicating the shell, so both share the same scope chain.
///
/// An error in `template.build(props)` (for example a `Video` the props leave
/// with no scenes) surfaces unchanged.
///
/// The built `Video` is wrapped in a left-to-right [Directionality] before
/// capture: a `VideoTemplate.build` returns a bare `Video`, and the render
/// canvas has no ambient locale, so the template path supplies the LTR default
/// its `Text` needs (the same wrap the example compositions add by
/// hand around `render(video, aspect:)`).
///
/// The host owns the pumping mechanics through [pumpWidget] and [pumpFrame],
/// which keeps this offline and gate-runnable (the example and goldens pass a
/// `flutter_test` pump; the CLI passes its binding's). To encode the result, run
/// the returned manifest's ffmpeg args through an `FfmpegProvider`.
Future<RenderAspectResult> renderTemplate<P>(
  VideoTemplate<P> template, {
  required P props,
  required int frameCount,
  required Directory outDir,
  required RenderService service,
  required ShellMount pumpWidget,
  required ShellFramePump pumpFrame,
  Aspect aspect = Aspect.reels,
  int longEdge = VideoDefaults.longEdge,
  int fps = VideoDefaults.fps,
  String compositionKey = 'template',
  bool cacheEnabled = false,
}) {
  final video = template.build(props);
  return render(
    composition: Directionality(textDirection: TextDirection.ltr, child: video),
    aspect: aspect,
    frameCount: frameCount,
    outDir: outDir,
    service: service,
    pumpWidget: pumpWidget,
    pumpFrame: pumpFrame,
    longEdge: longEdge,
    fps: fps,
    compositionKey: compositionKey,
    cacheEnabled: cacheEnabled,
  );
}
