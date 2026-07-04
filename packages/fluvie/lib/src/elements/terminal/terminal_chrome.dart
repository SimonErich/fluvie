/// @docImport 'package:fluvie/src/elements/terminal/terminal.dart';
library;

import 'package:meta/meta.dart' show immutable;

/// The optional window chrome painted above a `Terminal`: a title bar with the
/// three macOS traffic-light dots.
///
/// Chrome is opt-in. A `Terminal` with no chrome (the default) paints bare; a
/// `Terminal(chrome: TerminalChrome.macos(title: 'zsh'))` draws a title bar with
/// the dots, and [TerminalChrome.none] is the explicit no-chrome value. The bar
/// is themed by `context.fluvie.code.chromeColor`.
///
/// ```dart
/// Terminal(
///   chrome: TerminalChrome.macos(title: 'zsh'),
///   lines: [TerminalLine.cmd('npm test')],
/// );
/// ```
///
/// `@immutable` and value-equal by field, so two terminals with the same chrome
/// paint identically and the repaint cache stays frame-stable.
@immutable
final class TerminalChrome {
  /// Creates chrome with an explicit [title] and [showDots] dot config.
  const TerminalChrome({this.title, this.showDots = true});

  /// macOS-style chrome: a title bar carrying [title] and the three traffic-light
  /// dots.
  // coverage:ignore-line const ctor artifact behavior pinned by terminal tests
  const TerminalChrome.macos({this.title}) : showDots = true;

  /// An explicit no-chrome value: no title bar, no dots. Equivalent to passing
  /// `chrome: null` to a `Terminal`.
  static const TerminalChrome none = TerminalChrome(showDots: false);

  /// The text shown in the title bar, or `null` for an empty title.
  final String? title;

  /// Whether the three traffic-light dots are drawn at the left of the bar.
  final bool showDots;

  @override
  bool operator ==(Object other) =>
      other is TerminalChrome && other.title == title && other.showDots == showDots;

  @override
  int get hashCode => Object.hash(TerminalChrome, title, showDots);

  @override
  String toString() => 'TerminalChrome(title: $title, showDots: $showDots)';
}
