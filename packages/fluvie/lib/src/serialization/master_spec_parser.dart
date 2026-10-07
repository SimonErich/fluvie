part of 'master_spec.dart';

// The MasterSpec parser: master names and slot names are identifiers, a
// Placeholder is legal only here, fixed children carry no identity keys at
// any depth, and each slot appears at most once per master.

final RegExp _identifier = RegExp(r'^[a-zA-Z][a-zA-Z0-9]*$');

/// Reads the document's `masters` block: a map of identifier names to
/// [MasterSpec] objects; an absent block reads as empty.
Map<String, MasterSpec> decodeMasters(
  Object? raw,
  AnchorTable anchors, {
  List<String> path = const [],
}) {
  if (raw == null) return const {};
  if (raw is! Map<String, Object?>) {
    throw FluvieSpecError('Expected an object of named masters', path: path);
  }
  final masters = <String, MasterSpec>{};
  for (final entry in raw.entries) {
    if (!_identifier.hasMatch(entry.key)) {
      throw FluvieSpecError(
        'Invalid master name "${entry.key}"; a name is a letter followed by letters or digits',
        path: path,
      );
    }
    final value = entry.value;
    if (value is! Map<String, Object?>) {
      throw FluvieSpecError('Expected a master object', path: [...path, entry.key]);
    }
    masters[entry.key] = MasterSpec.fromJson(value, anchors, path: [...path, entry.key]);
  }
  return masters;
}

MasterSpec _parseMaster(Map<String, Object?> json, AnchorTable anchors, List<String> path) {
  final background = json['background'];
  final children = <MasterChildSpec>[];
  final slots = <String>{};
  final childrenRaw = json['children'];
  if (childrenRaw is List) {
    for (var i = 0; i < childrenRaw.length; i++) {
      final childPath = [...path, 'children', '$i'];
      final child = childrenRaw[i];
      if (child is! Map<String, Object?>) {
        throw FluvieSpecError('Expected an element or Placeholder object', path: childPath);
      }
      if (child['type'] == 'Placeholder') {
        final placeholder = _parsePlaceholder(child, childPath);
        if (!slots.add(placeholder.slot)) {
          throw FluvieSpecError('Duplicate slot "${placeholder.slot}"', path: childPath);
        }
        children.add(placeholder);
      } else {
        _forbidIdentityKeys(child, childPath);
        children.add(MasterElementSpec(ElementSpec.fromJson(child, anchors, path: childPath)));
      }
    }
  } else if (childrenRaw != null) {
    throw FluvieSpecError('Expected "children" to be a list', path: [...path, 'children']);
  }
  return MasterSpec(
    background: background == null
        ? null
        : BackgroundSpec.fromJson(
            _masterObject(background, [...path, 'background']),
            path: [...path, 'background'],
          ),
    layout: _parseLayout(json['layout'], path),
    children: children,
  );
}

PlaceholderSpec _parsePlaceholder(Map<String, Object?> json, List<String> path) {
  final slot = json['slot'];
  if (slot is! String) {
    throw FluvieSpecError('A Placeholder needs a "slot" name', path: path);
  }
  if (!_identifier.hasMatch(slot)) {
    throw FluvieSpecError(
      'Invalid slot "$slot"; a slot name is a letter followed by letters or digits',
      path: path,
    );
  }
  final transform = json['transform'];
  final style = json['style'];
  if (style != null && style is! Map<String, Object?>) {
    throw FluvieSpecError('Expected a style object', path: [...path, 'style']);
  }
  return PlaceholderSpec(
    slot: slot,
    placement: transform == null ? null : decodePlacement(transform, path: [...path, 'transform']),
    style: style == null ? null : {...style as Map<String, Object?>},
  );
}

SceneLayout _parseLayout(Object? raw, List<String> path) => switch (raw) {
  null || 'stack' => SceneLayout.stack,
  'canvas' => SceneLayout.canvas,
  _ => throw FluvieSpecError(
    'Unknown layout "$raw"; expected "canvas" or "stack"',
    path: [...path, 'layout'],
  ),
};

/// Master children are chrome, not per-scene elements: identity keys are
/// rejected at any depth (a wrapper's `child`, a group's `children`).
void _forbidIdentityKeys(Map<String, Object?> json, List<String> path) {
  for (final key in const ['id', 'anchor', 'shared']) {
    if (!json.containsKey(key)) continue;
    throw FluvieSpecError(
      'A master child carries no "$key"; identity belongs to the scene\'s own fills and children',
      path: path,
    );
  }
  final child = json['child'];
  if (child is Map<String, Object?>) _forbidIdentityKeys(child, [...path, 'child']);
  final children = json['children'];
  if (children is! List) return;
  for (var i = 0; i < children.length; i++) {
    final nested = children[i];
    if (nested is Map<String, Object?>) {
      _forbidIdentityKeys(nested, [...path, 'children', '$i']);
    }
  }
}

Map<String, Object?> _masterObject(Object? raw, List<String> path) {
  if (raw is Map<String, Object?>) return raw;
  throw FluvieSpecError('Expected an object', path: path);
}
