import 'dart:convert';
import 'dart:io';

import 'package:fluvie/fluvie.dart';
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

/// Builds a [CompositionEntry] from [spec]; everything a render needs is derived
/// from the built `Video`.
CompositionEntry compositionFromSpec(VideoSpec spec) =>
    CompositionEntry(key: 'spec', video: spec.build);

/// Builds a [CompositionEntry] from the spec JSON file at [path].
CompositionEntry compositionFromSpecFile(String path) =>
    compositionFromSpec(videoSpecFromFile(path));

/// Writes [spec] to [path] as pretty JSON (the reproducible artifact).
void writeSpecToFile(VideoSpec spec, String path) =>
    File(path).writeAsStringSync(const JsonEncoder.withIndent('  ').convert(spec.toJson()));
