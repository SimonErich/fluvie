part of 'dart_spec_printer.dart';

/// A `Terminal(...)` constructor, mirroring `_terminalElement` in fluvie's
/// builder: the lines list plus prompt, chrome, and the per-item timings.
String _terminalElement(Map<String, Object?> element) {
  final lines = element['lines']! as List;
  return 'Terminal(${_args([
    'lines: [${lines.map((line) => _terminalLine(_map(line))).join(', ')}]',
    if (element['prompt'] != null) 'prompt: ${_str(element['prompt']! as String)}',
    if (element['chrome'] != null) 'chrome: ${_terminalChrome(_map(element['chrome']))}',
    if (element['typingSpeed'] != null) 'typingSpeed: ${_time(element['typingSpeed']! as String)}',
    if (element['lineGap'] != null) 'lineGap: ${_time(element['lineGap']! as String)}',
    if (element['style'] != null) 'style: ${_textStyle(_map(element['style']))}',
  ])})';
}

/// A `TerminalLine.cmd(...)`/`TerminalLine.out(...)` literal from a line object.
String _terminalLine(Map<String, Object?> line) {
  final cmd = line['cmd'];
  if (cmd is String) {
    return 'TerminalLine.cmd(${_args([
      _str(cmd),
      if (line['prompt'] != null) 'prompt: ${_str(line['prompt']! as String)}',
    ])})';
  }
  final out = line['out'];
  if (out is String) return 'TerminalLine.out(${_str(out)})';
  throw const FormatException('A terminal line needs a "cmd" or an "out"');
}

/// A `TerminalChrome(...)` literal over the title and dots fields.
String _terminalChrome(Map<String, Object?> chrome) =>
    'TerminalChrome(${_args([
      if (chrome['title'] != null) 'title: ${_str(chrome['title']! as String)}',
      if (chrome['showDots'] != null) 'showDots: ${chrome['showDots']}',
    ])})';

/// A `Code(...)` (or `Code.diff(...)` when `after` is present) constructor.
String _codeElement(Map<String, Object?> element) {
  final after = element['after'];
  final shared = <String?>[
    if (element['language'] != null) 'language: ${_str(element['language']! as String)}',
    if (element['theme'] != null) 'theme: ${_codeTheme(element['theme']! as String)}',
    if (element['reveal'] != null) 'reveal: ${_codeReveal(_map(element['reveal']))}',
    if (element['style'] != null) 'style: ${_textStyle(_map(element['style']))}',
  ];
  final source = _str(element['source']! as String);
  if (after is String) return 'Code.diff(${_args([source, _str(after), ...shared])})';
  return 'Code(${_args([
    source,
    ...shared,
    if (element['focusLines'] != null) 'focusLines: ${_intSet(element['focusLines']! as List)}',
    if (element['highlightLines'] != null) 'highlightLines: ${_intSet(element['highlightLines']! as List)}',
  ])})';
}

/// A `CodeTheme.<preset>()` literal from the named theme string.
String _codeTheme(String name) => switch (name) {
  'dark' => 'CodeTheme.dark()',
  'light' => 'CodeTheme.light()',
  _ => throw FormatException('Unknown code theme "$name"'),
};

/// A `CodeReveal` value from the tagged reveal union.
String _codeReveal(Map<String, Object?> reveal) => switch (reveal['kind']) {
  'instant' => 'CodeReveal.instant',
  'typing' => 'CodeReveal.typing(${_time(reveal['speed']! as String)})',
  'lineByLine' => 'CodeReveal.lineByLine(${_time(reveal['perLine']! as String)})',
  _ => throw FormatException('Unknown code reveal kind "${reveal['kind']}"'),
};

/// A `Set<int>` literal from a JSON integer list; the empty set is typed so it
/// can never read as an empty map.
String _intSet(List<Object?> lines) =>
    lines.isEmpty ? '<int>{}' : '{${lines.map(_num).join(', ')}}';
