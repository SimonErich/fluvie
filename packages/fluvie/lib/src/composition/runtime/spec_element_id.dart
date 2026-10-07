import 'package:flutter/widgets.dart' show BuildContext, StatelessWidget, Widget;
import 'package:fluvie/src/composition/runtime/collectible_children.dart';

/// Marks [child] as the widget form of the spec element identified by [id],
/// so timeline introspection can join resolved spans back to document
/// elements without heuristics.
///
/// The spec builder wraps every element that carries an `id` in this marker,
/// directly around the element's `.animate()` wrapper (inside `Placed`, so a
/// placement stays the outermost widget). The id binds to that direct child
/// alone: a marker over a non-animated element binds to nothing, and nested
/// elements never inherit an enclosing element's id. Widget-authored decks
/// may place the marker by hand to opt an element into
/// `TimelineIntrospection.elementById`.
///
/// Render-transparent: it mounts [child] unchanged and shifts no pixel. The
/// structural walks ([CollectibleChildren]) see through it, so media
/// collection and introspection descend as if it were not there.
///
/// ```dart
/// SpecElementId(
///   id: 'el-title',
///   child: const Text('Hello').animate([Animation.fadeIn()]),
/// )
/// ```
final class ElementId extends StatelessWidget implements CollectibleChildren {
  /// Marks [child] as the element identified by [id].
  const ElementId({required this.id, required this.child, this.lane, super.key});

  /// The spec element's document id, exactly as the document carries it.
  final String id;

  /// Optional shared clip lane used by paired transitions.
  final String? lane;

  /// The element's widget form, usually its `.animate()` wrapper.
  final Widget child;

  /// The structural walk sees through the marker to the element itself.
  @override
  Iterable<Widget> get collectibleChildren => [child];

  @override
  Widget build(BuildContext context) => child;
}

/// Compatibility name retained for existing spec/editor integrations.
typedef SpecElementId = ElementId;
