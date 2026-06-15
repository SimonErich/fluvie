import 'package:flutter/widgets.dart';
import 'package:fluvie/src/composition/transition/runtime/morph_layer.dart';
import 'package:fluvie/src/composition/transition/runtime/shared_element_registry.dart';
import 'package:fluvie/src/core/time.dart';
import 'package:fluvie/src/timing/placement/scene_offset_resolver.dart';
import 'package:fluvie/src/timing/scene_scope.dart';

/// The compositor's last [Stack] child: the hero morph layer,
/// painted **above** both blend layers so a shared element never rides the
/// scene crossfade.
///
/// During an active boundary window it mounts one [MorphLayer] per complete
/// pair, each under the *incoming* scene's [SceneScope] math but under **no**
/// `CompositionRegistrarScope` — so a `MotionTarget` inside the cloned child
/// takes the documented standalone path instead of registering a late token.
/// Outside any window it is a [SizedBox.shrink], so the overlay
/// changing shape never touches a scene subtree.
final class SharedElementOverlay extends StatelessWidget {
  /// Builds the overlay for the active [boundary] at [progress], reading pairs
  /// from [registry] and the incoming scene scope from [offsets]. A `null`
  /// [boundary] (or [registry], or no pair) yields an empty overlay.
  const SharedElementOverlay({
    required this.registry,
    required this.boundary,
    required this.progress,
    this.offsets,
    super.key,
  });

  /// The composition's hero registry, or `null` when none is wired.
  final SharedElementRegistry? registry;

  /// The active boundary index, or `null` outside a blend window.
  final int? boundary;

  /// The eased blend progress in `[0, 1]`.
  final double progress;

  /// The resolved scene offsets, used to scope the morph clone to the incoming
  /// scene; `null` falls back to a zero-based unit scope (test rigs).
  final SceneOffsets? offsets;

  @override
  Widget build(BuildContext context) {
    final activeBoundary = boundary;
    final reg = registry;
    if (activeBoundary == null || reg == null) return const SizedBox.shrink();
    final pair = reg.pairAtBoundary(activeBoundary);
    if (pair == null) return const SizedBox.shrink();

    final incoming = activeBoundary + 1;
    final start = offsets?.startFrames[incoming] ?? 0;
    final duration = offsets?.durationFrames[incoming] ?? 1;
    return SceneScope(
      start: Time.frames(start),
      duration: Time.frames(duration),
      // No CompositionRegistrarScope here: the clone resolves standalone, so
      // its animations must be self-contained.
      child: MorphLayer(pair: pair, progress: progress, child: pair.target.child),
    );
  }
}
