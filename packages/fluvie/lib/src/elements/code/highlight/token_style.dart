/// The syntactic kind of a highlighted code token.
///
/// A `SyntaxHighlighter` classifies each run of source into one of these kinds;
/// a `CodeTheme` then maps each kind to a color. The kinds are the small,
/// theme-stable set Fluvie colors (mapped from highlight.js's class names), not
/// the full grammar of any one language — a punctuation token is punctuation
/// whether it is Dart or Python.
enum TokenStyle {
  /// A language keyword (`void`, `class`, `def`, `return`).
  keyword,

  /// A string or character literal, including its quotes.
  string,

  /// A line or block comment.
  comment,

  /// A numeric literal (integer, double, hex).
  number,

  /// A type name, class name, or built-in type.
  type,

  /// A function, method, or built-in name at a call or declaration site.
  function,

  /// A bracket, operator, separator, or other punctuation.
  punctuation,

  /// Unclassified text: identifiers and whitespace the grammar did not tag.
  plain,
}
