import 'package:flutter/widgets.dart' show BoxFit, BuildContext, StatelessWidget, Widget;
import 'package:fluvie/src/core/anchor.dart';
import 'package:fluvie/src/core/media/media_carrier.dart';
import 'package:fluvie/src/core/media/media_source.dart';
import 'package:fluvie/src/core/media/snapshot_source.dart';
import 'package:fluvie/src/elements/mermaid/mermaid_reveal.dart';
import 'package:fluvie/src/elements/mermaid/mermaid_theme.dart';
import 'package:fluvie/src/elements/runtime/element_shared.dart';
import 'package:fluvie/src/elements/snapshot/runtime/resolved_snapshot.dart';
import 'package:fluvie/src/rendering/runtime/frame_provider.dart';
import 'package:fluvie/src/timing/time_scope_provider.dart';
import 'package:meta/meta.dart';

/// A Mermaid diagram rendered deterministically to a raster — the diagram
/// source becomes a still image computed once before the frame loop, never a
/// live view captured mid-frame (the pre-rasterize rule).
///
/// A headless Chromium lays the diagram out into an SVG string and Fluvie
/// rasterizes that SVG in-process, so the same [source] and [theme] always
/// render the same raster. The renderer pre-resolves every diagram before
/// capture (no "pops in when it loads"), caches it by content hash, and paints
/// it synchronously from the enclosing `ImageResolverScope` through
/// [ResolvedSnapshot]. A capture with no pre-resolution throws a
/// `FluvieRenderException`; a live preview shows a placeholder, never a live
/// platform view.
///
/// The bundled headless-Chrome renderer is experimental and not wired in this
/// build, so out of the box a `Mermaid` cannot rasterize real content yet: you
/// inject a `SnapshotService` (the example uses an offline fixture one). See the
/// "diagrams and webviews" guide, "The live renderer is experimental".
///
/// ```dart
/// const Mermaid('graph TD; A-->B; B-->C;')
/// Mermaid(flow, theme: MermaidTheme.light(), reveal: MermaidReveal.fadeNodes(1.seconds))
/// ```
///
/// The [snapshotSource] the collect pass gathers (`collectSnapshotSources`)
/// folds the *effective* theme into its cache key: an explicit [theme]
/// contributes its `MermaidTheme.cacheKey`; with no explicit theme the key is
/// `null` (the default theme), so the same declaration yields a stable,
/// `BuildContext`-free key. An optional [reveal] drives a per-frame opacity over
/// that single raster; an optional [shared] anchor wraps the result in a
/// `SharedElement` for a hero morph across a scene boundary. Transforms and
/// effects come through `.animate()` only, like every element.
///
/// The bundled headless-Chrome rasterizer is not wired in this 1.0 build, so
/// `Mermaid` is marked [experimental]: it renders only with an injected
/// `SnapshotService`, and the live transport may change.
///
/// Two durations can meet here: [reveal] times the intrinsic diagram
/// reveal, while transforms and opacity ride `.animate()` with their own
/// timing.
@experimental
final class Mermaid extends StatelessWidget implements MediaCarrier {
  /// A diagram from Mermaid [source], optionally [theme]d, revealed by [reveal]
  /// (default [MermaidReveal.none]) and scaled by [fit] (default
  /// [BoxFit.contain]).
  const Mermaid(
    this.source, {
    this.theme,
    this.reveal = MermaidReveal.none,
    this.fit = BoxFit.contain,
    this.shared,
    super.key,
  });

  /// The Mermaid diagram source text (for example `'graph TD; A-->B;'`).
  final String source;

  /// An explicit theme override, or `null` to render with Mermaid's default
  /// theme. An explicit theme wins over `context.fluvie.mermaid` and folds into
  /// the snapshot cache key.
  final MermaidTheme? theme;

  /// How the diagram reveals over its window (default [MermaidReveal.none]).
  final MermaidReveal reveal;

  /// How the raster scales into its box (default [BoxFit.contain]).
  final BoxFit fit;

  /// An optional hero anchor: when non-null the diagram morphs across the
  /// boundary it shares with the same anchor in the adjacent scene. `null`
  /// mounts no `SharedElement`.
  final Anchor? shared;

  /// A `Mermaid` declares no loaded media — it is a computed snapshot.
  @override
  MediaSource? get mediaSource => null;

  /// The computed snapshot this diagram rasterizes, exposed through the
  /// [MediaCarrier] contract so the collect pass reads it without a
  /// `BuildContext`.
  ///
  /// The key folds in the effective theme: an explicit [theme]'s
  /// `MermaidTheme.cacheKey`, or `null` for the default theme. Reading the
  /// ambient `context.fluvie.mermaid` here would make the key context-dependent
  /// and break the static collect walk, so the default theme is the sentinel.
  @override
  SnapshotSource? get snapshotSource => SnapshotSource.mermaid(source, themeKey: theme?.cacheKey);

  @override
  Widget build(BuildContext context) {
    final frame = FrameProvider.of(context).frame;
    final scope = TimeScopeProvider.of(context);
    final opacity = mermaidRevealOpacity(reveal, frame, scope);
    final painted = ResolvedSnapshot(source: snapshotSource!, fit: fit, opacity: opacity);
    return wrapShared(shared, painted);
  }
}
