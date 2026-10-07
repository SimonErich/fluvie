part of 'scene_spec.dart';

// The scene's master-adoption keys: the adopted master's name and the
// slot-to-element fills map. Application itself lives with `MasterSpec`
// (`resolveSceneMaster` in master_spec.dart); the scene only carries the
// data verbatim so the document round-trips.

String? _decodeMasterName(Object? raw, List<String> path) {
  if (raw == null || raw is String) return raw as String?;
  throw FluvieSpecError('Expected "master" to be a master name', path: [...path, 'master']);
}

Map<String, ElementSpec> _decodeFills(
  Object? raw,
  AnchorTable anchors,
  List<String> path, {
  required bool hasMaster,
}) {
  if (raw == null) return const {};
  final fillsPath = [...path, 'fills'];
  if (raw is! Map<String, Object?>) {
    throw FluvieSpecError('Expected "fills" to be an object of slot fills', path: fillsPath);
  }
  if (!hasMaster && raw.isNotEmpty) {
    throw FluvieSpecError('"fills" need a "master" to fill', path: fillsPath);
  }
  final fills = <String, ElementSpec>{};
  for (final entry in raw.entries) {
    final value = entry.value;
    if (value is! Map<String, Object?>) {
      throw FluvieSpecError('Expected an element object', path: [...fillsPath, entry.key]);
    }
    fills[entry.key] = ElementSpec.fromJson(value, anchors, path: [...fillsPath, entry.key]);
  }
  return fills;
}
