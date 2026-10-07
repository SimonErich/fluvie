import 'package:flutter/painting.dart'
    show Alignment, Border, BorderRadius, BoxDecoration, BoxShadow, Color, LinearGradient, Offset;
import 'package:fluvie/src/core/errors/fluvie_spec_error.dart';
import 'package:fluvie/src/serialization/codecs/alignment_codec.dart';
import 'package:fluvie/src/serialization/codecs/color_codec.dart';
import 'package:fluvie/src/serialization/codecs/gradient_stops_codec.dart';

/// The fields a `decoration` object reads, mirrored by the unknown-prop
/// validator: a fill `color`, a uniform `cornerRadius`, a `border`
/// ({color, width}), a linear `gradient` ({colors, stops, begin, end}), and
/// one `shadow` ({color, blur, offset, spread}).
const Set<String> knownDecorationKeys = {'color', 'cornerRadius', 'border', 'gradient', 'shadow'};

/// The nested `border` fields.
const Set<String> knownDecorationBorderKeys = {'color', 'width'};

/// The nested `gradient` fields.
const Set<String> knownDecorationGradientKeys = {'colors', 'stops', 'begin', 'end'};

/// The nested `shadow` fields.
const Set<String> knownDecorationShadowKeys = {'color', 'blur', 'offset', 'spread'};

/// Reads the spec's [BoxDecoration] subset from [raw].
///
/// Throws a [FluvieSpecError] (located at [path]) when [raw] is not an object
/// or a field inside it has the wrong shape.
BoxDecoration decodeBoxDecoration(Object? raw, {List<String> path = const []}) {
  if (raw is! Map<String, Object?>) {
    throw FluvieSpecError('Expected a decoration object', path: path);
  }
  final cornerRadius = raw['cornerRadius'];
  if (cornerRadius != null && cornerRadius is! num) {
    throw FluvieSpecError('Expected a number "cornerRadius"', path: [...path, 'cornerRadius']);
  }
  return BoxDecoration(
    color: raw['color'] == null ? null : decodeColor(raw['color'], path: [...path, 'color']),
    borderRadius: cornerRadius is num ? BorderRadius.circular(cornerRadius.toDouble()) : null,
    border: raw['border'] == null ? null : _border(raw['border'], [...path, 'border']),
    gradient: raw['gradient'] == null ? null : _gradient(raw['gradient'], [...path, 'gradient']),
    boxShadow: raw['shadow'] == null
        ? null
        : [
            _shadow(raw['shadow'], [...path, 'shadow']),
          ],
  );
}

Border _border(Object? raw, List<String> path) {
  if (raw is! Map<String, Object?>) throw FluvieSpecError('Expected a border object', path: path);
  final width = raw['width'];
  return Border.all(
    color: raw['color'] == null
        ? const Color(0xFF000000)
        : decodeColor(raw['color'], path: [...path, 'color']),
    width: width is num ? width.toDouble() : 1,
  );
}

LinearGradient _gradient(Object? raw, List<String> path) {
  if (raw is! Map<String, Object?>) throw FluvieSpecError('Expected a gradient object', path: path);
  final colors = raw['colors'];
  if (colors is! List || colors.length < 2) {
    throw FluvieSpecError('Expected "colors" with at least two entries', path: [...path, 'colors']);
  }
  return LinearGradient(
    colors: [
      for (var i = 0; i < colors.length; i++)
        decodeColor(colors[i], path: [...path, 'colors', '$i']),
    ],
    stops: decodeGradientStops(
      raw['stops'],
      colorCount: colors.length,
      path: [...path, 'stops'],
    ),
    begin: raw['begin'] == null
        ? Alignment.topCenter
        : decodeAlignment(raw['begin'], path: [...path, 'begin']),
    end: raw['end'] == null
        ? Alignment.bottomCenter
        : decodeAlignment(raw['end'], path: [...path, 'end']),
  );
}

BoxShadow _shadow(Object? raw, List<String> path) {
  if (raw is! Map<String, Object?>) throw FluvieSpecError('Expected a shadow object', path: path);
  final blur = raw['blur'];
  final spread = raw['spread'];
  final offset = raw['offset'];
  var dx = 0.0;
  var dy = 0.0;
  if (offset is Map<String, Object?>) {
    final x = offset['x'];
    final y = offset['y'];
    if (x is num) dx = x.toDouble();
    if (y is num) dy = y.toDouble();
  } else if (offset != null) {
    throw FluvieSpecError('Expected an offset {x, y}', path: [...path, 'offset']);
  }
  return BoxShadow(
    color: raw['color'] == null
        ? const Color(0x33000000)
        : decodeColor(raw['color'], path: [...path, 'color']),
    blurRadius: blur is num ? blur.toDouble() : 0,
    spreadRadius: spread is num ? spread.toDouble() : 0,
    offset: Offset(dx, dy),
  );
}
