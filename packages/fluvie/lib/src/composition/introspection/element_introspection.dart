import 'package:flutter/widgets.dart' show Key;
import 'package:fluvie/src/composition/introspection/animation_introspection.dart';
import 'package:fluvie/src/composition/introspection/frame_span.dart';
import 'package:fluvie/src/core/anchor.dart';
import 'package:fluvie/src/core/animation_phase.dart';
import 'package:fluvie/src/timing/resolver/anchor_registry.dart' show overlaySceneIndex;
import 'package:meta/meta.dart';

/// One animated element on the resolved timeline: where it lives, when it is
/// alive, and the absolute spans of its animations.
///
/// The stable identities, strongest first: [anchor] (compared by instance,
/// like every anchor), [key] (the widget key of the `.animate()` wrapper or
/// its child), [elementId] (the spec element's document id, for spec-built
/// decks), and [ownerId] (the scene-scoped ordinal fluvie's timeline rows
/// use). Consumers that walked the composition themselves can also look an
/// element up by widget instance through `TimelineIntrospection.elementFor`.
@immutable
final class ElementIntrospection {
  /// Creates the introspection of one element.
  const ElementIntrospection({
    required this.sceneIndex,
    required this.ownerId,
    required this.window,
    required this.animations,
    this.anchor,
    this.key,
    this.elementId,
  });

  /// The index of the scene the element is declared in, or
  /// [overlaySceneIndex] for an overlay, which is declared in none.
  final int sceneIndex;

  /// Whether this element belongs to no scene and runs the whole video.
  bool get isOverlay => sceneIndex == overlaySceneIndex;

  /// The scene-scoped ordinal identifier timeline rows carry
  /// (`s<scene>e<ordinal>:<owner>`).
  final String ownerId;

  /// The element's alive-window in absolute video frames.
  final FrameSpan window;

  /// One introspection per declared animation, in declaration order.
  final List<AnimationIntrospection> animations;

  /// The anchor other elements' triggers reference, or `null` when the
  /// element declares none. Compared by identity.
  final Anchor? anchor;

  /// The widget key of the element (the `.animate()` wrapper's key, or its
  /// child's), or `null` when neither is keyed.
  final Key? key;

  /// The spec element's document id, read from the `SpecElementId` marker
  /// directly wrapping the element's `.animate()` wrapper, or `null` for a
  /// widget-authored element without a marker.
  final String? elementId;

  /// The combined entrance: from the first enter animation's start to the
  /// last enter animation's end, or `null` when the element has no entrance.
  ///
  /// This is the span a consumer plays to bring the element in exactly as
  /// authored.
  FrameSpan? get enterSpan {
    FrameSpan? combined;
    for (final animation in animations) {
      if (animation.phase != AnimationPhase.enter) continue;
      final span = animation.span;
      combined = combined == null
          ? span
          : FrameSpan(
              combined.start < span.start ? combined.start : span.start,
              combined.end > span.end ? combined.end : span.end,
            );
    }
    return combined;
  }

  @override
  String toString() =>
      'ElementIntrospection($ownerId, window: $window, '
      'animations: ${animations.length}, anchor: $anchor, key: $key, '
      'elementId: $elementId)';
}
