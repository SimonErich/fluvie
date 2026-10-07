part of 'dart_spec_printer.dart';

// The decoration and text-style literal printers, shared by Box, the styled
// text elements, and the rich spans.

/// A `BoxDecoration(...)` over the spec's decoration subset.
String _decoration(Map<String, Object?> decoration) =>
    'BoxDecoration(${_args([
      if (decoration['color'] != null) 'color: ${_color(decoration['color'])}',
      if (decoration['cornerRadius'] != null) 'borderRadius: BorderRadius.circular(${_num(decoration['cornerRadius'])})',
      if (decoration['border'] != null) 'border: ${_border(_map(decoration['border']))}',
      if (decoration['gradient'] != null) 'gradient: ${_linearGradient(_map(decoration['gradient']))}',
      if (decoration['shadow'] != null) 'boxShadow: [${_boxShadow(_map(decoration['shadow']))}]',
    ])})';

String _border(Map<String, Object?> border) =>
    'Border.all(${_args([
      if (border['color'] != null) 'color: ${_color(border['color'])}',
      if (border['width'] != null) 'width: ${_num(border['width'])}',
    ])})';

String _linearGradient(Map<String, Object?> gradient) {
  final colors = gradient['colors']! as List;
  return 'LinearGradient(${_args([
    'colors: [${colors.map(_color).join(', ')}]',
    if (gradient['stops'] != null) 'stops: ${_numList(gradient['stops'])}',
    if (gradient['begin'] != null) 'begin: ${_alignment(gradient['begin'])}',
    if (gradient['end'] != null) 'end: ${_alignment(gradient['end'])}',
  ])})';
}

String _boxShadow(Map<String, Object?> shadow) {
  final offset = shadow['offset'];
  return 'BoxShadow(${_args([
    if (shadow['color'] != null) 'color: ${_color(shadow['color'])}',
    if (shadow['blur'] != null) 'blurRadius: ${_num(shadow['blur'])}',
    if (shadow['spread'] != null) 'spreadRadius: ${_num(shadow['spread'])}',
    if (offset is Map<String, Object?>) 'offset: Offset(${_num(offset['x'])}, ${_num(offset['y'])})',
  ])})';
}

/// A `TextStyle(...)` over the curated spec subset, in canonical field order.
String _textStyle(Map<String, Object?> style) => 'TextStyle(${_args(_textStyleArgs(style))})';

/// The `TextStyle` argument fragments in canonical field order, shared with the
/// span printer (which appends a link underline after them). A type-scale
/// `token` resolves to its literal base first; sibling literals win per field.
List<String?> _textStyleArgs(Map<String, Object?> raw) {
  final style = _resolvedStyle(raw);
  return [
    if (style['color'] != null) 'color: ${_color(style['color'])}',
    if (style['fontSize'] != null) 'fontSize: ${_num(style['fontSize'])}',
    if (style['fontWeight'] != null) 'fontWeight: ${_fontWeight(style['fontWeight']! as String)}',
    if (style['fontStyle'] != null) 'fontStyle: FontStyle.${style['fontStyle']}',
    if (style['fontFamily'] != null) 'fontFamily: ${_str(style['fontFamily']! as String)}',
    if (style['letterSpacing'] != null) 'letterSpacing: ${_num(style['letterSpacing'])}',
    if (style['height'] != null) 'height: ${_num(style['height'])}',
  ];
}

String _fontWeight(String name) => switch (name) {
  'bold' => 'FontWeight.bold',
  'normal' => 'FontWeight.normal',
  _ => 'FontWeight.$name',
};
