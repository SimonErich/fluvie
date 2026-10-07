part of 'inspector_sections.dart';

// The text-bearing sections: Text (wave 1) and the rich wave-2 types whose
// surface is a source string plus a few timing knobs. Defaults mirror the
// element builders (Typewriter speed 2f, Terminal prompt `$ `, plaintext
// Code, instant reveal).

List<OiPropertyRow> _textStyleRows(
  Map<String, Object?> element,
  ElementPatch patch,
  TokenColorScope colors,
  TextStyle? tokenStyle,
) {
  final style = element['style'] is Map<String, Object?>
      ? element['style']! as Map<String, Object?>
      : const <String, Object?>{};
  return [
    OiPropertyRow(
      label: 'Text',
      editor: InspectorTextField(
        value: element['text'] as String? ?? '',
        onChanged: (next) => patch({'text': next}),
      ),
    ),
    OiPropertyRow(
      label: 'Size',
      editor: MathNumberInput(
        label: '',
        value: style['fontSize'] is num
            ? (style['fontSize']! as num).toDouble()
            : tokenStyle?.fontSize ?? 32,
        min: 1,
        onChanged: (next) => patch({
          'style': {...style, 'fontSize': next},
        }),
      ),
    ),
    OiPropertyRow(
      label: 'Color',
      editor: ColorField(
        label: 'Color',
        color: colors.resolve(style['color'], tokenStyle?.color ?? const Color(0xFFF9FAFB)),
        boundToken: TokenColorScope.boundTokenOf(style['color']),
        tokens: colors.tokens,
        recents: colors.recents,
        onCommitted: colors.onPicked,
        onTokenSelected: colors.tokens.isEmpty
            ? null
            : (name) => patch({
                'style': {
                  ...style,
                  'color': {'token': name},
                },
              }),
        onChanged: (next) => patch({
          'style': {...style, 'color': encodeColor(next)},
        }, mergeGroup: 'pick-text-color'),
      ),
    ),
  ];
}

List<OiPropertyRow> _typewriterRows(Map<String, Object?> element, ElementPatch patch) => [
  _timeRow(element, patch, 'Speed', 'speed', placeholder: '2f'),
  _switchRow(element, patch, 'Caret', 'caret'),
];

List<OiPropertyRow> _markdownRows(Map<String, Object?> element, ElementPatch patch) => [
  _textRow(element, patch, 'Source', 'source', maxLines: 6),
  _timeRow(element, patch, 'Reveal', 'reveal'),
];

// A Terminal's `lines` session stays raw JSON: its cmd/out entries edit on
// the canvas story, not in a property row.
List<OiPropertyRow> _terminalRows(Map<String, Object?> element, ElementPatch patch) => [
  _textRow(element, patch, 'Prompt', 'prompt', placeholder: r'$ ', emptyClears: true),
  _timeRow(element, patch, 'Typing', 'typingSpeed', placeholder: '2f'),
  _timeRow(element, patch, 'Line gap', 'lineGap', placeholder: '18f'),
];

List<OiPropertyRow> _codeRows(Map<String, Object?> element, ElementPatch patch) {
  final reveal = element['reveal'];
  final kind = reveal is Map<String, Object?> ? reveal['kind'] as String? ?? 'instant' : 'instant';
  final theme = element['theme'] as String? ?? 'default';
  return [
    _textRow(element, patch, 'Language', 'language', placeholder: 'plaintext', emptyClears: true),
    _selectRow(
      'Theme',
      key: const ValueKey('style-code-theme'),
      value: theme,
      options: const ['default', 'dark', 'light'],
      onPicked: (next) {
        if (next != theme) patch({'theme': next == 'default' ? null : next});
      },
    ),
    // Switching the reveal kind seeds the widget-default parameter (typing
    // 2f, lineByLine 18f); instant removes the key.
    _selectRow(
      'Reveal',
      key: const ValueKey('style-code-reveal'),
      value: kind,
      options: const ['instant', 'typing', 'lineByLine'],
      onPicked: (next) {
        if (next == kind) return;
        patch({
          'reveal': switch (next) {
            'typing' => {'kind': 'typing', 'speed': '2f'},
            'lineByLine' => {'kind': 'lineByLine', 'perLine': '18f'},
            _ => null,
          },
        });
      },
    ),
    // The active kind's own time knob. The codec requires the parameter,
    // so an invalid or empty commit drops instead of removing the key.
    if (kind == 'typing') _codeRevealParamRow(reveal, patch, 'Speed', 'speed', '2f'),
    if (kind == 'lineByLine') _codeRevealParamRow(reveal, patch, 'Per line', 'perLine', '18f'),
  ];
}

OiPropertyRow _codeRevealParamRow(
  Object? reveal,
  ElementPatch patch,
  String label,
  String key,
  String placeholder,
) {
  final current = reveal is Map<String, Object?> ? reveal : const <String, Object?>{};
  return OiPropertyRow(
    label: label,
    editor: InspectorTextField(
      key: const ValueKey('style-code-reveal-param'),
      value: current[key]?.toString() ?? '',
      placeholder: placeholder,
      onChanged: (next) {
        if (next.isEmpty) return;
        try {
          decodeTime(next);
        } on FluvieSpecError {
          return;
        }
        patch({
          'reveal': {...current, key: next},
        });
      },
    ),
  );
}
