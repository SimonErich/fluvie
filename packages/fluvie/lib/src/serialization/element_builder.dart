import 'package:flutter/widgets.dart' show BoxFit, Size, Text, Widget;
import 'package:fluvie/src/animation/animate_extension.dart';
import 'package:fluvie/src/animation/animation.dart';
import 'package:fluvie/src/composition/box.dart';
import 'package:fluvie/src/core/errors/fluvie_spec_error.dart';
import 'package:fluvie/src/core/time.dart';
import 'package:fluvie/src/elements/counter.dart';
import 'package:fluvie/src/elements/image.dart';
import 'package:fluvie/src/serialization/anchor_table.dart';
import 'package:fluvie/src/serialization/animation_builder.dart';
import 'package:fluvie/src/serialization/codecs/color_codec.dart';
import 'package:fluvie/src/serialization/codecs/enum_codec.dart';
import 'package:fluvie/src/serialization/codecs/text_style_codec.dart';
import 'package:fluvie/src/serialization/codecs/time_codec.dart';
import 'package:fluvie/src/serialization/element_spec.dart';

/// Builds a real widget from an [ElementSpec], wrapping it in `.animate(...)`
/// when it has animations or an anchor.
Widget buildElement(ElementSpec spec, AnchorTable anchors) {
  final base = _base(spec);
  final animations = <Animation>[for (final animation in spec.animate) buildAnimation(animation)];
  final anchorId = spec.anchor;
  final anchor = anchorId == null ? null : anchors.resolve(anchorId);
  if (animations.isEmpty && anchor == null) return base;
  return base.animate(animations, anchor: anchor);
}

Widget _base(ElementSpec spec) {
  final props = spec.props;
  switch (spec.type) {
    case 'Text':
      return Text(
        _string(props['text'], 'text'),
        style: props['style'] == null
            ? null
            : decodeTextStyle(props['style'], path: const ['style']),
      );
    case 'Box':
      return Box(
        color: props['color'] == null ? null : decodeColor(props['color'], path: const ['color']),
        size: _size(props['size']),
      );
    case 'Image':
      return _image(props);
    case 'Counter':
      return Counter(
        to: _num(props['to'], 'to'),
        from: _numOr(props['from'], 0),
        reveal: props['reveal'] == null
            ? const Time.seconds(1)
            : decodeTime(props['reveal'], path: const ['reveal']),
        style: props['style'] == null
            ? null
            : decodeTextStyle(props['style'], path: const ['style']),
      );
  }
  // Defensive: ElementSpec.fromJson validates the type, so this is unreachable.
  throw FluvieSpecError('Unknown element "${spec.type}"'); // coverage:ignore-line
}

Widget _image(Map<String, Object?> props) {
  final source = props['source'];
  if (source is! Map<String, Object?>) {
    throw FluvieSpecError('An Image needs a "source" object', path: const ['source']);
  }
  final value = source['value'];
  if (value is! String) {
    throw FluvieSpecError(
      'An image source needs a string "value"',
      path: const ['source', 'value'],
    );
  }
  final fit = props['fit'] == null
      ? null
      : decodeEnum(BoxFit.values, props['fit'], 'fit', path: const ['fit']);
  return switch (source['kind']) {
    'asset' => Image.asset(value, fit: fit),
    'network' => Image.network(value, fit: fit),
    'file' => Image.file(value, fit: fit),
    _ => throw FluvieSpecError(
      'Unknown image source kind "${source['kind']}"',
      path: const ['source', 'kind'],
    ),
  };
}

String _string(Object? raw, String field) {
  if (raw is String) return raw;
  throw FluvieSpecError('Expected a string "$field"', path: [field]);
}

Size? _size(Object? raw) {
  if (raw == null) return null;
  if (raw is Map<String, Object?>) {
    final width = raw['width'];
    final height = raw['height'];
    if (width is num && height is num) return Size(width.toDouble(), height.toDouble());
  }
  throw FluvieSpecError('Expected a size {width, height}', path: const ['size']);
}

num _num(Object? raw, String field) {
  if (raw is num) return raw;
  throw FluvieSpecError('Expected a number "$field"', path: [field]);
}

num _numOr(Object? raw, num fallback) => raw is num ? raw : fallback;
