import 'package:fluvie/src/core/time.dart';
import 'package:meta/meta.dart';

/// One parsed caption block: the [text] shown over its `[start, end]` window,
/// with optional word-level timing for karaoke and word-pop.
///
/// An SRT/VTT parser produces a list of these in display order, and the caption
/// layer shows the cue whose window contains the current frame. Cues are
/// value-equal data, so two parses of the same file produce equal cues and the
/// frame cache stays stable.
@immutable
final class CaptionCue {
  /// Creates a cue showing [text] from [start] to [end], with optional
  /// per-[words] timing (empty when the source carries none).
  CaptionCue(
    this.text, {
    required this.start,
    required this.end,
    List<CaptionCueWord> words = const [],
  }) : words = List.unmodifiable(words);

  /// The caption text shown over the window, punctuation included.
  final String text;

  /// When the cue first appears, measured from the start of the video.
  final Time start;

  /// When the cue disappears, measured from the start of the video.
  final Time end;

  /// The cue's words with their individual start times, in display order;
  /// empty when the source carries no word-level timing. Unmodifiable.
  final List<CaptionCueWord> words;

  @override
  bool operator ==(Object other) =>
      other is CaptionCue &&
      other.text == text &&
      other.start == start &&
      other.end == end &&
      _sameWords(other.words, words);

  @override
  int get hashCode => Object.hash(CaptionCue, text, start, end, Object.hashAll(words));

  static bool _sameWords(List<CaptionCueWord> a, List<CaptionCueWord> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  String toString() => "CaptionCue('$text', $start..$end)";
}

/// One word inside a [CaptionCue] with its own start time — the unit karaoke
/// highlights and word-pop staggers.
///
/// Distinct from the inline `CaptionWord` authoring type: this is parser output
/// scoped to a cue, carrying the word as displayed and when it begins. Value
/// equal so a re-parse produces equal words.
@immutable
final class CaptionCueWord {
  /// Creates a cue word showing [text] starting [at] (from the start of the
  /// video).
  const CaptionCueWord(this.text, {required this.at});

  /// The word as displayed, punctuation included.
  final String text;

  /// When the word begins, measured from the start of the video.
  final Time at;

  @override
  bool operator ==(Object other) => other is CaptionCueWord && other.text == text && other.at == at;

  @override
  int get hashCode => Object.hash(CaptionCueWord, text, at);

  @override
  String toString() => "CaptionCueWord('$text', at: $at)";
}
