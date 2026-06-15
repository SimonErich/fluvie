import 'package:fluvie/src/captions/parse/caption_timecode.dart';
import 'package:fluvie/src/core/captions/caption_cue.dart';
import 'package:fluvie/src/core/errors/fluvie_timing_error.dart';
import 'package:fluvie/src/core/time.dart';

/// Matches an inline VTT word timestamp `<HH:MM:SS.mmm>` in a cue payload.
final _inlineTimestamp = RegExp(r'<(\d{1,2}:\d{1,2}:\d{1,2}\.\d{1,3})>');

/// Parses WebVTT [source] into [CaptionCue]s in display order: an in-house,
/// line-oriented parser, pure and deterministic, with no dependency.
///
/// VTT opens with a `WEBVTT` header, then cues separated by blank lines; each
/// cue has an optional identifier line, an `HH:MM:SS.mmm --> HH:MM:SS.mmm`
/// timecode line, then one or more payload lines. An inline `<HH:MM:SS.mmm>`
/// timestamp before a word carries word-level timing (preserved as the cue's
/// [CaptionCue.words]). CRLF endings are tolerated. A malformed timecode is a
/// [FluvieTimingError] naming the line, so a bad file fails fast in the pre-pass.
List<CaptionCue> parseVtt(String source) {
  final blocks = _blocks(normalizeCaptionLines(source));
  return [for (final block in blocks) _parseCue(block)];
}

/// Groups the body lines (after the `WEBVTT` header) into cue blocks. The
/// header line and any header metadata before the first blank line are dropped.
List<List<String>> _blocks(List<String> lines) {
  var start = 0;
  while (start < lines.length && lines[start].trim().isNotEmpty) {
    start += 1; // skip the WEBVTT header and any header metadata lines
  }
  final blocks = <List<String>>[];
  var current = <String>[];
  for (final line in lines.skip(start)) {
    if (line.trim().isEmpty) {
      if (current.isNotEmpty) {
        blocks.add(current);
        current = <String>[];
      }
    } else {
      current.add(line);
    }
  }
  if (current.isNotEmpty) blocks.add(current);
  return blocks;
}

/// Turns one cue [block] into a [CaptionCue]: an optional identifier line, the
/// timecode line, then the payload (joined with newlines, inline word timing
/// preserved).
CaptionCue _parseCue(List<String> block) {
  var index = 0;
  if (block.isNotEmpty && !block[index].contains('-->')) {
    index += 1; // a cue identifier precedes the timecode line
  }
  if (index >= block.length) {
    throw FluvieTimingError('WebVTT cue "${block.join('\n')}" has no timecode line.');
  }
  final (start, end) = _parseArrow(block[index]);
  final payloadLines = block.sublist(index + 1);
  return CaptionCue(
    _stripTimestamps(payloadLines),
    start: start,
    end: end,
    words: _wordsFrom(payloadLines, start),
  );
}

/// Parses an `HH:MM:SS.mmm --> HH:MM:SS.mmm` arrow line; cue settings after the
/// end timecode (alignment, position) are ignored.
(Time, Time) _parseArrow(String line) {
  final parts = line.split('-->');
  if (parts.length != 2) {
    throw FluvieTimingError('Malformed WebVTT timecode line "$line": expected "start --> end".');
  }
  final start = parseCaptionTimecode(parts[0], '.', line: line);
  final endField = parts[1].trim().split(RegExp(r'\s+')).first;
  final end = parseCaptionTimecode(endField, '.', line: line);
  return (start, end);
}

/// The display text of [payloadLines]: each line has its inline `<...>`
/// timestamp tags removed and its words collapsed to single spaces, and the
/// lines are re-joined with a newline so a multi-line cue keeps its breaks.
String _stripTimestamps(List<String> payloadLines) => payloadLines
    .map(
      (line) => line
          .replaceAll(_inlineTimestamp, '')
          .split(RegExp(r'\s+'))
          .where((w) => w.isNotEmpty)
          .join(' '),
    )
    .join('\n');

/// The word-level timing of [payloadLines], or empty when none is present.
///
/// A VTT inline `<timestamp>` precedes the word it times, so the parser splits
/// the payload on those tags: the first segment starts at the cue [start], each
/// later segment at its leading timestamp. Words in one segment share its time.
List<CaptionCueWord> _wordsFrom(List<String> payloadLines, Time start) {
  final joined = payloadLines.join(' ');
  if (!_inlineTimestamp.hasMatch(joined)) return const [];
  final words = <CaptionCueWord>[];
  var at = start;
  var cursor = 0;
  for (final match in _inlineTimestamp.allMatches(joined)) {
    _addWords(words, joined.substring(cursor, match.start), at);
    at = parseCaptionTimecode(match.group(1)!, '.', line: match.group(0)!);
    cursor = match.end;
  }
  _addWords(words, joined.substring(cursor), at);
  return words;
}

/// Splits [segment] into whitespace-delimited words, each at time [at].
void _addWords(List<CaptionCueWord> words, String segment, Time at) {
  for (final word in segment.split(RegExp(r'\s+')).where((w) => w.isNotEmpty)) {
    words.add(CaptionCueWord(word, at: at));
  }
}
