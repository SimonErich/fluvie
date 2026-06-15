import 'package:flutter/widgets.dart';
import 'package:fluvie/src/core/anchor.dart';
import 'package:fluvie/src/core/audio/band_table.dart';

/// Carries the precomputed [BandTable]s down to the reactive effects that read
/// them — the audio-reactive counterpart to the
/// media `ImageResolverScope`.
///
/// The render shell (and a live preview) analyses every reactive audio track
/// once before frame 0 and mounts one of these above the composition: a
/// [table] for the default (untracked) reactivity plus a per-[Anchor] map for
/// `track:`-scoped reactivity. A `ReactiveEffect` reads its band's energy from
/// here per frame — a pure synchronous lookup, never live audio, so the frame
/// stays the only clock.
///
/// In a live preview app there is usually no scope; `ReactiveEffect` then falls
/// back to a neutral (energy 0) state. In capture a missing scope is a
/// determinism violation the effect throws on.
final class ReactiveScope extends InheritedWidget {
  /// Provides the default [table] (and optional per-anchor [tracks]) to every
  /// descendant of [child].
  const ReactiveScope({
    required this.table,
    required super.child,
    this.tracks = const {},
    super.key,
  });

  /// The band table reactive effects with no `track:` anchor read.
  final BandTable table;

  /// Per-track band tables, keyed by the `Audio.track` anchor a reactive effect
  /// names through `track:`.
  final Map<Anchor, BandTable> tracks;

  /// The band table for [anchor] above [context], or `null` when no scope is
  /// present.
  ///
  /// A `null` [anchor] resolves the default [table]; a non-null [anchor]
  /// resolves its per-track table, falling back to the default when the track
  /// has none (so an unanalysed track still reacts to the master mix rather
  /// than reading silence).
  static BandTable? tableFor(BuildContext context, Anchor? anchor) {
    final scope = context.dependOnInheritedWidgetOfExactType<ReactiveScope>();
    if (scope == null) return null;
    if (anchor == null) return scope.table;
    return scope.tracks[anchor] ?? scope.table;
  }

  @override
  bool updateShouldNotify(ReactiveScope oldWidget) =>
      oldWidget.table != table || !_sameTracks(oldWidget.tracks, tracks);

  static bool _sameTracks(Map<Anchor, BandTable> a, Map<Anchor, BandTable> b) {
    if (a.length != b.length) return false;
    for (final entry in a.entries) {
      if (b[entry.key] != entry.value) return false;
    }
    return true;
  }
}
