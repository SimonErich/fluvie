import 'package:flutter/painting.dart' show Alignment;
import 'package:fluvie/src/core/errors/fluvie_spec_error.dart';
import 'package:fluvie/src/core/keyframe.dart';
import 'package:fluvie/src/serialization/codecs/alignment_codec.dart';
import 'package:fluvie/src/serialization/codecs/color_codec.dart';

/// The JSON form of a [Keyframe]: an object carrying only the overridden
/// (non-null) fields, plus `origin` when it is not the default center.
Map<String, Object?> encodeKeyframe(Keyframe keyframe) => {
  if (keyframe.opacity != null) 'opacity': keyframe.opacity,
  if (keyframe.x != null) 'x': keyframe.x,
  if (keyframe.y != null) 'y': keyframe.y,
  if (keyframe.scale != null) 'scale': keyframe.scale,
  if (keyframe.scaleX != null) 'scaleX': keyframe.scaleX,
  if (keyframe.scaleY != null) 'scaleY': keyframe.scaleY,
  if (keyframe.rotation != null) 'rotation': keyframe.rotation,
  if (keyframe.skewX != null) 'skewX': keyframe.skewX,
  if (keyframe.skewY != null) 'skewY': keyframe.skewY,
  if (keyframe.blur != null) 'blur': keyframe.blur,
  if (keyframe.color != null) 'color': encodeColor(keyframe.color!),
  if (keyframe.origin != Alignment.center) 'origin': encodeAlignment(keyframe.origin),
};

/// Reads a [Keyframe] from an object in [raw]; absent fields stay null
/// ("leave natural"), and an absent `origin` defaults to [Alignment.center].
///
/// Throws a [FluvieSpecError] (located at [path]) when [raw] is not an object.
Keyframe decodeKeyframe(Object? raw, {List<String> path = const []}) {
  if (raw is! Map<String, Object?>) {
    throw FluvieSpecError('Expected a keyframe object', path: path);
  }
  final color = raw['color'];
  final origin = raw['origin'];
  return Keyframe(
    opacity: _double(raw['opacity']),
    x: _double(raw['x']),
    y: _double(raw['y']),
    scale: _double(raw['scale']),
    scaleX: _double(raw['scaleX']),
    scaleY: _double(raw['scaleY']),
    rotation: _double(raw['rotation']),
    skewX: _double(raw['skewX']),
    skewY: _double(raw['skewY']),
    blur: _double(raw['blur']),
    color: color == null ? null : decodeColor(color, path: [...path, 'color']),
    origin: origin == null ? Alignment.center : decodeAlignment(origin, path: [...path, 'origin']),
  );
}

double? _double(Object? value) => value is num ? value.toDouble() : null;
