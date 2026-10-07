part of 'editor_document.dart';

/// Lane edits retain the existing element lists as the only z-order truth.
extension EditorDocumentLanes on EditorDocument {
  /// Patches an existing lane; null values remove optional properties.
  EditorDocument updateLane(String id, Map<String, Object?> patch) => _mutate((json) {
    final lanes = (json['lanes'] as List?) ?? const [];
    final lane = lanes
        .whereType<Map<String, Object?>>()
        .where((lane) => lane['id'] == id)
        .firstOrNull;
    if (lane == null) throw ArgumentError.value(id, 'id', 'Unknown lane');
    for (final entry in patch.entries) {
      if (entry.key == 'id') continue;
      if (entry.value == null) {
        lane.remove(entry.key);
      } else {
        lane[entry.key] = _copyValue(entry.value!);
      }
    }
  });

  /// Removes a lane while retaining its material on implicit rows.
  EditorDocument removeLane(String id) => _mutate((json) {
    final lanes = ((json['lanes'] as List?) ?? [])
      ..removeWhere((lane) => (lane! as Map)['id'] == id);
    if (lanes.isEmpty) json.remove('lanes');
    void detach(Object? value) {
      if (value is Map<String, Object?>) {
        if (value['lane'] == id) value.remove('lane');
        value.values.forEach(detach);
      } else if (value is List) {
        value.forEach(detach);
      }
    }

    // Only render lists: editorial assets may use arbitrary keys of their own.
    detach(json['scenes']);
    detach(json['overlays']);
    detach(json['audio']);
  });

  /// Reorders lane presentation, then reorders the assigned elements within
  /// each holding list so top timeline rows and top painted elements agree.
  /// Unassigned elements and audio mix order retain their positions.
  EditorDocument reorderLane(String id, int to) => _mutate((json) {
    final lanes = json['lanes']! as List<Object?>;
    final from = lanes.indexWhere((lane) => (lane! as Map)['id'] == id);
    if (from < 0) throw ArgumentError.value(id, 'id', 'Unknown lane');
    lanes.insert(to.clamp(0, lanes.length - 1), lanes.removeAt(from));
    final order = {for (var i = 0; i < lanes.length; i++) (lanes[i]! as Map)['id']: i};
    void reorder(List<Object?> children) {
      final assigned = [
        for (final child in children.whereType<Map<String, Object?>>())
          if (order.containsKey(child['lane'])) child,
      ];
      final old = {for (var i = 0; i < assigned.length; i++) assigned[i]['id']: i};
      assigned.sort((a, b) {
        final byLane = order[b['lane']]!.compareTo(order[a['lane']]!);
        return byLane == 0 ? old[a['id']]!.compareTo(old[b['id']]!) : byLane;
      });
      var index = 0;
      for (var i = 0; i < children.length; i++) {
        final child = children[i]! as Map<String, Object?>;
        if (order.containsKey(child['lane'])) children[i] = assigned[index++];
        if (child['type'] == 'Group' && child['children'] is List<Object?>) {
          reorder(child['children']! as List<Object?>);
        }
      }
    }

    for (var s = 0; s < sceneCount; s++) {
      reorder(_sceneChildren(json, s));
    }
    if (json['overlays'] is List<Object?>) reorder(json['overlays']! as List<Object?>);
  });
}
