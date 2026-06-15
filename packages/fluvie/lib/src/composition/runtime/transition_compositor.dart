import 'package:flutter/widgets.dart';
import 'package:fluvie/src/composition/transition/runtime/shared_element_overlay.dart';
import 'package:fluvie/src/composition/transition/runtime/shared_element_registry.dart';
import 'package:fluvie/src/composition/transition/runtime/transition_phase_scope.dart';
import 'package:fluvie/src/composition/transition/transition_stage.dart';
import 'package:fluvie/src/composition/transition/transition_strategy.dart';
import 'package:fluvie/src/core/transition.dart';
import 'package:fluvie/src/rendering/runtime/frame_clamp.dart';
import 'package:fluvie/src/rendering/runtime/frame_provider.dart';
import 'package:fluvie/src/timing/placement/scene_offset_resolver.dart';

/// The single frame reader of the composition shell: assigns every scene its
/// [SceneRole] for the current frame and mounts one shared, expanding [Stack]
/// accordingly.
///
/// Hidden scenes sit in an [Offstage] — they still build, so element
/// registrations stay alive — and solo scenes are the same [Offstage] with the
/// flag off. During a blend window the boundary's [TransitionStrategy] composes
/// the outgoing/incoming pair in its own paint order; a non-overlap outgoing is
/// wrapped in a [FrameClamp] first, holding it at its final frame.
///
/// The compositor is stateless and rebuilds whole wrapper chains as roles
/// change, so [sceneShells] that carry state across role changes (element
/// registrations do) must be keyed with a `GlobalKey` by their owner — the
/// `Video` shell does exactly that. The strategy widgets themselves are all
/// stateless render-safe primitives, so re-inflating them is free.
final class TransitionCompositor extends StatelessWidget {
  /// Composes [sceneShells] under the roles [offsets] and [transitions]
  /// imply per frame, with the [sharedElements] hero overlay on top.
  const TransitionCompositor({
    required this.offsets,
    required this.transitions,
    required this.sceneShells,
    this.sharedElements,
    super.key,
  });

  /// The resolved scene boundaries — starts, durations, and blend windows —
  /// from the shared offset math.
  final SceneOffsets offsets;

  /// The boundary transitions the [offsets] were resolved with: one entry
  /// per adjacent scene pair (`null` = cut), or empty for all-cut.
  final List<Transition?> transitions;

  /// One shell per scene, in scene order; must match [offsets]' scene count.
  final List<Widget> sceneShells;

  /// The composition's hero registry, or `null` when no `Video` wired it —
  /// then the overlay never mounts and slots never suppress.
  final SharedElementRegistry? sharedElements;

  @override
  Widget build(BuildContext context) {
    final frame = FrameProvider.of(context).frame;
    final states = stageAt(frame: frame, offsets: offsets, transitions: transitions);
    final phase = _activePhase(states);
    final children = <Widget>[];
    for (var s = 0; s < sceneShells.length; s++) {
      final state = states[s];
      switch (state.role) {
        case SceneRole.hidden || SceneRole.solo:
          // Always mount the phase scope over each shell: a value, never a
          // tree-shape change, so a suppressed hero slot keeps its child
          // across the boundary.
          children.add(
            Offstage(
              offstage: state.role == SceneRole.hidden,
              child: TransitionPhaseScope(phase: phase, child: sceneShells[s]),
            ),
          );
        case SceneRole.outgoing:
          children.addAll(_blend(state, s, phase));
        case SceneRole.incoming:
          break; // Already composed alongside its outgoing partner.
      }
    }
    children.add(
      SharedElementOverlay(
        registry: sharedElements,
        boundary: phase?.boundary,
        progress: phase?.progress ?? 0,
        offsets: offsets,
      ),
    );
    return Stack(
      // Expanding children leave alignment inert; a non-directional value
      // keeps the compositor mountable without a Directionality ancestor.
      alignment: Alignment.topLeft,
      fit: StackFit.expand,
      children: children,
    );
  }

  /// The single active blend window across all scenes: its boundary and eased
  /// progress, or `null` when nothing is blending.
  TransitionPhase? _activePhase(List<SceneFrameState> states) {
    for (final state in states) {
      if (state.role == SceneRole.incoming && state.boundary != null) {
        final spec = transitions[state.boundary!]!;
        return TransitionPhase(
          boundary: state.boundary!,
          progress: spec.ease.transform(state.progress),
        );
      }
    }
    return null;
  }

  /// The blended pair for the boundary [state] reports on scene [s], in the
  /// strategy's paint order. The held outgoing is clamped to its final frame.
  /// Both shells carry the active [phase] so their hero slots can suppress.
  List<Widget> _blend(SceneFrameState state, int s, TransitionPhase? phase) {
    final spec = transitions[state.boundary!]!;
    final hold = state.holdFrame;
    final outgoing = TransitionPhaseScope(
      phase: phase,
      child: hold == null ? sceneShells[s] : FrameClamp(holdFrame: hold, child: sceneShells[s]),
    );
    final incoming = TransitionPhaseScope(phase: phase, child: sceneShells[s + 1]);
    return strategyFor(spec.kind).compose(
      outgoing: outgoing,
      incoming: incoming,
      easedProgress: spec.ease.transform(state.progress),
      spec: spec,
    );
  }
}
