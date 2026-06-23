part of 'dart_spec_printer.dart';

/// One scene child: the base element constructor, wrapped in `.animate(...)` when
/// it carries animations or an anchor (mirroring `buildElement`).
String _element(Map<String, Object?> element, _Anchors anchors) {
  final base = _elementBase(element);
  final animate = element['animate'];
  final animations = animate is List
      ? [for (final entry in animate) _animation(_map(entry), anchors)]
      : const <String>[];
  final anchorId = element['anchor'];
  final anchorVar = anchorId is String ? anchors.variableFor(anchorId) : null;
  if (animations.isEmpty && anchorVar == null) return base;
  final args = _args([
    '[${animations.join(', ')}]',
    if (anchorVar != null) 'anchor: $anchorVar',
  ]);
  return '$base.animate($args)';
}

String _elementBase(Map<String, Object?> element) {
  final type = element['type'];
  switch (type) {
    case 'Text':
      return 'Text(${_args([
        _str(element['text']! as String),
        if (element['style'] != null) 'style: ${_textStyle(_map(element['style']))}',
      ])})';
    case 'Box':
      return 'Box(${_args([
        if (element['color'] != null) 'color: ${_color(element['color'])}',
        if (element['size'] != null) 'size: ${_size(_map(element['size']))}',
      ])})';
    case 'Image':
      return _image(element);
    case 'Counter':
      return 'Counter(${_args([
        'to: ${_num(element['to'])}',
        if (element['from'] != null) 'from: ${_num(element['from'])}',
        if (element['duration'] != null) 'duration: ${_time(element['duration']! as String)}',
        if (element['style'] != null) 'style: ${_textStyle(_map(element['style']))}',
      ])})';
  }
  throw FormatException('Unknown element "$type"');
}

String _image(Map<String, Object?> element) {
  final source = _map(element['source']);
  final value = _str(source['value']! as String);
  final args = _args([
    value,
    if (element['fit'] != null) 'fit: ${_enumValue('BoxFit', element['fit']! as String)}',
  ]);
  return switch (source['kind']) {
    'asset' => 'Image.asset($args)',
    'network' => 'Image.network($args)',
    'file' => 'Image.file($args)',
    _ => throw FormatException('Unknown image source kind "${source['kind']}"'),
  };
}

String _size(Map<String, Object?> size) => 'Size(${_num(size['width'])}, ${_num(size['height'])})';

/// A `TextStyle(...)` over the curated spec subset, in canonical field order.
String _textStyle(Map<String, Object?> style) =>
    'TextStyle(${_args([
      if (style['color'] != null) 'color: ${_color(style['color'])}',
      if (style['fontSize'] != null) 'fontSize: ${_num(style['fontSize'])}',
      if (style['fontWeight'] != null) 'fontWeight: ${_fontWeight(style['fontWeight']! as String)}',
      if (style['fontFamily'] != null) 'fontFamily: ${_str(style['fontFamily']! as String)}',
      if (style['letterSpacing'] != null) 'letterSpacing: ${_num(style['letterSpacing'])}',
      if (style['height'] != null) 'height: ${_num(style['height'])}',
    ])})';

String _fontWeight(String name) => switch (name) {
  'bold' => 'FontWeight.bold',
  'normal' => 'FontWeight.normal',
  _ => 'FontWeight.$name',
};
