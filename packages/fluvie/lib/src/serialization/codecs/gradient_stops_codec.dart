import 'package:fluvie/src/core/errors/fluvie_spec_error.dart';

/// Reads a gradient's optional `stops` list from [raw]: one 0..1 offset per
/// color, non-decreasing. Returns `null` when [raw] is null — the gradient
/// then spaces its colors evenly, the canonical stops-less form.
///
/// Throws a [FluvieSpecError] (located at [path], or at the offending index)
/// when [raw] is not a list, its length differs from [colorCount], an entry
/// is not a number inside 0..1, or an entry decreases below its predecessor.
List<double>? decodeGradientStops(
  Object? raw, {
  required int colorCount,
  List<String> path = const [],
}) {
  if (raw == null) return null;
  if (raw is! List) {
    throw FluvieSpecError('Expected a list of stop offsets', path: path);
  }
  if (raw.length != colorCount) {
    throw FluvieSpecError(
      'Expected $colorCount stops to match $colorCount colors, got ${raw.length}',
      path: path,
    );
  }
  final stops = <double>[];
  for (var i = 0; i < raw.length; i++) {
    final entry = raw[i];
    if (entry is! num || entry < 0 || entry > 1) {
      throw FluvieSpecError('Expected a stop offset between 0 and 1', path: [...path, '$i']);
    }
    final offset = entry.toDouble();
    if (stops.isNotEmpty && offset < stops.last) {
      throw FluvieSpecError('Stop offsets must not decrease', path: [...path, '$i']);
    }
    stops.add(offset);
  }
  return stops;
}
