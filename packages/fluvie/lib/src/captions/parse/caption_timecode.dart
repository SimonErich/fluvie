import 'package:fluvie/src/core/errors/fluvie_timing_error.dart';
import 'package:fluvie/src/core/time.dart';

/// One caption timecode `[HH:]MM:SS<sep>mmm` parsed to absolute [Time]: SubRip
/// uses a comma separator, WebVTT a period, and VTT may omit the leading hours
/// field.
///
/// The hour group is optional, so `MM:SS.mmm` and `HH:MM:SS.mmm` both parse.
/// The result is wall-clock seconds, exact at millisecond resolution, so the
/// caption layer resolves the same frame regardless of fps. A timecode that
/// does not match the grammar is a [FluvieTimingError] naming the offending
/// [line] — captions parse in a pure pre-pass, so a bad file fails fast with an
/// actionable message instead of mid-capture.
Time parseCaptionTimecode(String timecode, String separator, {required String line}) {
  final escaped = RegExp.escape(separator);
  final pattern = RegExp('^(?:(\\d+):)?(\\d{1,2}):(\\d{1,2})$escaped(\\d{1,3})\$');
  final match = pattern.firstMatch(timecode.trim());
  if (match == null) {
    throw FluvieTimingError(
      'Malformed caption timecode "$timecode" on line "$line". Expected '
      '[HH:]MM:SS${separator}mmm (for example 00:00:01${separator}500).',
    );
  }
  final hours = int.parse(match.group(1) ?? '0');
  final minutes = int.parse(match.group(2)!);
  final seconds = int.parse(match.group(3)!);
  final millis = int.parse(match.group(4)!.padRight(3, '0'));
  final total = hours * 3600 + minutes * 60 + seconds + millis / 1000;
  return Time.seconds(total);
}

/// Splits caption [source] into normalized lines: CRLF and CR are folded to LF
/// first, so a Windows-authored file parses identically to a Unix one.
List<String> normalizeCaptionLines(String source) =>
    source.replaceAll('\r\n', '\n').replaceAll('\r', '\n').split('\n');
