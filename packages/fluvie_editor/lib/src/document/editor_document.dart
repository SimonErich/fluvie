import 'dart:convert';
import 'dart:ui' show Size;

import 'package:fluvie/fluvie.dart' show VideoSpec;
import 'package:fluvie_editor/src/arrange/arrange_order.dart';
import 'package:fluvie_editor/src/arrange/group_math.dart';
import 'package:fluvie_editor/src/autoanimate/pairing.dart';
import 'package:fluvie_editor/src/blocks/block_reflow.dart';
import 'package:fluvie_editor/src/blocks/block_spec.dart';
import 'package:fluvie_editor/src/media/media_store_entry.dart';
import 'package:meta/meta.dart';

part 'editor_document_animations.dart';
part 'editor_document_effects.dart';
part 'editor_document_arrange.dart';
part 'editor_document_audio.dart';
part 'editor_document_autoanimate.dart';
part 'editor_document_autoanimate_edits.dart';
part 'editor_document_blocks.dart';
part 'editor_document_fills.dart';
part 'editor_document_masters.dart';
part 'editor_document_media.dart';
part 'editor_document_meta.dart';
part 'editor_document_move.dart';
part 'editor_document_overlays.dart';
part 'editor_document_mutations.dart';
part 'editor_document_shared.dart';
part 'editor_document_lanes.dart';
part 'editor_document_scene_meta.dart';
part 'editor_document_scenes.dart';
part 'editor_document_theme.dart';
part 'editor_document_tree.dart';
part 'editor_document_json.dart';

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
  // Element props and editorData may retain nested parser input. Isolate the
  // public spec from the canonical snapshot before retaining derived lookups.
  EditorDocument._(this._json) : _spec = VideoSpec.fromJson(_deepCopy(_json));

  /// Parses [json], validates it as a spec, and mints missing element ids
  /// (group children included). Legacy editor-block `hidden` flags migrate
  /// to the spec's `visible` key here.
  factory EditorDocument.fromJson(Map<String, Object?> json) {
    final canonical = _deepCopy(json);
    _mintMissingIds(canonical);
    _migrateHiddenMeta(canonical);
    return EditorDocument._(canonical);
  }

  final Map<String, Object?> _json;
  final VideoSpec _spec;
  late final String _documentDigest = jsonEncode(_json).hashCode.toRadixString(16);
  late final Map<String, _ElementLocation> _elementLocations = _indexElements();

  /// The parsed spec for this document state (derivation reads this).
  /// Its nested collections are independent of the canonical document; edits
  /// intended for saving or undo must use the document's typed mutations.
  VideoSpec get spec => _spec;

  /// The canonical JSON document. Treat it as immutable; mutations go
  /// through the typed methods.
  Map<String, Object?> toJson() => _deepCopy(_json);

  /// The render digest: only render-affecting content moves it (the
  /// `editor` block is excluded by the spec itself).
  String get renderDigest => _spec.digest();

  /// The whole-document digest, editor metadata included — the dirty
  /// tracker's truth.
  String get documentDigest => _documentDigest;

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

  /// The scene index holding [id] (group children resolve to their scene),
  /// or null.
  int? sceneOfElement(String id) => _locate(id)?.scene;

  /// The child ids of group [id] in z-order — empty for non-groups and
  /// unknown ids.
  List<String> childIdsOfGroup(String id) {
    final found = _locate(id);
    if (found == null) return const [];
    return [for (final child in _groupChildren(found.element)) child['id']! as String];
  }

  /// The id of the group holding [id], or null at the scene's top level
  /// (and for ids the document does not hold).
  String? parentGroupOf(String id) => _locate(id)?.parent;

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

  /// The editor-block metadata for slide [index] (manual guides and
  /// friends), empty when none was written.
  Map<String, Object?> sceneMeta(int index) {
    final editor = _json['editor'];
    if (editor is! Map<String, Object?>) return const {};
    final scenes = editor['scenes'];
    if (scenes is! Map<String, Object?>) return const {};
    final meta = scenes['$index'];
    return meta is Map<String, Object?> ? _deepCopy(meta) : const {};
  }

  /// A fresh element id that collides with nothing in the document.
  String nextId() => _nextId(_json);

  /// [count] fresh element ids, distinct from each other and from every id
  /// in the document — a paste mints its whole batch up front so redo stays
  /// deterministic.
  List<String> nextIds(int count) {
    final used = _usedIds(_json);
    return [for (var i = 0; i < count; i++) _mintId(used)];
  }

  /// Every anchor id declared by any element, nested group children
  /// included — the namespace a paste must not collide with.
  Set<String> get anchorIds => {
    for (var s = 0; s < _scenes.length; s++)
      for (final walked in _walkScene(_scene(s)))
        if (walked.element['anchor'] case final String anchor) anchor,
  };

  List<Object?> get _scenes => _json['scenes']! as List<Object?>;

  Map<String, Object?> _scene(int index) => _scenes[index]! as Map<String, Object?>;

  _ElementLocation? _locate(String id) => _elementLocations[id];

  Map<String, _ElementLocation> _indexElements() {
    final locations = <String, _ElementLocation>{};
    void add(_WalkedElement walked, int? scene) {
      final id = walked.element['id'];
      if (id is String) {
        locations.putIfAbsent(
          id,
          () => (scene: scene, element: walked.element, parent: walked.parent),
        );
      }
    }

    for (var s = 0; s < _scenes.length; s++) {
      for (final walked in _walkScene(_scene(s))) {
        add(walked, s);
      }
    }
    // The overlays: found by id like anything else, but owned by no scene, so
    // `scene` stays null. Handing back a home index here would let a verb that
    // means "the scene that holds this" insert into a scene's children.
    for (final walked in _walkElements(_overlayJson(_json), null)) {
      add(walked, null);
    }
    return Map.unmodifiable(locations);
  }
}
