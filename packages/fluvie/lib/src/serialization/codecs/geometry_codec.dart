import 'dart:ui' show Offset, Rect;

import 'package:fluvie/src/core/errors/fluvie_spec_error.dart';

/// The keys an `{x, y}` point object reads — shared by the parser's
/// unknown-property check and the schema.
const Set<String> knownOffsetKeys = {'x', 'y'};

/// The keys an `{x, y, w, h}` rect object reads — shared by the parser's
/// unknown-property check and the schema.
const Set<String> knownRectKeys = {'x', 'y', 'w', 'h'};

/// Reads an [Offset] from an `{x, y}` object in [raw] (logical pixels).
///
/// Throws a [FluvieSpecError] (located at [path]) for a non-object or
/// missing coordinates.
Offset decodeOffset(Object? raw, {List<String> path = const []}) {
  if (raw is! Map<String, Object?>) {
    throw FluvieSpecError('Expected a point object {x, y}', path: path);
  }
  final x = raw['x'];
  final y = raw['y'];
  if (x is! num || y is! num) {
    throw FluvieSpecError('A point needs numeric "x" and "y"', path: path);
  }
  return Offset(x.toDouble(), y.toDouble());
}

/// Reads a [Rect] from an `{x, y, w, h}` object in [raw] (logical pixels).
///
/// Throws a [FluvieSpecError] (located at [path]) for a non-object or
/// missing fields.
Rect decodeRect(Object? raw, {List<String> path = const []}) {
  if (raw is! Map<String, Object?>) {
    throw FluvieSpecError('Expected a rect object {x, y, w, h}', path: path);
  }
  final x = raw['x'];
  final y = raw['y'];
  final w = raw['w'];
  final h = raw['h'];
  if (x is! num || y is! num || w is! num || h is! num) {
    throw FluvieSpecError('A rect needs numeric "x", "y", "w", and "h"', path: path);
  }
  return Rect.fromLTWH(x.toDouble(), y.toDouble(), w.toDouble(), h.toDouble());
}
