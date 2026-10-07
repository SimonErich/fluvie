part of 'spec_validation.dart';

// The warning half of masters, mirroring the parser errors in
// master_spec_parser.dart: masters are closed shapes, a placeholder is a
// closed shape, master children carry no identity keys at any depth, and a
// scene's master name and fill slots must exist.

/// The closed placeholder shape (mirror of the placeholder parser).
const Set<String> _placeholderShape = {'type', 'slot', 'transform', 'style'};

/// The masters block: each master closed over [MasterSpec.knownKeys], its
/// background and chrome children swept as usual, placeholders as closed
/// shapes, and identity keys flagged at any depth of a fixed child.
void _checkMasters(Map<String, Object?> masters, List<FluvieSpecWarning> out) {
  for (final entry in masters.entries) {
    final master = entry.value;
    if (master is! Map<String, Object?>) continue; // Wrong type: the parser reports it.
    final path = ['masters', entry.key];
    _checkKeys(master, MasterSpec.knownKeys, 'a master', path, out);
    final background = master['background'];
    if (background is Map<String, Object?>) {
      _checkBackground(background, [...path, 'background'], out);
    }
    final children = master['children'];
    if (children is! List) continue;
    for (var i = 0; i < children.length; i++) {
      final child = children[i];
      if (child is! Map<String, Object?>) continue;
      final childPath = [...path, 'children', '$i'];
      if (child['type'] == 'Placeholder') {
        _checkKeys(child, _placeholderShape, 'a placeholder', childPath, out);
        _checkNested(child, 'transform', knownPlacementKeys, 'a transform', childPath, out);
        _checkNested(child, 'style', _styleOrTokenFields, 'a text style', childPath, out);
      } else {
        _warnIdentityKeys(child, childPath, out);
        _checkElement(child, childPath, out);
      }
    }
  }
}

/// The scene's adoption keys: an unknown master name, fills for slots the
/// master does not define, and the fill elements themselves (each swept like
/// any other element).
void _checkSceneMaster(
  Map<String, Object?> scene,
  Object? mastersRaw,
  List<String> scenePath,
  List<FluvieSpecWarning> out,
) {
  final masters = mastersRaw is Map<String, Object?> ? mastersRaw : const <String, Object?>{};
  final name = scene['master'];
  final master = name is String ? masters[name] : null;
  if (name is String && master is! Map<String, Object?>) {
    out.add(
      FluvieSpecWarning(
        'Unknown master "$name"; the document defines ${_nameList(masters.keys)}',
        path: [...scenePath, 'master'],
      ),
    );
  }
  final fills = scene['fills'];
  if (fills is! Map<String, Object?>) return; // Wrong type: the parser reports it.
  final slots = master is Map<String, Object?> ? _masterSlots(master) : null;
  for (final entry in fills.entries) {
    final fillPath = [...scenePath, 'fills', entry.key];
    if (slots != null && !slots.contains(entry.key)) {
      out.add(
        FluvieSpecWarning(
          'Unknown slot "${entry.key}"; the master defines ${_nameList(slots)}',
          path: fillPath,
        ),
      );
    }
    final fill = entry.value;
    if (fill is Map<String, Object?>) _checkElement(fill, fillPath, out);
  }
}

/// Master children are chrome, not per-scene elements: identity keys are
/// flagged at any depth (mirror of the parser's hard rejection).
void _warnIdentityKeys(Map<String, Object?> json, List<String> path, List<FluvieSpecWarning> out) {
  for (final key in const ['id', 'anchor', 'shared']) {
    if (!json.containsKey(key)) continue;
    out.add(
      FluvieSpecWarning(
        'A master child carries no "$key"; identity belongs to the scene\'s own fills and children',
        path: path,
      ),
    );
  }
  final child = json['child'];
  if (child is Map<String, Object?>) _warnIdentityKeys(child, [...path, 'child'], out);
  final children = json['children'];
  if (children is! List) return;
  for (var i = 0; i < children.length; i++) {
    final nested = children[i];
    if (nested is Map<String, Object?>) {
      _warnIdentityKeys(nested, [...path, 'children', '$i'], out);
    }
  }
}

/// The slot names a raw master json defines.
Set<String> _masterSlots(Map<String, Object?> master) {
  final children = master['children'];
  if (children is! List) return const {};
  return {
    for (final child in children)
      if (child is Map<String, Object?> && child['type'] == 'Placeholder')
        if (child['slot'] case final String slot) slot,
  };
}

String _nameList(Iterable<String> names) {
  if (names.isEmpty) return 'no names';
  final sorted = names.toList()..sort();
  return sorted.map((name) => '"$name"').join(', ');
}
