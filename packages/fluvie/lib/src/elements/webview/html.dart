import 'package:flutter/widgets.dart' show BoxFit, BuildContext, StatelessWidget, Widget;
import 'package:fluvie/src/core/anchor.dart';
import 'package:fluvie/src/core/media/media_carrier.dart';
import 'package:fluvie/src/core/media/media_source.dart';
import 'package:fluvie/src/core/media/snapshot_source.dart';
import 'package:fluvie/src/core/snapshot/snapshot_viewport.dart';
import 'package:fluvie/src/elements/runtime/element_shared.dart';
import 'package:fluvie/src/elements/snapshot/runtime/resolved_snapshot.dart';
import 'package:meta/meta.dart';

/// Inline HTML laid out and captured deterministically to a raster — the markup
/// becomes a still image rasterized once before the frame loop at a fixed
/// [viewport], never a live web view captured mid-frame (the pre-rasterize
/// rule).
///
/// A headless Chromium lays out the [source] document and screenshots it at the
/// declared [viewport] (GPU-disabled, time-boxed), so the same markup and
/// viewport always yield the same raster. Unlike `WebView` the markup is local,
/// so no network is touched and no allowlist is consulted. The renderer
/// pre-resolves every document before capture, caches it by content hash, and
/// paints it synchronously from the enclosing `ImageResolverScope` through
/// [ResolvedSnapshot]. A capture with no pre-resolution throws a
/// `FluvieRenderException`; a live preview shows a placeholder.
///
/// The bundled headless-Chrome renderer is experimental and not wired in this
/// build, so out of the box an `Html` cannot rasterize real markup yet: you
/// inject a `SnapshotService` (the example uses an offline fixture one). See the
/// "diagrams and webviews" guide, "The live renderer is experimental".
///
/// ```dart
/// Html('<h1>Hello</h1>', viewport: SnapshotViewport(width: 800, height: 200))
/// Html(snippet, viewport: SnapshotViewport(width: 600, height: 400), fit: BoxFit.contain)
/// ```
///
/// The [snapshotSource] the collect pass gathers (`collectSnapshotSources`)
/// folds the markup and the [viewport] into its cache key, so a markup or size
/// change is a distinct cache entry while an identical declaration shares one.
/// An optional [shared] anchor wraps the result in a `SharedElement` for a hero
/// morph across a scene boundary. Transforms and effects come through
/// `.animate()` only, like every element.
///
/// The bundled headless-Chrome rasterizer is not wired in this 1.0 build, so
/// `Html` is marked [experimental]: it rasterizes only with an injected
/// `SnapshotService`, and the live transport may change.
@experimental
final class Html extends StatelessWidget implements MediaCarrier {
  /// An inline HTML document from [source] captured at [viewport], scaled by
  /// [fit] (default [BoxFit.cover]).
  const Html(
    this.source, {
    required this.viewport,
    this.fit = BoxFit.cover,
    this.shared,
    super.key,
  });

  /// The inline HTML markup laid out and captured.
  final String source;

  /// The fixed pixel box the document is laid out and captured in.
  final SnapshotViewport viewport;

  /// How the raster scales into its box (default [BoxFit.cover]).
  final BoxFit fit;

  /// An optional hero anchor: when non-null the document morphs across the
  /// boundary it shares with the same anchor in the adjacent scene. `null`
  /// mounts no `SharedElement`.
  final Anchor? shared;

  /// An `Html` declares no loaded media — it is a computed snapshot.
  @override
  MediaSource? get mediaSource => null;

  /// The computed snapshot this document rasterizes, exposed through the
  /// [MediaCarrier] contract so the collect pass reads it without a
  /// `BuildContext`.
  ///
  /// The key folds in the markup and the [viewport], so the same declaration
  /// yields a stable, `BuildContext`-free key.
  @override
  SnapshotSource? get snapshotSource => SnapshotSource.html(source, viewport: viewport);

  @override
  Widget build(BuildContext context) {
    final painted = ResolvedSnapshot(source: snapshotSource!, fit: fit);
    return wrapShared(shared, painted);
  }
}
