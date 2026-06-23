import 'dart:io';

/// Reads one line of input, or `null` at end of input. Injectable so `fluvie
/// init` tests drive the prompts without a real terminal.
typedef LineReader = String? Function();

/// The interactive prompt seam for `fluvie init`.
///
/// `fluvie`'s other commands are batch-only; `init` is the one place a user
/// answers questions, so the input side is a seam and every prompt has a default
/// the user accepts by pressing Enter. Pass `readLine` in tests; the default
/// reads stdin.
final class InitPrompt {
  /// Creates a prompt writing questions to [out] and reading answers via
  /// [readLine] (default: `stdin.readLineSync`).
  InitPrompt({required this.out, LineReader? readLine}) : _readLine = readLine ?? _stdinReadLine;

  // coverage:ignore-start: real stdin; the seam is exercised via an injected reader.
  static String? _stdinReadLine() => stdin.readLineSync();
  // coverage:ignore-end

  /// Where questions are written.
  final StringSink out;

  final LineReader _readLine;

  /// Asks [question], showing [defaultValue] in brackets; returns the trimmed
  /// answer, or [defaultValue] when the user presses Enter (or input ends).
  String ask(String question, {required String defaultValue}) {
    out.write('$question [$defaultValue]: ');
    final line = _readLine()?.trim();
    return line == null || line.isEmpty ? defaultValue : line;
  }

  /// Asks a yes/no [question]; returns [defaultYes] when the user presses Enter.
  bool confirm(String question, {bool defaultYes = true}) {
    out.write('$question [${defaultYes ? 'Y/n' : 'y/N'}]: ');
    final line = _readLine()?.trim().toLowerCase();
    if (line == null || line.isEmpty) return defaultYes;
    return line == 'y' || line == 'yes';
  }
}
