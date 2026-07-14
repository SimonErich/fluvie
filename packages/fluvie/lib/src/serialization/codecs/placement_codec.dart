import 'package:flutter/painting.dart' show Alignment;
import 'package:fluvie/src/core/errors/fluvie_spec_error.dart';
import 'package:fluvie/src/core/placement.dart';
import 'package:fluvie/src/serialization/codecs/alignment_codec.dart';

/// The keys a `transform` object reads. The single source of truth shared by
/// the parser's unknown-property check and the schema.
const Set<String> knownPlacementKeys = {'x', 'y', 'w', 'h', 'rotation', 'anchor'};

/// Reads a [Placement] from a `transform` object in [raw].
///
/// Throws a [FluvieSpecError] (located at [path]) for a non-object, missing
/// `x`/`y`, or an unknown `anchor`.
Placement decodePlacement(Object? raw, {List<String> path = const []}) {
  if (raw is! Map<String, Object?>) {
    throw FluvieSpecError('Expected a transform object', path: path);
  }
  final x = raw['x'];
  final y = raw['y'];
  if (x is! num || y is! num) {
    throw FluvieSpecError(
      'A transform needs numeric "x" and "y" canvas fractions',
      path: path,
    );
  }
  final w = raw['w'];
  final h = raw['h'];
  final rotation = raw['rotation'];
  return Placement(
    x: x.toDouble(),
    y: y.toDouble(),
    width: w is num ? w.toDouble() : null,
    height: h is num ? h.toDouble() : null,
    rotation: rotation is num ? rotation.toDouble() : 0,
    anchor: raw['anchor'] == null
        ? Alignment.center
        : decodeAlignment(raw['anchor'], path: [...path, 'anchor']),
  );
}

/// The JSON form of a [Placement]: only the fields that differ from their
/// defaults, so the canonical form stays minimal.
Map<String, Object?> encodePlacement(Placement placement) => {
  'x': placement.x,
  'y': placement.y,
  if (placement.width != null) 'w': placement.width,
  if (placement.height != null) 'h': placement.height,
  if (placement.rotation != 0) 'rotation': placement.rotation,
  if (placement.anchor != Alignment.center) 'anchor': encodeAlignment(placement.anchor),
};
