part of 'editor_document.dart';

typedef _ElementLocation = ({int? scene, Map<String, Object?> element, String? parent});

/// The document's overlay elements, or an empty list when it declares none.
List<Map<String, Object?>> _overlayJson(Map<String, Object?> json) {
  final overlays = json['overlays'];
  if (overlays is! List) return const [];
  return overlays.cast<Map<String, Object?>>();
}

List<Map<String, Object?>> _children(Map<String, Object?> scene) {
  final children = scene['children'];
  if (children is! List) return const [];
  return children.cast<Map<String, Object?>>();
}

Map<String, Object?> _deepCopy(Map<String, Object?> json) =>
    jsonDecode(jsonEncode(json)) as Map<String, Object?>;
