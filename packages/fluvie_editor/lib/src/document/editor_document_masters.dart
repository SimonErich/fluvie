part of 'editor_document.dart';

/// One slot of the master a scene adopts: the slot name, the id of the
/// scene's fill (null while the slot is unfilled), the resolved `transform`
/// JSON (the fill's own wins over the placeholder's; null when neither
/// declares one), and the placeholder's style defaults.
typedef MasterSlot = ({
  String slot,
  String? fillId,
  Map<String, Object?>? transform,
  Map<String, Object?>? style,
});

/// The document's masters surface: reading the `masters` block and a
/// scene's adoption, and the mutations behind master editing — writing a
/// master wholesale, filling a slot, and the apply/detach pair whose
/// orphaned fills promote to plain scene children instead of vanishing.
extension EditorDocumentMasters on EditorDocument {
  /// The master names, in document order.
  List<String> get masterNames {
    final masters = _json['masters'];
    return masters is Map<String, Object?> ? [...masters.keys] : const [];
  }

  /// A copy of the master [name]'s JSON, or null for an unknown name.
  Map<String, Object?>? masterJson(String name) {
    final master = _masterIn(_json, name);
    return master == null ? null : _deepCopy(master);
  }

  /// The master slide [index] adopts, or null for a freeform slide.
  String? sceneMasterName(int index) {
    final name = _scene(index)['master'];
    return name is String ? name : null;
  }

  /// The adopted master's slots joined with slide [index]'s fills, in
  /// master-child order; empty for a freeform slide.
  List<MasterSlot> masterSlots(int index) {
    final scene = _scene(index);
    final name = scene['master'];
    final master = name is String ? _masterIn(_json, name) : null;
    if (master == null) return const [];
    final fills = scene['fills'];
    return [
      for (final placeholder in _placeholdersOf(master))
        _slotOf(placeholder, fills is Map<String, Object?> ? fills : const {}),
    ];
  }

  /// The slot the fill with [id] fills, or null when [id] is not a fill.
  String? fillSlotOf(String id) => _fillHolding(_json, id)?.slot;

  /// The ids of slide [index]'s fills, in slot order.
  List<String> fillIdsInScene(int index) => [
    for (final slot in masterSlots(index))
      if (slot.fillId case final String id) id,
  ];

  /// Writes the master [name] wholesale (null removes it; the last removal
  /// drops the `masters` block). Removing a master a scene still adopts
  /// fails the revalidation loudly.
  EditorDocument setMasterJson(String name, Map<String, Object?>? master) => _mutate((json) {
    final masters = (json['masters'] ??= <String, Object?>{}) as Map<String, Object?>;
    if (master == null) {
      masters.remove(name);
      if (masters.isEmpty) json.remove('masters');
    } else {
      masters[name] = _deepCopy(master);
    }
  });

  /// Writes [element] as slide [index]'s fill for [slot]. The revalidation
  /// rejects a slot the adopted master does not define — and any fill on a
  /// slide without a master.
  EditorDocument fillSlot(int index, String slot, Map<String, Object?> element) => _mutate((json) {
    final scene = _sceneIn(json, index);
    final fills = (scene['fills'] ??= <String, Object?>{}) as Map<String, Object?>;
    fills[slot] = _deepCopy(element);
  });

  /// Adopts the master [name] on slide [index]. Fills whose slots the new
  /// master defines stay fills; orphaned fills promote to scene children
  /// carrying their resolved look (see [detachMaster]). Throws an
  /// [ArgumentError] for an unknown master.
  EditorDocument applyMaster(int index, String name) => _mutate((json) {
    if (_masterIn(json, name) == null) {
      throw ArgumentError.value(name, 'name', 'No master with this name');
    }
    final scene = _sceneIn(json, index);
    final slots = {
      for (final placeholder in _placeholdersOf(_masterIn(json, name)!)) placeholder['slot'],
    };
    final old = _placeholdersBySlot(json, scene['master']);
    final fills = scene['fills'];
    final kept = <String, Object?>{};
    if (fills is Map<String, Object?>) {
      for (final entry in fills.entries) {
        if (slots.contains(entry.key)) {
          kept[entry.key] = entry.value;
        } else {
          _promoteFill(scene, entry.value, old[entry.key]);
        }
      }
    }
    scene['master'] = name;
    if (kept.isEmpty) {
      scene.remove('fills');
    } else {
      scene['fills'] = kept;
    }
  });

  /// Drops slide [index]'s adoption. Every fill promotes to a scene child
  /// keeping its id and resolved look: its own `transform` (else the
  /// placeholder's, else centered) and the placeholder style merged under
  /// its own per field. The master's chrome stays with the master.
  EditorDocument detachMaster(int index) => _mutate((json) {
    final scene = _sceneIn(json, index);
    final placeholders = _placeholdersBySlot(json, scene['master']);
    final fills = scene['fills'];
    if (fills is Map<String, Object?>) {
      for (final entry in fills.entries) {
        _promoteFill(scene, entry.value, placeholders[entry.key]);
      }
    }
    scene
      ..remove('master')
      ..remove('fills');
  });
}
