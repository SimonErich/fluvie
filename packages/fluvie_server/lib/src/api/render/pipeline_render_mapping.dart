import 'dart:convert';
import 'dart:io';

import 'package:fluvie_cli/fluvie_cli.dart';
import 'package:fluvie_server/src/api/render/render_request.dart';
import 'package:fluvie_server/src/api/render/render_runner.dart';

/// The `(extension, contentType)` output target for a request's [format].
(String, String) formatTarget(String? format) => switch (format) {
  null || 'mp4' => ('mp4', 'video/mp4'),
  'gif' => ('gif', 'image/gif'),
  'transparent' => ('webm', 'video/webm'),
  // coverage:ignore-line unreachable formats are validated at request parse
  _ => throw RenderFailure('Unsupported format: $format'),
};

/// The poster PNG path that sits beside an output video at [outPath].
String posterPath(String outPath) => outPath.replaceFirst(RegExp(r'\.[^.]+$'), '.poster.png');

/// The `--dart-define` map for [request]'s capture. Writes any spec or base
/// spec JSON under [workDir] and points AI authoring at [specOut].
Map<String, String> definesFor(RenderRequest request, Directory workDir, String specOut) =>
    switch (request) {
      // A code render carries no defines of its own; the block is merged in by
      // the caller and the staged harness supplies the rest.
      CodeRenderRequest() => const {},
      KeyRenderRequest() => const {},
      SpecRenderRequest(:final spec) => specDefines(
        _writeJson(spec, '${workDir.path}/input.fluvie.json'),
      ),
      PromptRenderRequest(:final prompt, :final provider) => generateDefines(
        prompt: prompt,
        specOut: specOut,
        provider: provider,
      ),
      EditRenderRequest(:final baseSpec, :final change, :final provider) => editDefines(
        baseSpecPath: _writeJson(baseSpec, '${workDir.path}/base.fluvie.json'),
        change: change,
        specOut: specOut,
        provider: provider,
      ),
    };

String _writeJson(Map<String, Object?> json, String path) {
  File(path).writeAsStringSync(jsonEncode(json));
  return path;
}

/// Reads the live [progressFile] and forwards a parsed [RenderProgress] to
/// [onProgress], or does nothing when the file is absent or unparseable.
void emitProgress(String progressFile, void Function(RenderProgress) onProgress) {
  final file = File(progressFile);
  if (!file.existsSync()) return;
  final progress = parseRenderProgress(file.readAsStringSync());
  if (progress != null) onProgress(progress);
}
