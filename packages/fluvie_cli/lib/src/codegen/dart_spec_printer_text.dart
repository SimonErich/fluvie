part of 'dart_spec_printer.dart';

/// A `Text(...)` or `Text.rich(...)` constructor, mirroring `_text` in
/// fluvie's builder: exactly one of `text` or `spans` (the printer rejects
/// the same shapes the builder does, so the two layers agree).
String _textElement(Map<String, Object?> element) {
  final text = element['text'];
  final spans = element['spans'];
  if ((text == null) == (spans == null)) {
    throw const FormatException('A Text takes exactly one of "text" or "spans"');
  }
  final tail = <String?>[
    if (element['style'] != null) 'style: ${_textStyle(_map(element['style']))}',
    if (element['textAlign'] != null)
      'textAlign: ${_enumValue('TextAlign', element['textAlign']! as String)}',
    if (element['maxLines'] != null) 'maxLines: ${_num(element['maxLines'])}',
  ];
  final framed =
      element['decoration'] != null || element['padding'] != null || element['maxWidth'] != null;
  if (framed) tail.add('textWidthBasis: TextWidthBasis.longestLine');
  final String label;
  if (spans == null) {
    label = 'Text(${_args([_str(text! as String), ...tail])})';
  } else {
    final children = [for (final span in spans as List) _spanLiteral(_map(span))].join(', ');
    label = 'Text.rich(${_args(['TextSpan(children: [$children])', ...tail])})';
  }
  if (!framed) return label;
  final padding = element['padding'] == null ? <String, Object?>{} : _map(element['padding']);
  final width = element['maxWidth'] == null ? 'double.infinity' : _num(element['maxWidth']);
  return 'ConstrainedBox(constraints: BoxConstraints(maxWidth: $width), child: Align(widthFactor: 1, heightFactor: 1, child: DecoratedBox( '
      'decoration: ${element['decoration'] == null ? 'const BoxDecoration()' : _decoration(_map(element['decoration']))}, '
      'child: Padding(padding: EdgeInsets.symmetric(horizontal: ${_num(padding['horizontal'] ?? 0)}, '
      'vertical: ${_num(padding['vertical'] ?? 0)}), child: $label))))';
}

/// One `TextSpan(...)` literal. A link span appends the underline after the
/// authored style fields and prints the `semanticsLabel` exactly as the
/// builder constructs it, so widget-authored and spec-authored trees match.
String _spanLiteral(Map<String, Object?> span) {
  final text = span['text']! as String;
  final link = span['link'];
  final style = span['style'];
  final styleArgs = [
    ...?(style == null ? null : _textStyleArgs(_map(style))),
    if (link != null) 'decoration: TextDecoration.underline',
  ];
  return 'TextSpan(${_args([
    'text: ${_str(text)}',
    if (styleArgs.isNotEmpty) 'style: TextStyle(${_args(styleArgs)})',
    if (link != null) 'semanticsLabel: ${_str('$text, link to $link')}',
  ])})';
}
