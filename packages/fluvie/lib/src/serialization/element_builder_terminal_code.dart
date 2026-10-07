part of 'element_builder.dart';

// The terminal and code builders mirror the widget defaults (prompt `$ `,
// typing speed 2 frames, line gap 18 frames, plaintext language, instant
// reveal) the same way the Counter case mirrors its one-second reveal.

/// A `Terminal` from its spec props: the `lines` session plus prompt, chrome,
/// and the two per-item timings.
Widget _terminalElement(Map<String, Object?> props) => Terminal(
  lines: _terminalLines(props['lines']),
  prompt: props['prompt'] is String ? props['prompt']! as String : r'$ ',
  chrome: props['chrome'] == null ? null : _terminalChrome(props['chrome']),
  typingSpeed: props['typingSpeed'] == null
      ? const Time.frames(2)
      : decodeTime(props['typingSpeed'], path: const ['typingSpeed']),
  lineGap: props['lineGap'] == null
      ? const Time.frames(18)
      : decodeTime(props['lineGap'], path: const ['lineGap']),
  style: props['style'] == null ? null : decodeTextStyle(props['style'], path: const ['style']),
);

/// The `lines` list: each entry is `{"cmd": ..., "prompt"?: ...}` or
/// `{"out": ...}`, mirroring `TerminalLine.cmd`/`TerminalLine.out`.
List<TerminalLine> _terminalLines(Object? raw) {
  if (raw is! List || raw.isEmpty) {
    throw FluvieSpecError('A Terminal needs a non-empty "lines" list', path: const ['lines']);
  }
  return [for (var i = 0; i < raw.length; i++) _terminalLine(raw[i], i)];
}

TerminalLine _terminalLine(Object? raw, int index) {
  if (raw is Map<String, Object?>) {
    final cmd = raw['cmd'];
    final out = raw['out'];
    final prompt = raw['prompt'];
    if (cmd is String && out == null) {
      return TerminalLine.cmd(cmd, prompt: prompt is String ? prompt : null);
    }
    if (out is String && cmd == null) return TerminalLine.out(out);
  }
  throw FluvieSpecError(
    'A terminal line is {"cmd": ...} (with an optional "prompt") or {"out": ...}',
    path: ['lines', '$index'],
  );
}

TerminalChrome _terminalChrome(Object? raw) {
  if (raw is! Map<String, Object?>) {
    throw FluvieSpecError('Expected a chrome object {title, showDots}', path: const ['chrome']);
  }
  final title = raw['title'];
  return TerminalChrome(
    title: title is String ? title : null,
    showDots: _boolOr(raw['showDots'], true, 'showDots'),
  );
}

/// A `Code` (or, when `after` is present, a `Code.diff`) from its spec props.
Widget _codeElement(Map<String, Object?> props) {
  final source = _string(props['source'], 'source');
  final after = props['after'];
  final language = props['language'] is String ? props['language']! as String : 'plaintext';
  final theme = _codeTheme(props['theme']);
  final reveal = _codeReveal(props['reveal']);
  final style = props['style'] == null
      ? null
      : decodeTextStyle(props['style'], path: const ['style']);
  final focusLines = _lineSet(props['focusLines'], 'focusLines');
  final highlightLines = _lineSet(props['highlightLines'], 'highlightLines');
  if (after == null) {
    return Code(
      source,
      language: language,
      theme: theme,
      reveal: reveal,
      focusLines: focusLines,
      highlightLines: highlightLines,
      style: style,
    );
  }
  if (after is! String) {
    throw FluvieSpecError('Expected a string "after"', path: const ['after']);
  }
  if (focusLines != null || highlightLines != null) {
    throw FluvieSpecError(
      'A Code diff (with "after") takes no "focusLines" or "highlightLines"',
      path: const ['after'],
    );
  }
  return Code.diff(source, after, language: language, theme: theme, reveal: reveal, style: style);
}

/// The named code themes the spec accepts, mirroring the `CodeTheme` presets.
CodeTheme? _codeTheme(Object? raw) => switch (raw) {
  null => null,
  'dark' => const CodeTheme.dark(),
  'light' => const CodeTheme.light(),
  _ => throw FluvieSpecError(
    'Unknown code theme "$raw"; expected "dark" or "light"',
    path: const ['theme'],
  ),
};

/// The tagged reveal union: `{"kind": "typing", "speed": ...}`,
/// `{"kind": "lineByLine", "perLine": ...}`, or `{"kind": "instant"}`.
CodeReveal _codeReveal(Object? raw) {
  if (raw == null) return CodeReveal.instant;
  if (raw is Map<String, Object?>) {
    switch (raw['kind']) {
      case 'instant':
        return CodeReveal.instant;
      case 'typing':
        return CodeReveal.typing(decodeTime(raw['speed'], path: const ['reveal', 'speed']));
      case 'lineByLine':
        return CodeReveal.lineByLine(decodeTime(raw['perLine'], path: const ['reveal', 'perLine']));
    }
  }
  throw FluvieSpecError(
    'Expected a reveal of kind "instant", "typing" (with "speed"), or '
    '"lineByLine" (with "perLine")',
    path: const ['reveal'],
  );
}

/// A 1-based line-number set from a JSON integer list, or null when absent.
Set<int>? _lineSet(Object? raw, String field) {
  if (raw == null) return null;
  if (raw is List && raw.every((line) => line is int)) return raw.cast<int>().toSet();
  throw FluvieSpecError('Expected a list of integers "$field"', path: [field]);
}
