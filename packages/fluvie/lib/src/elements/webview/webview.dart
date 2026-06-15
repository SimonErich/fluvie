import 'package:flutter/widgets.dart'
    show BoxFit, BuildContext, Offset, Rect, StatelessWidget, Widget;
import 'package:fluvie/src/core/anchor.dart';
import 'package:fluvie/src/core/media/media_carrier.dart';
import 'package:fluvie/src/core/media/media_source.dart';
import 'package:fluvie/src/core/media/snapshot_source.dart';
import 'package:fluvie/src/core/snapshot/snapshot_viewport.dart';
import 'package:fluvie/src/elements/runtime/element_shared.dart';
import 'package:fluvie/src/elements/snapshot/runtime/resolved_snapshot.dart';
import 'package:meta/meta.dart';

/// A live web page captured deterministically to a raster — the page at a URL
/// becomes a still image rasterized once before the frame loop at a fixed
/// [viewport], never a live web view captured mid-frame (the pre-rasterize
/// rule).
///
/// A headless Chromium navigates to the page and screenshots it at the declared
/// [viewport] (network-allowlisted, GPU-disabled, time-boxed), so the same URL,
/// viewport, scroll and clip always yield the same raster. The renderer
/// pre-resolves every page before capture (no "pops in when it loads"), caches
/// it by content hash, and paints it synchronously from the enclosing
/// `ImageResolverScope` through [ResolvedSnapshot]. A capture with no
/// pre-resolution throws a `FluvieRenderException`; a live preview shows a
/// placeholder, never a live web view.
///
/// The page host is checked against the network allowlist before any navigation:
/// the resolution pass calls `NetworkAllowlist.check` for a [WebView] before it
/// asks the snapshot service to capture, so a disallowed host is a typed
/// `FluvieRenderException` and never reaches the browser.
///
/// The bundled headless-Chrome renderer is experimental and not wired in this
/// build, so out of the box a `WebView` cannot capture a real page yet: you
/// inject a `SnapshotService` (the example uses an offline fixture one). See the
/// "diagrams and webviews" guide, "The live renderer is experimental".
///
/// ```dart
/// WebView.url('https://example.com', viewport: SnapshotViewport(width: 1280, height: 720))
/// WebView.url(Uri.parse('https://example.com'),
///   viewport: SnapshotViewport(width: 800, height: 600),
///   scroll: const Offset(0, 240), clip: const Rect.fromLTWH(0, 0, 800, 360))
/// ```
///
/// The [snapshotSource] the collect pass gathers (`collectSnapshotSources`)
/// carries the URL host, the [viewport], the [scroll] offset, and the [clip]
/// size, so any change is a distinct cache entry. An optional [shared] anchor
/// wraps the result in a `SharedElement` for a hero morph across a scene
/// boundary. Transforms and effects come through `.animate()` only, like every
/// element.
///
/// The bundled headless-Chrome capture is not wired in this 1.0 build, so
/// `WebView` is marked [experimental]: it captures only with an injected
/// `SnapshotService`, and the live transport may change.
@experimental
final class WebView extends StatelessWidget implements MediaCarrier {
  /// A page at [uri] (a `Uri` or a parseable `String`) captured at [viewport],
  /// optionally pre-[scroll]ed and [clip]ped, scaled by [fit] (default
  /// [BoxFit.cover]).
  ///
  /// [uri] is normalized to a `Uri` at construction; a non-`Uri`/non-`String`
  /// value or an unparseable string is an [ArgumentError]. Only allowlisted
  /// hosts and schemes are navigated to in capture.
  WebView.url(
    Object uri, {
    required this.viewport,
    this.scroll,
    this.clip,
    this.fit = BoxFit.cover,
    this.shared,
    super.key,
  }) : uri = _normalize(uri);

  /// The normalized page URL, navigated to and captured by the snapshot service.
  final Uri uri;

  /// The fixed pixel box the page is laid out and captured in.
  final SnapshotViewport viewport;

  /// The scroll offset applied before capture, or `null` for the page top.
  final Offset? scroll;

  /// The capture region within the viewport, or `null` for the whole viewport.
  final Rect? clip;

  /// How the raster scales into its box (default [BoxFit.cover]).
  final BoxFit fit;

  /// An optional hero anchor: when non-null the page morphs across the boundary
  /// it shares with the same anchor in the adjacent scene. `null` mounts no
  /// `SharedElement`.
  final Anchor? shared;

  /// A `WebView` declares no loaded media — it is a computed snapshot.
  @override
  MediaSource? get mediaSource => null;

  /// The computed snapshot this page rasterizes, exposed through the
  /// [MediaCarrier] contract so the collect pass reads it without a
  /// `BuildContext`.
  ///
  /// The key carries the URL host, the [viewport], the [scroll] offset, and the
  /// [clip] size, so a scroll or clip change is a distinct cache entry while an
  /// identical declaration shares one.
  @override
  SnapshotSource? get snapshotSource => SnapshotSource.url(
    uri,
    viewport: viewport,
    scrollX: scroll?.dx.round() ?? 0,
    scrollY: scroll?.dy.round() ?? 0,
    clipWidth: clip?.width.round(),
    clipHeight: clip?.height.round(),
  );

  /// Normalizes [uri] to a `Uri`: returned as-is when already a `Uri`, parsed
  /// when a `String`, otherwise an [ArgumentError]. An unparseable string is
  /// also an [ArgumentError].
  static Uri _normalize(Object uri) {
    if (uri is Uri) {
      return uri;
    }
    if (uri is String) {
      final parsed = Uri.tryParse(uri);
      if (parsed == null) {
        throw ArgumentError.value(uri, 'uri', 'WebView.url could not parse the URL');
      }
      return parsed;
    }
    throw ArgumentError.value(uri, 'uri', 'WebView.url expects a Uri or a String');
  }

  @override
  Widget build(BuildContext context) {
    final painted = ResolvedSnapshot(source: snapshotSource!, fit: fit);
    return wrapShared(shared, painted);
  }
}
