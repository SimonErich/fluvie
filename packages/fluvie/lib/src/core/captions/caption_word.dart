import 'package:fluvie/src/core/time.dart';
import 'package:meta/meta.dart';

/// One word of an inline caption track: the [text] and when it appears.
///
/// Words are value-equal data — `Captions.words` carries a list of them, and
/// the caption renderer turns each into a styled, word-level pop.
@immutable
final class CaptionWord {
  /// Creates a caption word showing [text] starting [at].
  const CaptionWord(this.text, {required this.at});

  /// The word as displayed, punctuation included.
  final String text;

  /// When the word appears, measured from the start of the video.
  final Time at;

  @override
  bool operator ==(Object other) => other is CaptionWord && other.text == text && other.at == at;

  @override
  int get hashCode => Object.hash(CaptionWord, text, at);

  @override
  String toString() => "CaptionWord('$text', at: $at)";
}
