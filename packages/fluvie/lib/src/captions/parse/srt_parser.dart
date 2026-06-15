import 'package:fluvie/src/captions/parse/caption_timecode.dart';
import 'package:fluvie/src/core/captions/caption_cue.dart';
import 'package:fluvie/src/core/errors/fluvie_timing_error.dart';
import 'package:fluvie/src/core/time.dart';

/// Parses SubRip [source] into [CaptionCue]s in display order: an in-house,
/// line-oriented parser, pure and deterministic, with no dependency.
///
/// SubRip groups cues into blocks separated by blank lines; each block is an
/// index line, an `HH:MM:SS,mmm --> HH:MM:SS,mmm` timecode line, then one or
/// more text lines joined with a newline. CRLF endings and stray blank lines
/// are tolerated (the source is normalized first). A malformed timecode is a
/// [FluvieTimingError] naming the line, so a bad file fails fast in the pre-pass.
List<CaptionCue> parseSrt(String source) {
  final cues = <CaptionCue>[];
  for (final block in _blocks(normalizeCaptionLines(source))) {
    cues.add(_parseBlock(block));
  }
  return cues;
}

/// Groups [lines] into blocks, dropping the index line each block opens with
/// (SubRip blocks may start with a numeric index; some authors omit it).
List<List<String>> _blocks(List<String> lines) {
  final blocks = <List<String>>[];
  var current = <String>[];
  for (final line in lines) {
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

/// Turns one non-empty [block] into a cue: an optional leading index line, the
/// timecode line, then the text lines.
CaptionCue _parseBlock(List<String> block) {
  var index = 0;
  // A purely numeric first line is the SubRip index — skip it; otherwise the
  // block opens straight with the timecode line.
  if (block.isNotEmpty && !block[index].contains('-->')) {
    index += 1;
  }
  if (index >= block.length) {
    throw FluvieTimingError('SubRip block "${block.join('\n')}" has no timecode line.');
  }
  final timing = block[index];
  final (start, end) = _parseArrow(timing);
  final text = block.sublist(index + 1).join('\n');
  return CaptionCue(text, start: start, end: end);
}

/// Parses an `HH:MM:SS,mmm --> HH:MM:SS,mmm` arrow line into its start and end.
(Time, Time) _parseArrow(String line) {
  final parts = line.split('-->');
  if (parts.length != 2) {
    throw FluvieTimingError('Malformed SubRip timecode line "$line": expected "start --> end".');
  }
  final start = parseCaptionTimecode(parts[0], ',', line: line);
  final end = parseCaptionTimecode(parts[1], ',', line: line);
  return (start, end);
}
