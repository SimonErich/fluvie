part of 'element_builder.dart';

// The diagram and web-surface builders (all three widgets are experimental:
// they rasterize through an injected SnapshotService). Defaults mirror the
// widgets: Mermaid fits `contain`, the web surfaces fit `cover`.

/// A `Mermaid` from its spec props: the diagram source, a named theme, the
/// reveal union, and the raster fit.
Widget _mermaidElement(Map<String, Object?> props) => Mermaid(
  _string(props['source'], 'source'),
  theme: _mermaidTheme(props['theme']),
  reveal: _mermaidReveal(props['reveal']),
  fit: _fitOrNull(props['fit']) ?? BoxFit.contain,
);

/// The named Mermaid themes the spec accepts, mirroring the theme presets.
MermaidTheme? _mermaidTheme(Object? raw) => switch (raw) {
  null => null,
  'dark' => const MermaidTheme.dark(),
  'light' => const MermaidTheme.light(),
  _ => throw FluvieSpecError(
    'Unknown mermaid theme "$raw"; expected "dark" or "light"',
    path: const ['theme'],
  ),
};

/// The tagged reveal union: `{"kind": "fadeNodes", "window": ...}`,
/// `{"kind": "drawEdges", "window": ...}`, or `{"kind": "none"}`.
MermaidReveal _mermaidReveal(Object? raw) {
  if (raw == null) return MermaidReveal.none;
  if (raw is Map<String, Object?>) {
    switch (raw['kind']) {
      case 'none':
        return MermaidReveal.none;
      case 'fadeNodes':
        return MermaidReveal.fadeNodes(decodeTime(raw['window'], path: const ['reveal', 'window']));
      case 'drawEdges':
        return MermaidReveal.drawEdges(decodeTime(raw['window'], path: const ['reveal', 'window']));
    }
  }
  throw FluvieSpecError(
    'Expected a reveal of kind "none", "fadeNodes", or "drawEdges" (with a "window")',
    path: const ['reveal'],
  );
}

/// A `WebView` from its spec props: a validated absolute http(s) URL, the
/// required capture viewport, and the optional scroll/clip/fit.
Widget _webViewElement(Map<String, Object?> props) => WebView.url(
  _webUri(props['uri']),
  viewport: _viewport(props['viewport']),
  scroll: props['scroll'] == null ? null : decodeOffset(props['scroll'], path: const ['scroll']),
  clip: props['clip'] == null ? null : decodeRect(props['clip'], path: const ['clip']),
  fit: _fitOrNull(props['fit']) ?? BoxFit.cover,
);

/// An `Html` from its spec props: the inline markup and its capture viewport.
Widget _htmlElement(Map<String, Object?> props) => Html(
  _string(props['source'], 'source'),
  viewport: _viewport(props['viewport']),
  fit: _fitOrNull(props['fit']) ?? BoxFit.cover,
);

/// The page URL: it must parse as an absolute `http`/`https` URL, so a typo
/// fails at spec time instead of at the allowlist check mid-resolve.
Uri _webUri(Object? raw) {
  final text = _string(raw, 'uri');
  final uri = Uri.tryParse(text);
  if (uri == null || !uri.isAbsolute || (uri.scheme != 'http' && uri.scheme != 'https')) {
    throw FluvieSpecError(
      'A WebView "uri" must be an absolute http(s) URL, got "$text"',
      path: const ['uri'],
    );
  }
  return uri;
}

/// The `{width, height, deviceScale?}` capture viewport; the sides are logical
/// pixels and must be positive integers.
SnapshotViewport _viewport(Object? raw) {
  if (raw is! Map<String, Object?>) {
    throw FluvieSpecError(
      'Expected a "viewport" object {width, height, deviceScale}',
      path: const ['viewport'],
    );
  }
  final width = raw['width'];
  final height = raw['height'];
  if (width is! int || width < 1 || height is! int || height < 1) {
    throw FluvieSpecError(
      'A viewport needs positive integer "width" and "height"',
      path: const ['viewport'],
    );
  }
  final deviceScale = raw['deviceScale'];
  if (deviceScale != null && (deviceScale is! num || deviceScale <= 0)) {
    throw FluvieSpecError(
      'A viewport "deviceScale" is a positive number',
      path: const ['viewport', 'deviceScale'],
    );
  }
  return SnapshotViewport(
    width: width,
    height: height,
    deviceScale: deviceScale is num ? deviceScale.toDouble() : 1.0,
  );
}
