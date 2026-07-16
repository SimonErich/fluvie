import 'dart:io';

import 'package:fluvie/src/core/aspect.dart';
import 'package:fluvie/src/core/export.dart';
import 'package:fluvie/src/core/quality.dart';
import 'package:fluvie/src/core/time.dart';

/// The [Export] for a `--format` value, or `null` (the mp4 default) for
/// `null`/empty/`mp4`.
///
/// A capture harness reads `--format` as a string (a `--dart-define` carries no
/// types), so the mapping lives here rather than in each harness — the CLI, the
/// Playground, and the example gallery all parse it the same way or they render
/// different files for the same flag.
///
/// Throws an [ArgumentError] naming the value when it is not a known format.
Export? parseExportFormat(String? format) => switch (format) {
  null || '' || 'mp4' => null,
  'gif' => const Export.gif(),
  'imageSequence' => const Export.imageSequence(),
  'transparent' => const Export.transparent(),
  _ => throw ArgumentError.value(format, 'format', 'unknown export format'),
};

/// The [Quality] for a `--quality` value, or `null` (the config default) for
/// `null`/empty. Throws an [ArgumentError] when the name is not a [Quality].
Quality? parseQuality(String? quality) =>
    quality == null || quality.isEmpty ? null : Quality.values.byName(quality);

/// The [Aspect] for an `--aspect` value, or `null` (the composition's declared
/// size wins) for `null`/empty. Throws an [ArgumentError] when the name is not
/// an [Aspect].
Aspect? parseAspect(String? aspect) =>
    aspect == null || aspect.isEmpty ? null : Aspect.values.byName(aspect);

/// The [Time] for a `--poster` value (`1.5s`, `30f`, `500ms`), or `null` (no
/// poster) for `null`/empty.
///
/// Throws an [ArgumentError] naming the value when it carries no known unit, so
/// a typo surfaces as a stated error rather than a silently missing poster.
Time? parsePosterTime(String? poster) {
  if (poster == null || poster.isEmpty) return null;
  if (poster.endsWith('ms')) return Time.ms(int.parse(poster.substring(0, poster.length - 2)));
  if (poster.endsWith('s')) {
    return Time.seconds(double.parse(poster.substring(0, poster.length - 1)));
  }
  if (poster.endsWith('f')) return Time.frames(int.parse(poster.substring(0, poster.length - 1)));
  throw ArgumentError.value(poster, 'poster', 'expected a Time string like 1.5s, 30f or 500ms');
}

/// Writes `"<completed>/<total>"` to [path] atomically, for a launcher polling a
/// render's progress.
///
/// A sibling `.tmp` file is written then renamed over [path], so a concurrent
/// reader always sees a whole count, never a half-written one. Pass this as
/// `renderVideo(onProgress:)` when the host wired a progress file.
void writeRenderProgress(String path, int completed, int total) {
  File('$path.tmp')
    ..writeAsStringSync('$completed/$total', flush: true)
    ..renameSync(path);
}
