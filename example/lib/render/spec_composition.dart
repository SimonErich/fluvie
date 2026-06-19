import 'dart:convert';
import 'dart:io';

import 'package:fluvie/fluvie.dart';
import 'package:fluvie_example/render/composition_entry.dart';

/// Reads a [VideoSpec] from a JSON file at [path].
///
/// Throws a [FormatException] when the file is not a JSON object (a malformed
/// spec then surfaces as a `FluvieSpecError` from [VideoSpec.fromJson]).
VideoSpec videoSpecFromFile(String path) {
  final decoded = jsonDecode(File(path).readAsStringSync());
  if (decoded is! Map<String, Object?>) {
    throw const FormatException('Spec file must contain a JSON object');
  }
  return VideoSpec.fromJson(decoded);
}

/// Builds a [CompositionEntry] from [spec]: geometry and fps come from the spec,
/// the frame count from the built video, and the media sources from a static
/// walk of its scenes (so `Image`/`Clip` pre-resolve like any composition).
CompositionEntry compositionFromSpec(VideoSpec spec) {
  final video = spec.build();
  return CompositionEntry(
    key: 'spec',
    width: spec.size.width,
    height: spec.size.height,
    fps: spec.fps,
    frameCount: video.totalFrames,
    build: spec.build,
    mediaSources: collectMediaSources(video.scenes),
  );
}

/// Builds a [CompositionEntry] from the spec JSON file at [path].
CompositionEntry compositionFromSpecFile(String path) =>
    compositionFromSpec(videoSpecFromFile(path));

/// Writes [spec] to [path] as pretty JSON (the reproducible artifact).
void writeSpecToFile(VideoSpec spec, String path) =>
    File(path).writeAsStringSync(const JsonEncoder.withIndent('  ').convert(spec.toJson()));
