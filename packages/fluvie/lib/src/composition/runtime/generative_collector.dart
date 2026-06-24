import 'package:fluvie/src/composition/runtime/scene_tree_walk.dart';
import 'package:fluvie/src/composition/scene.dart';
import 'package:fluvie/src/core/media/generative_carrier.dart';
import 'package:fluvie/src/core/media/generative_source.dart';

/// Gathers every declared [GenerativeSource] from [scenes] before the frame loop
/// — the generative sibling of `collectMediaSources`, walking the same tree
/// (`walkSceneTree`) with no mounting and no async.
///
/// The generic generative elements expose their source through
/// [GenerativeCarrier]; everything else is transparent. The result is a `Set`,
/// so the same prompt+seed declared across scenes is produced once (the cache
/// deduplicates by value equality / [GenerativeSource.cacheKey]). The render
/// harness hands this set to `GenerativeResolver.generateAll` before media
/// pre-resolution; the produced files then fold back in as plain
/// `MediaSource`/`AudioSource`s.
Set<GenerativeSource> collectGenerativeSources(List<Scene> scenes) {
  final sources = <GenerativeSource>{};
  walkSceneTree(scenes, (widget) {
    if (widget is! GenerativeCarrier) return;
    final source = (widget as GenerativeCarrier).generativeSource;
    if (source != null) sources.add(source);
  });
  return sources;
}
