import 'dart:convert';

import 'package:fluvie/fluvie.dart' show VideoSpec;
import 'package:meta/meta.dart';

part 'editor_document_mutations.dart';

/// The deck being edited: a thin immutable wrapper over the `.fluvie`
/// document itself.
///
/// The editor edits the spec's canonical JSON directly — there is no second
/// model, so saving is identity and everything authorable is already
/// serializable. Every mutation returns a new document and leaves this one
/// untouched; commands and history build on that.
///
/// Loading mints a stable `id` for every element that has none (fluvie
/// preserves ids but never invents them); from then on ids are the one way
/// tools refer to elements.
@immutable
final class EditorDocument {
  EditorDocument._(this._json) : _spec = VideoSpec.fromJson(_json);

  /// Parses [json], validates it as a spec, and mints missing element ids.
  factory EditorDocument.fromJson(Map<String, Object?> json) {
    final canonical = _deepCopy(json);
    _mintMissingIds(canonical);
    return EditorDocument._(canonical);
  }

  final Map<String, Object?> _json;
  final VideoSpec _spec;

  /// The parsed spec for this document state (derivation reads this).
  VideoSpec get spec => _spec;

  /// The canonical JSON document. Treat it as immutable; mutations go
  /// through the typed methods.
  Map<String, Object?> toJson() => _deepCopy(_json);

  /// The render digest: only render-affecting content moves it (the
  /// `editor` block is excluded by the spec itself).
  String get renderDigest => _spec.digest();

  /// The whole-document digest, editor metadata included — the dirty
  /// tracker's truth.
  String get documentDigest => jsonEncode(_json).hashCode.toRadixString(16);

  /// How many scenes (slides) the deck has.
  int get sceneCount => _scenes.length;

  /// The JSON of scene [index].
  Map<String, Object?> sceneJson(int index) => _deepCopy(_scene(index));

  /// The element ids of scene [index], in z-order.
  List<String> elementIdsInScene(int index) => [
    for (final child in _children(_scene(index))) child['id']! as String,
  ];

  /// The JSON of the element with [id], or null when no scene holds it.
  Map<String, Object?>? elementJson(String id) {
    final found = _locate(id);
    return found == null ? null : _deepCopy(found.element);
  }

  /// The scene index holding [id], or null.
  int? sceneOfElement(String id) => _locate(id)?.scene;

  /// The editor-block metadata for [id] (name, lock, and friends), empty
  /// when none was written.
  Map<String, Object?> elementMeta(String id) {
    final editor = _json['editor'];
    if (editor is! Map<String, Object?>) return const {};
    final elements = editor['elements'];
    if (elements is! Map<String, Object?>) return const {};
    final meta = elements[id];
    return meta is Map<String, Object?> ? _deepCopy(meta) : const {};
  }

  /// A fresh element id that collides with nothing in the document.
  String nextId() => _nextId(_json);

  List<Object?> get _scenes => _json['scenes']! as List<Object?>;

  Map<String, Object?> _scene(int index) => _scenes[index]! as Map<String, Object?>;

  ({int scene, Map<String, Object?> element})? _locate(String id) {
    for (var s = 0; s < _scenes.length; s++) {
      for (final child in _children(_scene(s))) {
        if (child['id'] == id) return (scene: s, element: child);
      }
    }
    return null;
  }
}

List<Map<String, Object?>> _children(Map<String, Object?> scene) {
  final children = scene['children'];
  if (children is! List) return const [];
  return children.cast<Map<String, Object?>>();
}

Map<String, Object?> _deepCopy(Map<String, Object?> json) =>
    jsonDecode(jsonEncode(json)) as Map<String, Object?>;

void _mintMissingIds(Map<String, Object?> json) {
  final scenes = json['scenes'];
  if (scenes is! List) return;
  for (final scene in scenes.whereType<Map<String, Object?>>()) {
    for (final child in _children(scene)) {
      child['id'] ??= _nextId(json);
    }
  }
}

String _nextId(Map<String, Object?> json) {
  final used = <Object?>{};
  final scenes = json['scenes'];
  if (scenes is List) {
    for (final scene in scenes.whereType<Map<String, Object?>>()) {
      for (final child in _children(scene)) {
        used.add(child['id']);
      }
    }
  }
  var counter = 1;
  while (used.contains('el-$counter')) {
    counter++;
  }
  return 'el-$counter';
}
