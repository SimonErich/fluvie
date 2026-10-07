part of 'dart_spec_printer.dart';

/// A `Mermaid(...)` constructor, mirroring `_mermaidElement` in fluvie's
/// builder: source, named theme, the reveal union, and the raster fit.
String _mermaidElement(Map<String, Object?> element) =>
    'Mermaid(${_args([
      _str(element['source']! as String),
      if (element['theme'] != null) 'theme: ${_mermaidTheme(element['theme']! as String)}',
      if (element['reveal'] != null) 'reveal: ${_mermaidReveal(_map(element['reveal']))}',
      if (element['fit'] != null) 'fit: ${_enumValue('BoxFit', element['fit']! as String)}',
    ])})';

/// A `MermaidTheme.<preset>()` literal from the named theme string.
String _mermaidTheme(String name) => switch (name) {
  'dark' => 'MermaidTheme.dark()',
  'light' => 'MermaidTheme.light()',
  _ => throw FormatException('Unknown mermaid theme "$name"'),
};

/// A `MermaidReveal` value from the tagged reveal union.
String _mermaidReveal(Map<String, Object?> reveal) => switch (reveal['kind']) {
  'none' => 'MermaidReveal.none',
  'fadeNodes' => 'MermaidReveal.fadeNodes(${_time(reveal['window']! as String)})',
  'drawEdges' => 'MermaidReveal.drawEdges(${_time(reveal['window']! as String)})',
  _ => throw FormatException('Unknown mermaid reveal kind "${reveal['kind']}"'),
};

/// A `WebView.url(...)` constructor with viewport, scroll, clip, and fit.
String _webViewElement(Map<String, Object?> element) =>
    'WebView.url(${_args([
      _str(element['uri']! as String),
      'viewport: ${_viewport(_map(element['viewport']))}',
      if (element['scroll'] != null) 'scroll: ${_point(element['scroll'])}',
      if (element['clip'] != null) 'clip: ${_rectLiteral(element['clip'])}',
      if (element['fit'] != null) 'fit: ${_enumValue('BoxFit', element['fit']! as String)}',
    ])})';

/// An `Html(...)` constructor with its viewport and fit.
String _htmlElement(Map<String, Object?> element) =>
    'Html(${_args([
      _str(element['source']! as String),
      'viewport: ${_viewport(_map(element['viewport']))}',
      if (element['fit'] != null) 'fit: ${_enumValue('BoxFit', element['fit']! as String)}',
    ])})';

/// A `SnapshotViewport(...)` literal from a `{width, height, deviceScale}`
/// object.
String _viewport(Map<String, Object?> viewport) =>
    'SnapshotViewport(${_args([
      'width: ${_num(viewport['width'])}',
      'height: ${_num(viewport['height'])}',
      if (viewport['deviceScale'] != null) 'deviceScale: ${_num(viewport['deviceScale'])}',
    ])})';
