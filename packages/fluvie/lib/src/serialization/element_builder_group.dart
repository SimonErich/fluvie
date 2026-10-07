part of 'element_builder.dart';

// A `Group` nests a whole `children` list inside one box. The composition is
// `SizedBox.expand` over a `Stack`: the expand fills whatever box the group
// gets (its placed rect, or the scene canvas without a `transform`), and each
// child's own `Placed` then resolves its fractions against THAT box — nesting
// comes free from `Placed`'s fraction-of-parent layout. Both widgets are
// walkable shapes, so media inside a group still reaches the collect pass.

/// A `Group` from its spec props: every entry of `children` is one full
/// element, decoded recursively and built through the document's shared
/// [anchors] table. An empty group renders nothing.
Widget _group(Map<String, Object?> props, AnchorTable anchors) {
  final childrenRaw = props['children'];
  if (childrenRaw is! List) {
    throw FluvieSpecError('A Group needs a "children" list', path: const ['children']);
  }
  final children = <Widget>[];
  for (var i = 0; i < childrenRaw.length; i++) {
    final child = childrenRaw[i];
    if (child is! Map<String, Object?>) {
      throw FluvieSpecError('Expected an element object', path: ['children', '$i']);
    }
    children.add(ElementSpec.fromJson(child, anchors, path: ['children', '$i']).build(anchors));
  }
  return SizedBox.expand(child: Stack(children: children));
}
