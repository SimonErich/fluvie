/// @docImport 'package:fluvie/src/core/stagger.dart';
/// @docImport 'package:fluvie/src/elements/code/code_reveal.dart';
/// @docImport 'package:fluvie/src/elements/terminal/terminal.dart';
library;

import 'package:meta/meta.dart' show immutable;

/// One line in a `Terminal` element: either a typed command or a block of
/// streamed output.
///
/// A sealed value type, mirroring `CodeReveal` and `Stagger`: a [Terminal] takes
/// a `List<TerminalLine>` and the layout switches over the two variants to drive
/// the per-line reveal. Build lines with the named factories rather than the
/// concrete classes, so the public surface stays one type:
///
/// ```dart
/// Terminal(lines: [
///   TerminalLine.cmd('npm install'),
///   TerminalLine.out('added 120 packages'),
/// ]);
/// ```
///
/// Every line carries its literal [text] (no trailing newline) and is value-equal
/// by it, so two terminals built from the same lines produce identical layout and
/// the repaint cache stays frame-stable.
@immutable
sealed class TerminalLine {
  // coverage:ignore-line: const-ctor artifact, behavior pinned by terminal tests
  const TerminalLine(this.text);

  /// A typed command line: it types out glyph by glyph after a prompt with a
  /// blinking caret. [prompt] overrides the terminal's default prompt for this
  /// one line; `null` uses the terminal's prompt.
  const factory TerminalLine.cmd(String text, {String? prompt}) = TerminalCmd;

  /// A streamed-output line: it appears whole once its turn arrives, with no
  /// prompt and no caret.
  const factory TerminalLine.out(String text) = TerminalOut;

  /// The literal line text this line types or streams (no trailing newline).
  final String text;
}

/// The [TerminalLine.cmd] variant: a typed command with an optional per-line
/// [prompt] override.
final class TerminalCmd extends TerminalLine {
  /// Creates a typed command over [text], optionally overriding the terminal's
  /// prompt with [prompt].
  // coverage:ignore-line: const-ctor artifact, behavior pinned by terminal tests
  const TerminalCmd(super.text, {this.prompt});

  /// The prompt printed before this command, or `null` to use the terminal's
  /// default prompt (`$ `).
  final String? prompt;

  @override
  bool operator ==(Object other) =>
      other is TerminalCmd && other.text == text && other.prompt == prompt;

  @override
  int get hashCode => Object.hash(TerminalCmd, text, prompt);

  @override
  String toString() => 'TerminalLine.cmd($text)';
}

/// The [TerminalLine.out] variant: a streamed block of output text.
final class TerminalOut extends TerminalLine {
  /// Creates an output line over [text].
  // coverage:ignore-line: const-ctor artifact, behavior pinned by terminal tests
  const TerminalOut(super.text);

  @override
  bool operator ==(Object other) => other is TerminalOut && other.text == text;

  @override
  int get hashCode => Object.hash(TerminalOut, text);

  @override
  String toString() => 'TerminalLine.out($text)';
}
