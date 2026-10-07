import 'dart:math' as math;
import 'dart:ui' show Color;

import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/painting.dart' show Alignment;
import 'package:fluvie/fluvie.dart' show decodeAlignment, encodeAlignment, encodeColor;
import 'package:fluvie_editor/src/theme/token_color_scope.dart';
import 'package:fluvie_editor/src/widgets/gradient_editor/gradient_editor_value.dart';

/// The gradient editor's view of a `gradient`/`radial` background: offsets
/// read from the spec's optional `stops` list (even spacing when it is
/// absent or does not line up with the colors), the angle derives from the
/// `begin`/`end` alignment pair. Token-bound colors resolve through
/// [colors].
GradientEditorValue gradientValueOf(Map<String, Object?> background, TokenColorScope colors) {
  final raw = background['colors'];
  final entries = raw is List ? raw : const <Object?>[];
  final offsets = _offsetsOf(background['stops'], entries.length);
  return GradientEditorValue(
    stops: [
      for (final (i, entry) in entries.indexed)
        GradientEditorStop(
          offset: offsets[i],
          color: colors.resolve(entry, const Color(0xFF101018)),
        ),
    ],
    kind: background['kind'] == 'radial' ? GradientEditorKind.radial : GradientEditorKind.linear,
    angle: _angleOf(background),
  );
}

/// The background JSON for [value] over [previous]: skewed offsets write the
/// `stops` list and exactly even offsets elide it (the canonical stops-less
/// form), a linear angle becomes `begin`/`end`, and a stop whose color or
/// offset did not change keeps its raw JSON — a token reference survives
/// edits to the other stops.
Map<String, Object?> gradientBackgroundJson(
  GradientEditorValue value,
  Map<String, Object?> previous,
  TokenColorScope colors,
) {
  final rawColors = previous['colors'];
  final kept = rawColors is List ? rawColors : const <Object?>[];
  final radial = value.kind == GradientEditorKind.radial;
  return {
    ...previous,
    'kind': radial ? 'radial' : 'gradient',
    'colors': [
      for (final (i, stop) in value.stops.indexed)
        if (i < kept.length && colors.resolve(kept[i], const Color(0x00000000)) == stop.color)
          kept[i]
        else
          encodeColor(stop.color),
    ],
    'stops': _stopsJson(value.stops, previous['stops']),
    if (radial) ...{'begin': null, 'end': null} else ..._alignmentsFor(value.angle),
  }..removeWhere((_, entry) => entry == null);
}

/// The stop offsets the editor shows: the spec's `stops` when it is a
/// numeric list pairing up with the colors, even spacing otherwise.
List<double> _offsetsOf(Object? raw, int count) {
  if (raw is List && raw.length == count && raw.every((entry) => entry is num)) {
    return [for (final entry in raw) (entry! as num).toDouble()];
  }
  final last = count - 1;
  return [
    for (var i = 0; i < count; i++)
      if (last <= 0) 0.0 else i / last,
  ];
}

/// The `stops` JSON for the edited offsets: null when every offset sits at
/// its even-spacing value (the canonical form drops the key), the previous
/// raw list when it matches numerically (old documents stay byte-identical),
/// the rounded offsets otherwise.
Object? _stopsJson(List<GradientEditorStop> stops, Object? previous) {
  final last = stops.length - 1;
  final offsets = [for (final stop in stops) _rounded(stop.offset)];
  final even = [
    for (var i = 0; i <= last; i++) _rounded(last <= 0 ? 0 : i / last),
  ];
  if (listEquals(offsets, even)) return null;
  if (previous is List && previous.length == offsets.length) {
    var unchanged = true;
    for (var i = 0; i < offsets.length; i++) {
      final entry = previous[i];
      if (entry is! num || entry.toDouble() != offsets[i]) {
        unchanged = false;
        break;
      }
    }
    if (unchanged) return previous;
  }
  return offsets;
}

double _angleOf(Map<String, Object?> background) {
  if (background['kind'] == 'radial') return 45;
  final begin = _alignment(background['begin'], Alignment.topLeft);
  final end = _alignment(background['end'], Alignment.bottomRight);
  final dx = end.x - begin.x;
  final dy = end.y - begin.y;
  if (dx == 0 && dy == 0) return 45;
  final degrees = math.atan2(dy, dx) * 180 / math.pi;
  return _rounded((degrees % 360 + 360) % 360);
}

Alignment _alignment(Object? raw, Alignment fallback) =>
    raw == null ? fallback : decodeAlignment(raw);

/// The `begin`/`end` pair of a linear [angle]: the direction vector scaled
/// to the unit-square edge, so the cardinal and diagonal angles land on the
/// codec's named alignments (45 is topLeft to bottomRight).
Map<String, Object?> _alignmentsFor(double angle) {
  final radians = angle * math.pi / 180;
  final dx = math.cos(radians);
  final dy = math.sin(radians);
  final scale = 1 / math.max(dx.abs(), dy.abs());
  final x = _rounded(dx * scale);
  final y = _rounded(dy * scale);
  return {
    'begin': encodeAlignment(Alignment(-x, -y)),
    'end': encodeAlignment(Alignment(x, y)),
  };
}

double _rounded(double value) => (value * 10000).round() / 10000;
