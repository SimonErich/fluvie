import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart' show Directionality, TextDirection;
import 'package:fluvie/fluvie.dart';
import 'package:fluvie/rendering.dart';
import 'package:fluvie_example/render/composition_entry.dart';

/// Reads a [VideoSpec] from a JSON file at [path].
///
/// Throws a [FormatException] when the file is not a JSON object (a malformed
/// spec then surfaces as a `FluvieSpecError` from [VideoSpec.fromJson]).
///
/// Any property Fluvie does not recognize (and would silently drop while
/// rendering) is surfaced through [onWarn], which defaults to writing one line
/// per warning to stderr — so a typo in a hand-written spec is visible without
/// failing the render. Pass a no-op to suppress.
VideoSpec videoSpecFromFile(String path, {void Function(FluvieSpecWarning warning)? onWarn}) {
  final decoded = jsonDecode(File(path).readAsStringSync());
  if (decoded is! Map<String, Object?>) {
    throw const FormatException('Spec file must contain a JSON object');
  }
  final spec = VideoSpec.fromJson(decoded);
  unknownSpecProps(decoded).forEach(onWarn ?? _warnToStderr);
  return spec;
}

void _warnToStderr(FluvieSpecWarning warning) => stderr.writeln('fluvie: spec warning: $warning');

/// Builds a [CompositionEntry] from [spec]: geometry and fps come from the spec,
/// the frame count from the built video, and the media sources from a static
/// walk of its scenes (so `Image`/`Clip` pre-resolve like any composition).
///
/// The built tree is wrapped in a left-to-right [Directionality]: the capture
/// canvas has no ambient locale, so a spec-built `Text` (a bare `RichText`)
/// needs the LTR default the way the hand-written lessons and `renderTemplate`
/// supply one. Without it the render throws "No Directionality widget found" at
/// mount.
CompositionEntry compositionFromSpec(VideoSpec spec) {
  final video = spec.build();
  return CompositionEntry(
    key: 'spec',
    width: spec.size.width,
    height: spec.size.height,
    fps: spec.fps,
    frameCount: video.totalFrames,
    build: () => Directionality(textDirection: TextDirection.ltr, child: spec.build()),
    mediaSources: collectMediaSources(video.scenes),
  );
}

/// Builds a [CompositionEntry] from the spec JSON file at [path].
CompositionEntry compositionFromSpecFile(String path) =>
    compositionFromSpec(videoSpecFromFile(path));

/// Writes [spec] to [path] as pretty JSON (the reproducible artifact).
void writeSpecToFile(VideoSpec spec, String path) =>
    File(path).writeAsStringSync(const JsonEncoder.withIndent('  ').convert(spec.toJson()));
