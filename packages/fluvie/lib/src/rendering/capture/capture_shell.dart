import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:fluvie/src/animation/runtime/color_lookup_scope.dart';
import 'package:fluvie/src/animation/runtime/reactive_scope_builder.dart';
import 'package:fluvie/src/animation/runtime/warm_shader_scope.dart';
import 'package:fluvie/src/composition/runtime/reactive_collector.dart';
import 'package:fluvie/src/core/anchor.dart';
import 'package:fluvie/src/core/audio/audio_source.dart';
import 'package:fluvie/src/core/contracts/audio_window_resolver.dart';
import 'package:fluvie/src/core/contracts/beat_grid.dart';
import 'package:fluvie/src/core/contracts/generative_resolver.dart';
import 'package:fluvie/src/core/contracts/media_resolver.dart';
import 'package:fluvie/src/elements/snapshot/runtime/snapshot_capture_scope.dart';
import 'package:fluvie/src/media/runtime/generative_resolver_scope.dart';
import 'package:fluvie/src/media/runtime/image_resolver_scope.dart';
import 'package:fluvie/src/rendering/capture/beat_grid_scope.dart';
import 'package:fluvie/src/rendering/runtime/render_controller.dart';
import 'package:fluvie/src/rendering/runtime/render_controller_scope.dart';
import 'package:fluvie/src/rendering/runtime/render_mode.dart';
import 'package:fluvie/src/rendering/runtime/render_mode_context.dart';

/// The reactive tracks a capture mounts no scope for — the neutral default for a
/// silent composition.
const ReactiveTracks noReactiveTracks = ReactiveTracks(
  byAnchor: {},
  defaultSource: null,
  allSources: {},
);

/// What `buildCaptureShell` returns: the `tree` to pump and the
/// `mountedSnapshotScope` the shell actually mounted (`null` when the
/// composition declares no snapshots).
///
/// The mounted scope is a fresh [SnapshotCaptureScope] instance — its order
/// cursor is distinct from the pre-pass result the caller passed in — so a host
/// that re-pumps one persistent tree per frame resets the mounted scope's cursor
/// before each pump (see the [SnapshotCaptureScope] dartdoc); a host that
/// rebuilds the shell per frame needs no reset.
typedef CaptureShell = ({Widget tree, SnapshotCaptureScope? mountedSnapshotScope});

/// Builds the production capture scope chain around [composition] — the ONE
/// capture path the example (offline fakes) and the CLI (real ffmpeg) share, so
/// neither `flutter_test` nor ffmpeg leaks into it.
///
/// The shell is parameterized by the injected pre-pass results: the media
/// [resolver] (pre-resolved before frame 0), the [snapshotScope] the snapshot
/// pre-pass rasterized, the [shaderPrograms] the shader pre-pass compiled, and
/// the [reactiveTracks] the reactive pre-pass analysed. It mounts each
/// conditional scope only when it has something to carry, in this exact depth
/// order:
///
/// ```text
/// RenderModeContext(capture)
///   > [SnapshotCaptureScope     when snapshotScope != null]
///     > RenderControllerScope
///       > [GenerativeResolverScope when generativeResolver != null]
///         > [ImageResolverScope  when resolver != null]
///           > [WarmShaderScope   when shaderPrograms is not empty]
///             > RepaintBoundary(boundaryKey)
///               > [ReactiveScope   when reactiveTracks has a default source]
///                 > [BeatGridScope when the resolver has any beat grid]
///                   > composition
/// ```
///
/// The `RenderModeContext` is outermost (mounted in `RenderMode.capture`) so the
/// whole subtree branches to frame-driven behavior; the `RepaintBoundary` is the
/// capture target the frame loop reads back at the render resolution. The
/// `ReactiveScope` and `BeatGridScope` sit just above the composition so the band
/// tables and beat grids reach the reactive effects and `Trigger.beat`
/// resolution. The [controller] drives the frame clock; the host pumps it.
///
/// Pure widget construction, no async, no wall-clock, so the same composition
/// produces the same chain.
CaptureShell buildCaptureShell({
  required Widget composition,
  required GlobalKey boundaryKey,
  required RenderController controller,
  MediaResolver? resolver,
  GenerativeResolver? generativeResolver,
  SnapshotCaptureScope? snapshotScope,
  ReactiveTracks reactiveTracks = noReactiveTracks,
  Map<String, ui.FragmentProgram> shaderPrograms = const {},
  Map<String, ui.Image> colorLookups = const {},
}) {
  // Innermost out: the composition wrapped in the per-frame audio scopes.
  var inner = composition;
  if (resolver != null) {
    inner = beatGridScopeFor(reactiveTracks, resolver, inner);
    inner = reactiveScopeFor(reactiveTracks, resolver, inner);
  }
  Widget tree = RepaintBoundary(key: boundaryKey, child: inner);
  // Above the boundary so a re-pumped tree keeps one warm set, and below the
  // media scopes so the pre-pass results read in one consistent order.
  if (shaderPrograms.isNotEmpty) {
    tree = WarmShaderScope(programs: shaderPrograms, child: tree);
  }
  if (colorLookups.isNotEmpty) {
    tree = ColorLookupScope(lookups: colorLookups, child: tree);
  }
  if (resolver != null) {
    tree = ImageResolverScope(resolver: resolver, child: tree);
  }
  // The generic generative elements map their produced source through this
  // scope; mounted whenever a generative resolver is wired (a no-op for a
  // composition that declares no generated media).
  if (generativeResolver != null) {
    tree = GenerativeResolverScope(resolver: generativeResolver, child: tree);
  }
  tree = RenderControllerScope(controller: controller, child: tree);
  // The mounted snapshot scope is a fresh instance (a fresh order cursor): the
  // caller resets it per frame when it re-pumps one persistent tree.
  final mounted = snapshotScope?.copyWithChild(tree);
  if (mounted != null) tree = mounted;
  return (
    tree: RenderModeContext(mode: RenderMode.capture, child: tree),
    mountedSnapshotScope: mounted,
  );
}

/// Wraps [child] in a [BeatGridScope] carrying the analysed beat grids for
/// [tracks] read from [resolver], or returns [child] unchanged when no track has
/// a grid (so `Trigger.beat` still throws the honest "no grid" error).
///
/// The default grid is the master track's; each `Audio.track` anchor maps to its
/// own grid. A track whose analysis carried no beats (or a resolver that throws)
/// is skipped, so a non-beat reactive track never mounts an empty scope.
Widget beatGridScopeFor(ReactiveTracks tracks, MediaResolver resolver, Widget child) {
  if (resolver is AudioWindowResolver && tracks.windows.isNotEmpty) {
    return BeatGridScope(
      defaultBeatGrid: (resolver as AudioWindowResolver).beatGridForWindow(tracks.windows.first),
      trackBeatGrids: {
        for (final entry in tracks.windowsByAnchor.entries)
          entry.key: (resolver as AudioWindowResolver).beatGridForWindow(entry.value),
      },
      child: child,
    );
  }
  final defaultSource = tracks.defaultSource;
  final defaultGrid = defaultSource == null ? null : _gridOrNull(resolver, defaultSource);
  final trackGrids = <Anchor, BeatGrid>{};
  for (final entry in tracks.byAnchor.entries) {
    final grid = _gridOrNull(resolver, entry.value);
    if (grid != null) trackGrids[entry.key] = grid;
  }
  if (defaultGrid == null && trackGrids.isEmpty) return child;
  return BeatGridScope(
    defaultBeatGrid: defaultGrid,
    trackBeatGrids: trackGrids,
    child: child,
  );
}

/// The analysed [BeatGrid] for [source], or `null` when the resolver has none
/// (a reactive track analysed only for its band table carries no grid).
BeatGrid? _gridOrNull(MediaResolver resolver, AudioSource source) {
  try {
    return resolver.beatGridFor(source);
  } on Object {
    return null;
  }
}
