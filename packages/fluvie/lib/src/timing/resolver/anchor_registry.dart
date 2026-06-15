import 'package:fluvie/src/core/anchor.dart';
import 'package:fluvie/src/core/errors/fluvie_timing_error.dart';
import 'package:fluvie/src/timing/plan/animation_plan.dart';
import 'package:fluvie/src/timing/plan/composition_plan.dart';
import 'package:fluvie/src/timing/plan/element_plan.dart';
import 'package:meta/meta.dart';

/// One animation located in its [CompositionPlan]: the unit the dependency
/// graph orders and the trigger resolver turns into a frame span.
///
/// [index] is the node's global declaration position — the registry assigns
/// them contiguously while walking scene → element → animation, so the
/// animations of one element always occupy **consecutive** indices (this is
/// what lets `Trigger.previous` mean exactly `index - 1`).
@immutable
final class AnimationNode {
  /// Creates a node; the registry is the only intended caller.
  const AnimationNode({
    required this.index,
    required this.sceneIndex,
    required this.elementIndex,
    required this.animationIndex,
    required this.element,
    required this.plan,
  });

  /// Global declaration position across the whole composition, from `0`.
  final int index;

  /// The position of the owning scene within the composition.
  final int sceneIndex;

  /// The position of the owning element within its scene.
  final int elementIndex;

  /// The position of this animation within its element's `animations` list.
  final int animationIndex;

  /// The element this animation is declared on.
  final ElementPlan element;

  /// The animation declaration itself.
  final AnimationPlan plan;

  @override
  String toString() =>
      'AnimationNode(#$index, scene: $sceneIndex, element: ${element.ownerId}, '
      'animation: $animationIndex)';
}

/// The collect pass of the two-pass trigger resolver: every animation becomes
/// an [AnimationNode] in declaration order, and every attached [Anchor] is
/// indexed so triggers can look up what they reference.
///
/// Anchors are compared by identity — two `Anchor('x')` are distinct handles
/// — and each anchor must be attached to exactly one element, because it
/// names exactly one timeline.
final class AnchorRegistry {
  AnchorRegistry._(this.nodes, this._elementByAnchor, this._nodesByAnchor);

  /// Walks [plan] scene → element → animation and indexes everything.
  ///
  /// Throws a [FluvieTimingError] when one anchor instance is attached to
  /// more than one element — an anchor names a single timeline, so a shared
  /// instance would make every trigger on it ambiguous.
  factory AnchorRegistry.collect(CompositionPlan plan) {
    final nodes = <AnimationNode>[];
    final elementByAnchor = <Anchor, ElementPlan>{};
    final nodesByAnchor = <Anchor, List<AnimationNode>>{};
    var index = 0;
    for (var s = 0; s < plan.scenes.length; s++) {
      final scene = plan.scenes[s];
      for (var e = 0; e < scene.elements.length; e++) {
        final element = scene.elements[e];
        final anchor = element.anchor;
        if (anchor != null) {
          final existing = elementByAnchor[anchor];
          if (existing != null) {
            throw FluvieTimingError(
              "$anchor is attached to both '${existing.ownerId}' and "
              "'${element.ownerId}' — an anchor names exactly one element, "
              'so create a separate Anchor for each.',
              anchors: [anchor],
            );
          }
          elementByAnchor[anchor] = element;
          nodesByAnchor[anchor] = [];
        }
        for (var a = 0; a < element.animations.length; a++) {
          final node = AnimationNode(
            index: index++,
            sceneIndex: s,
            elementIndex: e,
            animationIndex: a,
            element: element,
            plan: element.animations[a],
          );
          nodes.add(node);
          nodesByAnchor[anchor]?.add(node);
        }
      }
    }
    return AnchorRegistry._(
      List.unmodifiable(nodes),
      Map.unmodifiable(elementByAnchor),
      Map.unmodifiable(<Anchor, List<AnimationNode>>{
        for (final entry in nodesByAnchor.entries) entry.key: List.unmodifiable(entry.value),
      }),
    );
  }

  /// Every animation in the composition, in declaration order; the list
  /// position equals [AnimationNode.index].
  final List<AnimationNode> nodes;

  final Map<Anchor, ElementPlan> _elementByAnchor;
  final Map<Anchor, List<AnimationNode>> _nodesByAnchor;

  /// Every attached [Anchor], in declaration order (scene → element) — the
  /// structured "jump to anchor" egress the timeline resolves to frames.
  Iterable<Anchor> get anchors => _elementByAnchor.keys;

  /// Whether [anchor] is attached to an element of the collected plan.
  bool isRegistered(Anchor anchor) => _elementByAnchor.containsKey(anchor);

  /// The nodes of the element [anchor] is attached to, in declaration order —
  /// empty when the anchored element declares no animations (its window then
  /// stands in for its timeline).
  ///
  /// Throws a [FluvieTimingError] naming the anchor when it dangles.
  List<AnimationNode> nodesForAnchor(Anchor anchor) {
    _requireRegistered(anchor);
    return _nodesByAnchor[anchor]!;
  }

  /// The element [anchor] is attached to.
  ///
  /// Throws a [FluvieTimingError] naming the anchor when it dangles.
  ElementPlan elementForAnchor(Anchor anchor) {
    _requireRegistered(anchor);
    return _elementByAnchor[anchor]!;
  }

  void _requireRegistered(Anchor anchor) {
    if (isRegistered(anchor)) return;
    throw FluvieTimingError(
      'A trigger references $anchor, but it is never attached to an element — '
      'pass it as the `anchor:` of the element it should name.',
      anchors: [anchor],
    );
  }
}

/// The shared error for `Trigger.previous` on an element's first animation
/// (thrown at graph build and again defensively at resolve time, so the
/// wording cannot drift between the two sites).
FluvieTimingError firstAnimationPreviousError(AnimationNode node) => FluvieTimingError(
  "Trigger.previous on the first animation of element '${node.element.ownerId}' "
  'has nothing to chain after — give the first animation a different trigger.',
);
