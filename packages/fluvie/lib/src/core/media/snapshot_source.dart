import 'dart:convert';

import 'package:fluvie/src/core/hash/fnv1a.dart';
import 'package:fluvie/src/core/snapshot/snapshot_request.dart';
import 'package:fluvie/src/core/snapshot/snapshot_viewport.dart';
import 'package:meta/meta.dart';

/// One declared snapshot the collect pass must pre-resolve.
///
/// A `SnapshotSource` is kept deliberately separate from `MediaSource`: a
/// snapshot is *computed* (rasterized by a `SnapshotService`), not *loaded*, and
/// widening `MediaSource` would break every existing switch over it. The collect
/// pass gathers it from `Mermaid`/`WebView`/`Html` (which expose it through
/// `MediaCarrier`), the `MediaResolver` rasterizes and decodes it before frame 0,
/// and paint reads the cached `ui.Image` back by it.
///
/// Each variant wraps the [request] handed to the `SnapshotService` and exposes
/// a stable [cacheKey] — the FNV-1a-64 hash of a canonical string that
/// distinguishes every variant and its discriminating fields (theme, viewport,
/// scroll, clip), so a theme or viewport change is a distinct cache entry while
/// an identical declaration shares one. It carries only Dart-core types, so it
/// satisfies the layering law and lives in `core`.
///
/// `MediaResolver`, `SnapshotService`, `Mermaid`, `WebView` and `Html` are named
/// in prose, not as doc links, because they live in layers above `core`.
@immutable
sealed class SnapshotSource {
  const SnapshotSource();

  /// A Mermaid diagram [source] under the theme identified by [themeKey].
  const factory SnapshotSource.mermaid(String source, {String? themeKey}) = MermaidSnapshotSource;

  /// An inline HTML [source] captured at [viewport].
  const factory SnapshotSource.html(String source, {required SnapshotViewport viewport}) =
      HtmlSnapshotSource;

  /// A remote page at [uri] captured at [viewport], optionally scrolled and
  /// clipped.
  const factory SnapshotSource.url(
    Uri uri, {
    required SnapshotViewport viewport,
    int scrollX,
    int scrollY,
    int? clipWidth,
    int? clipHeight,
  }) = UrlSnapshotSource;

  /// The request this source hands to the `SnapshotService`.
  SnapshotRequest get request;

  /// The canonical string that fully identifies this source's pixels — hashed
  /// into [cacheKey]. Distinct for every field that changes the raster.
  String get _canonical;

  /// The path-safe content-hash key for the snapshot cache.
  String get cacheKey => fnv1a64Hex(utf8.encode(_canonical));
}

/// A [SnapshotSource] for a Mermaid diagram.
final class MermaidSnapshotSource extends SnapshotSource {
  /// Creates a Mermaid source over [source] with the optional [themeKey].
  const MermaidSnapshotSource(this.source, {this.themeKey});

  /// The Mermaid diagram source text.
  final String source;

  /// The canonical theme key, or `null` for the default theme.
  final String? themeKey;

  @override
  SnapshotRequest get request => SnapshotRequest.mermaid(source, themeKey: themeKey);

  @override
  String get _canonical => 'mermaid|theme=$themeKey|$source';

  @override
  bool operator ==(Object other) =>
      other is MermaidSnapshotSource && other.source == source && other.themeKey == themeKey;

  @override
  int get hashCode => Object.hash(MermaidSnapshotSource, source, themeKey);

  @override
  String toString() => 'SnapshotSource.mermaid(${source.length} chars, theme: $themeKey)';
}

/// A [SnapshotSource] for an inline HTML document.
final class HtmlSnapshotSource extends SnapshotSource {
  /// Creates an HTML source over [source] captured at [viewport].
  const HtmlSnapshotSource(this.source, {required this.viewport});

  /// The inline HTML source text.
  final String source;

  /// The viewport the document is laid out and captured in.
  final SnapshotViewport viewport;

  @override
  SnapshotRequest get request => SnapshotRequest.html(source, viewport: viewport);

  @override
  String get _canonical =>
      'html|${viewport.width}x${viewport.height}@${viewport.deviceScale}|$source';

  @override
  bool operator ==(Object other) =>
      other is HtmlSnapshotSource && other.source == source && other.viewport == viewport;

  @override
  int get hashCode => Object.hash(HtmlSnapshotSource, source, viewport);

  @override
  String toString() => 'SnapshotSource.html(${source.length} chars, $viewport)';
}

/// A [SnapshotSource] for a remote page URL.
final class UrlSnapshotSource extends SnapshotSource {
  /// Creates a URL source for [uri] at [viewport], optionally scrolled and
  /// clipped.
  const UrlSnapshotSource(
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

  /// The capture clip width, or `null` for the whole viewport.
  final int? clipWidth;

  /// The capture clip height, or `null` for the whole viewport.
  final int? clipHeight;

  /// The URL host, checked against the network allowlist before navigation.
  String get host => uri.host;

  @override
  SnapshotRequest get request => SnapshotRequest.url(
    uri,
    viewport: viewport,
    scrollX: scrollX,
    scrollY: scrollY,
    clipWidth: clipWidth,
    clipHeight: clipHeight,
  );

  @override
  String get _canonical =>
      'url|$uri|${viewport.width}x${viewport.height}@${viewport.deviceScale}'
      '|scroll=$scrollX,$scrollY|clip=$clipWidth,$clipHeight';

  @override
  bool operator ==(Object other) =>
      other is UrlSnapshotSource &&
      other.uri == uri &&
      other.viewport == viewport &&
      other.scrollX == scrollX &&
      other.scrollY == scrollY &&
      other.clipWidth == clipWidth &&
      other.clipHeight == clipHeight;

  @override
  int get hashCode =>
      Object.hash(UrlSnapshotSource, uri, viewport, scrollX, scrollY, clipWidth, clipHeight);

  @override
  String toString() => 'SnapshotSource.url($uri, $viewport)';
}
