part of 'editor_document.dart';

/// Editing a shared title propagates only the properties the user actually
/// changed. Each member keeps its geometry, identity, anchors and lane.
extension EditorDocumentShared on EditorDocument {
  /// Splits in the same holding list, including nested groups and overlays.
  EditorDocument razorElement(
    String id,
    String tailId,
    Map<String, Object?> head,
    Map<String, Object?> tail,
  ) => _mutate((json) {
    final holding = _childrenHolding(json, id);
    final index = holding.indexWhere((child) => (child! as Map)['id'] == id);
    holding[index] = {..._deepCopy(head), 'id': id};
    holding.insert(index + 1, {..._deepCopy(tail), 'id': tailId});
    final home = overlayHome(id);
    if (home != null) {
      final editor = json['editor']! as Map<String, Object?>;
      (editor['overlayHomes']! as Map<String, Object?>)[tailId] = home;
    }
  });

  /// Applies per-member structural replacements and inserts each split tail
  /// beside its head in the same holding list, as one validated mutation.
  EditorDocument splitSharedMembers(
    Map<String, Map<String, Object?>> replacements,
    Map<String, Map<String, Object?>> tails,
  ) => _mutate((json) {
    for (final entry in replacements.entries) {
      _withElement(json, entry.key, (_) => _deepCopy(entry.value));
    }
    for (final entry in tails.entries) {
      final holding = _childrenHolding(json, entry.key);
      final index = holding.indexWhere((child) => (child! as Map)['id'] == entry.key);
      holding.insert(index + 1, _deepCopy(entry.value));
    }
  });

  /// Scene-ordered members of [id]'s chain, or just [id] for an unshared element.
  List<String> sharedChainIds(String id) {
    final shared = elementJson(id)?['shared'];
    if (shared is! String) return [id];
    return [
      for (var s = 0; s < sceneCount; s++)
        for (final walked in _walkScene(_scene(s)))
          if (walked.element['shared'] == shared) walked.element['id']! as String,
    ];
  }

  /// Replaces the edited member and fans out changed content/timing keys as a
  /// single atomic mutation. Raw [replaceElement] stays local for structural edits.
  EditorDocument editSharedContent(String id, Map<String, Object?> element) {
    final previous = elementJson(id);
    if (previous == null) return replaceElement(id, element);
    const local = {'id', 'shared', 'anchor', 'transform', 'lane', 'children'};
    final changes = <String, Object?>{
      for (final key in {...previous.keys, ...element.keys})
        if (!local.contains(key) && jsonEncode(previous[key]) != jsonEncode(element[key]))
          key: element[key],
    };
    final peers = sharedChainIds(id);
    return _mutate((json) {
      _withElement(json, id, (_) => {..._deepCopy(element), 'id': id});
      for (final peer in peers) {
        if (peer == id) continue;
        _withElement(json, peer, (current) {
          final next = {...current};
          for (final entry in changes.entries) {
            if (entry.value == null) {
              next.remove(entry.key);
            } else {
              next[entry.key] = _copyValue(entry.value!);
            }
          }
          return next;
        });
      }
    });
  }
}
