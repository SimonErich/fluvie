import 'package:flutter/painting.dart' show Color, FontWeight, TextStyle;
import 'package:meta/meta.dart';

/// How a caption track is drawn: the [textStyle] of the words, the
/// [background] behind them, the [highlight] color of the active word, and the
/// [wordPop] / [karaoke] behavior flags the caption layer reads.
///
/// Ship the three presets — [CaptionStyle.tikTok] (bold, popping words),
/// [CaptionStyle.subtitle] (a plain lower-third caption), and
/// [CaptionStyle.karaoke] (per-word highlight) — or build a custom style. Value
/// equal const, so a styled track caches stably across builds and two
/// builds produce identical captions.
@immutable
final class CaptionStyle {
  /// Creates a style from an explicit [textStyle], [background], [highlight],
  /// and the [wordPop] / [karaoke] flags.
  // coverage:ignore-line: const-ctor artifact, pinned by caption_values_coverage_test
  const CaptionStyle({
    required this.textStyle,
    required this.background,
    required this.highlight,
    this.wordPop = false,
    this.karaoke = false,
  });

  /// Bold white words on a translucent dark pill that pop in one by one — the
  /// social-clip caption look.
  // coverage:ignore-line: const-ctor artifact, pinned by caption_values_coverage_test
  const CaptionStyle.tikTok()
    : textStyle = const TextStyle(
        color: Color(0xFFFFFFFF),
        fontSize: 34,
        fontWeight: FontWeight.w800,
      ),
      background = const Color(0xCC000000),
      highlight = const Color(0xFFFFE45C),
      wordPop = true,
      karaoke = false;

  /// A plain, readable lower-third subtitle: white text on a subtle dark band,
  /// no pop, no per-word highlight.
  const CaptionStyle.subtitle()
    : textStyle = const TextStyle(
        color: Color(0xFFFFFFFF),
        fontSize: 24,
        fontWeight: FontWeight.w500,
      ),
      background = const Color(0x99000000),
      highlight = const Color(0xFFFFFFFF),
      wordPop = false,
      karaoke = false;

  /// A karaoke caption: the whole line shows dimmed and the active word lights
  /// up in the [highlight] color as it is sung.
  // coverage:ignore-line: const-ctor artifact, pinned by caption_values_coverage_test
  const CaptionStyle.karaoke()
    : textStyle = const TextStyle(
        color: Color(0x80FFFFFF),
        fontSize: 30,
        fontWeight: FontWeight.w700,
      ),
      background = const Color(0xB3000000),
      highlight = const Color(0xFF4EC9B0),
      wordPop = false,
      karaoke = true;

  /// The base text style of the caption words (the active word may override its
  /// color via [highlight] when [karaoke] is set).
  final TextStyle textStyle;

  /// The background painted behind the caption block.
  final Color background;

  /// The color the active word takes in [karaoke] mode (and the accent the
  /// presets read).
  final Color highlight;

  /// Whether each word pops in on its own start time (word-pop).
  final bool wordPop;

  /// Whether the active word is highlighted as it plays (karaoke).
  final bool karaoke;

  @override
  bool operator ==(Object other) =>
      other is CaptionStyle &&
      other.textStyle == textStyle &&
      other.background == background &&
      other.highlight == highlight &&
      other.wordPop == wordPop &&
      other.karaoke == karaoke;

  @override
  int get hashCode => Object.hash(CaptionStyle, textStyle, background, highlight, wordPop, karaoke);

  @override
  String toString() =>
      'CaptionStyle(wordPop: $wordPop, karaoke: $karaoke, background: $background)';
}
