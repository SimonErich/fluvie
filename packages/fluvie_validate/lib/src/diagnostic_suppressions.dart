part of 'fluvie_code_analyzer.dart';

/// Applies Dart's comment directives to programmatically executed Fluvie rules.
/// Compiler diagnostics already have their own analyzer suppression handling.
final class _DiagnosticSuppressions {
  _DiagnosticSuppressions(this._resolved) {
    var token = _resolved.unit.beginToken;
    while (true) {
      for (
        Token? comment = token.precedingComments;
        comment is CommentToken;
        comment = comment.next
      ) {
        _add(comment);
      }
      if (token == _resolved.unit.endToken) break;
      token = token.next!;
    }
  }

  final ResolvedUnitResult _resolved;
  final Set<String> _file = {};
  final Map<int, Set<String>> _lines = {};
  static final _directive = RegExp(r'^//\s*(ignore_for_file|ignore)\s*:\s*(.*)$');

  void _add(CommentToken comment) {
    final match = _directive.firstMatch(comment.lexeme);
    if (match == null) return;
    final codes = match.group(2)!.split(',').map((code) => code.trim().toLowerCase()).toSet();
    if (match.group(1) == 'ignore_for_file') {
      _file.addAll(codes);
      return;
    }
    final location = _resolved.lineInfo.getLocation(comment.offset);
    final lineStart = comment.offset - location.columnNumber + 1;
    final standalone = _resolved.content.substring(lineStart, comment.offset).trim().isEmpty;
    final line = location.lineNumber + (standalone ? 1 : 0);
    (_lines[line] ??= {}).addAll(codes);
  }

  bool contains(Diagnostic diagnostic) {
    final code = diagnostic.diagnosticCode.name.toLowerCase();
    final line = _resolved.lineInfo.getLocation(diagnostic.offset).lineNumber;
    bool matches(Set<String> codes) => codes.contains(code) || codes.contains('type=lint');
    return matches(_file) || matches(_lines[line] ?? const {});
  }
}
