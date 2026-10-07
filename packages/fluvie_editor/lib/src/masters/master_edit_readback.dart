part of 'master_edit_session.dart';

/// The read-back half of [MasterEditSession]: the edited synthetic scene
/// turned back into master JSON, with the placeholder guard and the deep
/// identity strip.
extension _MasterEditReadBack on MasterEditSession {
  /// The master JSON the edited [scene] describes, or null when a
  /// placeholder was removed, buried, or duplicated (refused — slots are
  /// not deletable from master-edit mode).
  Map<String, Object?>? _readBack(Map<String, Object?> scene) {
    final children = scene['children'];
    final list = children is List
        ? children.whereType<Map<String, Object?>>()
        : const Iterable<Map<String, Object?>>.empty();
    final rebuilt = <Map<String, Object?>>[];
    final seen = <int>{};
    for (final child in list) {
      final index = _slotIndexOf(child['id']);
      if (index == null) {
        rebuilt.add(_strippedChrome(child));
        continue;
      }
      final original = _placeholders[index];
      if (original == null || !seen.add(index)) return null;
      rebuilt.add(_placeholderFrom(child, original));
    }
    if (seen.length != _placeholders.length) return null;
    return {
      if (scene['background'] != null) 'background': scene['background'],
      if (_master['layout'] != null) 'layout': _master['layout'],
      if (rebuilt.isNotEmpty) 'children': rebuilt,
    };
  }

  /// The placeholder child index a view id names, or null for chrome.
  int? _slotIndexOf(Object? id) {
    if (id is! String) return null;
    final match = RegExp(r'^s-(\d+)$').firstMatch(id);
    return match == null ? null : int.parse(match.group(1)!);
  }

  /// The placeholder rebuilt from its view group: the slot and style stay
  /// the original's, the transform follows the group — except an untouched
  /// injected default on a transformless placeholder, which stays absent.
  Map<String, Object?> _placeholderFrom(
    Map<String, Object?> child,
    Map<String, Object?> original,
  ) {
    final transform = child['transform'];
    final untouchedDefault =
        original['transform'] == null &&
        _deepEquals(transform, MasterEditSession.defaultSlotTransform);
    return {
      'type': 'Placeholder',
      'slot': original['slot'],
      if (transform != null && !untouchedDefault) 'transform': transform,
      if (original['style'] != null) 'style': original['style'],
    };
  }
}

/// [element] with every identity key (`id`, `anchor`, `shared`) removed at
/// any depth — master children are chrome, and the parser rejects identity
/// on them.
Map<String, Object?> _strippedChrome(Map<String, Object?> element) {
  final stripped = {
    for (final entry in element.entries)
      if (entry.key != 'id' && entry.key != 'anchor' && entry.key != 'shared')
        entry.key: entry.value,
  };
  final child = stripped['child'];
  if (child is Map<String, Object?>) stripped['child'] = _strippedChrome(child);
  final children = stripped['children'];
  if (children is List) {
    stripped['children'] = [
      for (final nested in children)
        if (nested is Map<String, Object?>) _strippedChrome(nested) else nested,
    ];
  }
  return stripped;
}

/// Order-insensitive deep equality over JSON maps, lists, and scalars.
bool _deepEquals(Object? a, Object? b) {
  if (a is Map<String, Object?> && b is Map<String, Object?>) {
    if (a.length != b.length) return false;
    for (final entry in a.entries) {
      if (!b.containsKey(entry.key) || !_deepEquals(entry.value, b[entry.key])) return false;
    }
    return true;
  }
  if (a is List && b is List) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (!_deepEquals(a[i], b[i])) return false;
    }
    return true;
  }
  if (a is num && b is num) return a == b;
  return a == b;
}
