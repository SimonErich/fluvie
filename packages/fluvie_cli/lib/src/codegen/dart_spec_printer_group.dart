part of 'dart_spec_printer.dart';

/// A `Group` printed as exactly the composition fluvie's builder mounts:
/// `SizedBox.expand` over a `Stack` of the printed children, so a
/// widget-authored tree and a spec-authored one read the same. The expand
/// fills the group's placed box and each child's `Placed` resolves its
/// fractions against that box — nesting needs no dedicated widget.
String _groupElement(Map<String, Object?> element, _Anchors anchors) {
  final children = element['children'];
  if (children is! List) {
    throw const FormatException('A Group needs a "children" list');
  }
  return 'SizedBox.expand(child: Stack(children: [${_elementItems(children, anchors)}]))';
}

/// The items of an element list (scene children, group children): every
/// visible element prints through `_element`, and a `visible: false` element
/// is omitted with a comment naming it — the printed Dart is the render, and
/// a hidden element renders nothing.
String _elementItems(List<Object?> children, _Anchors anchors) {
  final buffer = StringBuffer();
  for (final child in children) {
    final element = _map(child);
    if (element['visible'] == false) {
      buffer.writeln('// ${_hiddenLabel(element)}');
    } else {
      buffer.write('${_element(element, anchors)}, ');
    }
  }
  return buffer.toString();
}

/// What a hidden element's stand-in comment says: the type, the id when the
/// document carries one, and why the element is not in the code.
String _hiddenLabel(Map<String, Object?> element) {
  final id = element['id'];
  final type = element['type'];
  final name = id is String ? '$type "$id"' : '$type';
  return 'hidden: $name omitted from the printed build';
}
