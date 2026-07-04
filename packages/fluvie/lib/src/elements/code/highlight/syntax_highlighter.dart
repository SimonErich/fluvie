/// @docImport 'package:fluvie/src/elements/code/highlight/highlight_js_highlighter.dart';
library;

import 'package:fluvie/src/elements/code/highlight/highlight_span.dart';

/// Tokenizes source into colored spans — the interface `Code` reads so the
/// tokenizer can be swapped or faked in tests.
///
/// The default implementation is [HighlightJsHighlighter] (the highlight.js Dart
/// port). An implementation must be a pure function of `(source, language)`: no
/// IO, no clock, no randomness, so the same inputs always yield the same spans.
/// The returned spans' concatenated text must equal `source` (lossless),
/// so the reveal arithmetic indexes one joined string while the painter colors
/// each run by its kind.
// ignore: one_member_abstracts — the tokenizer seam is the type; a fake backs it in tests.
abstract interface class SyntaxHighlighter {
  /// The colored spans for [source] written in [language].
  ///
  /// An unknown [language] is not an error: it yields a single plain span over
  /// the whole [source]. Empty [source] yields an empty list.
  List<HighlightSpan> highlight(String source, String language);
}
