part of 'markdown.dart';

/// Every image `src` the `AstRenderer` actually paints, in reading order.
///
/// It descends the SAME node subset the renderer does — only collecting an
/// image the render would show. A `pre` fenced block, an inline `code` run,
/// and any unknown block (a GFM table, a footnote section, an `hr`) render as
/// text and paint no image, so they are opaque here too; collecting an image
/// the renderer never paints would make the collect pass pre-resolve — and a
/// bad URL would fail — a document that renders fine.
Iterable<String> _imageSources(List<md.Node> nodes) sync* {
  for (final node in nodes) {
    yield* _blockImages(node);
  }
}

/// Images one top-level block [node] paints — mirrors `AstRenderer._block`.
Iterable<String> _blockImages(md.Node node) sync* {
  if (node is! md.Element) return;
  switch (node.tag) {
    case 'h1' || 'h2' || 'h3' || 'h4' || 'h5' || 'h6' || 'p':
      yield* _inlineImages(node.children);
    case 'ul' || 'ol':
      for (final item in (node.children ?? const <md.Node>[]).whereType<md.Element>()) {
        yield* _inlineImages(item.children);
      }
    case 'blockquote':
      for (final child in node.children ?? const <md.Node>[]) {
        if (child is md.Element && child.tag == 'p') {
          yield* _inlineImages(child.children);
        } else {
          yield* _blockImages(child);
        }
      }
    // A `pre` fenced block and every other (fallback) tag paint no image.
  }
}

/// Images in inline [children] — mirrors `AstRenderer._span`: an `img` is
/// collected, `strong`/`em`/links descend, and inline `code` is opaque text.
Iterable<String> _inlineImages(List<md.Node>? children) sync* {
  for (final node in children ?? const <md.Node>[]) {
    if (node is! md.Element) continue;
    switch (node.tag) {
      case 'img':
        yield node.attributes['src'] ?? '';
      case 'code':
        break; // inline code renders as text; no image descent
      default:
        yield* _inlineImages(node.children);
    }
  }
}
