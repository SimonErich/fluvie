import 'package:fluvie/src/core/snapshot/snapshot_viewport.dart';
import 'package:meta/meta.dart';

/// One thing a `SnapshotService` is asked to rasterize, identified before it is
/// resolved.
///
/// The three variants cover the three snapshot origins: a [SnapshotRequest.mermaid]
/// diagram source, an inline [SnapshotRequest.html] document, and a remote
/// [SnapshotRequest.url] page. They are value-equal so the snapshot cache
/// deduplicates identical declarations, and they carry only Dart-core types, so
/// they satisfy the layering law and live in `core`.
///
/// `SnapshotService`, `Mermaid`, `WebView` and `Html` are named in prose, not as
/// doc links, because they live in layers above `core`.
@immutable
sealed class SnapshotRequest {
  const SnapshotRequest();

  /// A Mermaid diagram [source] rendered with the theme identified by
  /// [themeKey] (a canonical string the widget derives from its theme, `null`
  /// for the default theme). The key participates in equality so a theme change
  /// produces a distinct request.
  const factory SnapshotRequest.mermaid(String source, {String? themeKey}) = MermaidRequest;

  /// An inline HTML [source] laid out and captured at [viewport].
  const factory SnapshotRequest.html(String source, {required SnapshotViewport viewport}) =
      HtmlRequest;

  /// A remote page at [uri] laid out at [viewport], optionally scrolled by
  /// ([scrollX], [scrollY]) and clipped to ([clipWidth], [clipHeight]).
  const factory SnapshotRequest.url(
    Uri uri, {
    required SnapshotViewport viewport,
    int scrollX,
    int scrollY,
    int? clipWidth,
    int? clipHeight,
  }) = UrlRequest;
}

/// A [SnapshotRequest] for a Mermaid diagram source.
final class MermaidRequest extends SnapshotRequest {
  /// Creates a Mermaid request over [source] with the optional [themeKey].
  const MermaidRequest(this.source, {this.themeKey});

  /// The Mermaid diagram source text.
  final String source;

  /// The canonical theme key, or `null` for the default theme.
  final String? themeKey;

  @override
  bool operator ==(Object other) =>
      other is MermaidRequest && other.source == source && other.themeKey == themeKey;

  @override
  int get hashCode => Object.hash(MermaidRequest, source, themeKey);

  @override
  String toString() => 'SnapshotRequest.mermaid(${source.length} chars, theme: $themeKey)';
}

/// A [SnapshotRequest] for an inline HTML document.
final class HtmlRequest extends SnapshotRequest {
  /// Creates an HTML request over [source] captured at [viewport].
  const HtmlRequest(this.source, {required this.viewport});

  /// The inline HTML source text.
  final String source;

  /// The viewport the document is laid out and captured in.
  final SnapshotViewport viewport;

  @override
  bool operator ==(Object other) =>
      other is HtmlRequest && other.source == source && other.viewport == viewport;

  @override
  int get hashCode => Object.hash(HtmlRequest, source, viewport);

  @override
  String toString() => 'SnapshotRequest.html(${source.length} chars, $viewport)';
}

/// A [SnapshotRequest] for a remote page URL.
final class UrlRequest extends SnapshotRequest {
  /// Creates a URL request for [uri] at [viewport], optionally scrolled and
  /// clipped.
  const UrlRequest(
    this.uri, {
    required this.viewport,
    this.scrollX = 0,
    this.scrollY = 0,
    this.clipWidth,
    this.clipHeight,
  });

  /// The page URL to navigate to and capture.
  final Uri uri;

  /// The viewport the page is laid out and captured in.
  final SnapshotViewport viewport;

  /// The horizontal scroll offset applied before capture.
  final int scrollX;

  /// The vertical scroll offset applied before capture.
  final int scrollY;

  /// The capture clip width, or `null` to capture the whole viewport.
  final int? clipWidth;

  /// The capture clip height, or `null` to capture the whole viewport.
  final int? clipHeight;

  @override
  bool operator ==(Object other) =>
      other is UrlRequest &&
      other.uri == uri &&
      other.viewport == viewport &&
      other.scrollX == scrollX &&
      other.scrollY == scrollY &&
      other.clipWidth == clipWidth &&
      other.clipHeight == clipHeight;

  @override
  int get hashCode =>
      Object.hash(UrlRequest, uri, viewport, scrollX, scrollY, clipWidth, clipHeight);

  @override
  String toString() => 'SnapshotRequest.url($uri, $viewport)';
}
