import 'package:flutter/painting.dart' show Alignment;
import 'package:fluvie/src/core/errors/fluvie_spec_error.dart';

/// The nine standard [Alignment] values by name.
const Map<String, Alignment> namedAlignments = {
  'topLeft': Alignment.topLeft,
  'topCenter': Alignment.topCenter,
  'topRight': Alignment.topRight,
  'centerLeft': Alignment.centerLeft,
  'center': Alignment.center,
  'centerRight': Alignment.centerRight,
  'bottomLeft': Alignment.bottomLeft,
  'bottomCenter': Alignment.bottomCenter,
  'bottomRight': Alignment.bottomRight,
};

/// The JSON form of an [Alignment]: a name from [namedAlignments] when it is one
/// of the nine standard values, otherwise an `{"x": .., "y": ..}` object.
Object encodeAlignment(Alignment alignment) {
  for (final entry in namedAlignments.entries) {
    if (entry.value == alignment) return entry.key;
  }
  return {'x': alignment.x, 'y': alignment.y};
}

/// Reads an [Alignment] from a name or an `{"x": .., "y": ..}` object in [raw].
///
/// Throws a [FluvieSpecError] (located at [path]) when [raw] is neither.
Alignment decodeAlignment(Object? raw, {List<String> path = const []}) {
  if (raw is String) {
    final alignment = namedAlignments[raw];
    if (alignment == null) {
      throw FluvieSpecError(
        'Unknown alignment "$raw"; expected one of: ${namedAlignments.keys.join(', ')}, or {x, y}',
        path: path,
      );
    }
    return alignment;
  }
  if (raw is Map) {
    final x = raw['x'];
    final y = raw['y'];
    if (x is num && y is num) return Alignment(x.toDouble(), y.toDouble());
  }
  throw FluvieSpecError('Expected an alignment name or an {x, y} object', path: path);
}
