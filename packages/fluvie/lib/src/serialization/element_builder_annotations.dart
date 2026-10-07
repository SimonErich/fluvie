part of 'element_builder.dart';

// The annotation builders mirror the widget defaults (Shape/Arrow stroke 3,
// Connector stroke 2, Arrow head 16) the same way the Counter case mirrors
// its one-second reveal.

/// A `Shape` from its spec props: `kind` picks the geometry, the shared
/// draw-on fields ride along.
Widget _shape(Map<String, Object?> props) {
  final color = _colorOrNull(props['color']);
  final strokeWidth = _numOr(props['strokeWidth'], 3).toDouble();
  final reveal = _revealOrNull(props['reveal']);
  switch (props['kind']) {
    case 'line':
      return Shape.line(
        from: _offset(props['from'], 'from'),
        to: _offset(props['to'], 'to'),
        color: color,
        strokeWidth: strokeWidth,
        reveal: reveal,
      );
    case 'rect':
      return Shape.rect(
        rect: _rect(props['rect'], 'rect'),
        color: color,
        strokeWidth: strokeWidth,
        reveal: reveal,
      );
    case 'circle':
      return Shape.circle(
        center: _offset(props['center'], 'center'),
        radius: _num(props['radius'], 'radius').toDouble(),
        color: color,
        strokeWidth: strokeWidth,
        reveal: reveal,
      );
    case 'path':
      final data = props['path'];
      if (data is! String) {
        throw FluvieSpecError('A path Shape needs an SVG "path" string', path: const ['path']);
      }
      try {
        return Shape.path(
          path: pathFromSvg(data),
          color: color,
          strokeWidth: strokeWidth,
          reveal: reveal,
        );
      } on FormatException catch (error) {
        throw FluvieSpecError(error.message, path: const ['path']);
      }
  }
  throw FluvieSpecError(
    'A Shape needs a "kind" of line, rect, circle, or path',
    path: const ['kind'],
  );
}

/// An `Arrow.to` from its spec props.
Widget _arrow(Map<String, Object?> props) => Arrow.to(
  from: _offset(props['from'], 'from'),
  to: _offset(props['to'], 'to'),
  color: _colorOrNull(props['color']),
  strokeWidth: _numOr(props['strokeWidth'], 3).toDouble(),
  headLength: _numOr(props['headLength'], 16).toDouble(),
  reveal: _revealOrNull(props['reveal']),
);

/// A `Connector` from its spec props.
Widget _connector(Map<String, Object?> props) => Connector(
  from: _offset(props['from'], 'from'),
  to: _offset(props['to'], 'to'),
  elbow: props['elbow'] == true,
  color: _colorOrNull(props['color']),
  strokeWidth: _numOr(props['strokeWidth'], 2).toDouble(),
  reveal: _revealOrNull(props['reveal']),
);

/// A `Bars` visualizer from its spec props; `track` names an `Audio.track`
/// anchor and resolves through the document's shared [anchors] table so the
/// spec and the audio pipeline share one identity.
Widget _bars(Map<String, Object?> props, AnchorTable anchors) {
  final track = props['track'];
  if (track != null && track is! String) {
    throw FluvieSpecError('Expected an anchor id string "track"', path: const ['track']);
  }
  return Bars(
    count: _maybeInt(props['count'], 'count') ?? 24,
    band: props['band'] == null
        ? AudioBand.bass
        : decodeEnum(AudioBand.values, props['band'], 'band', path: const ['band']),
    track: track is String ? anchors.resolve(track) : null,
    gain: _numOr(props['gain'], 1.0).toDouble(),
  );
}

/// A `LowerThird` from its spec props, over an optional nested `child`
/// (decoded recursively, like the wrapper elements).
Widget _lowerThird(Map<String, Object?> props, AnchorTable anchors) => LowerThird(
  name: _string(props['name'], 'name'),
  title: props['title'] is String ? props['title']! as String : null,
  reveal: _revealOrNull(props['reveal']),
  color: props['color'] == null
      ? const Color(0xCC101418)
      : decodeColor(props['color'], path: const ['color']),
  child: props['child'] == null ? null : _childElement(props['child'], anchors),
);

/// A `TitleCard` from its spec props, over an optional nested `child`.
Widget _titleCard(Map<String, Object?> props, AnchorTable anchors) => TitleCard(
  title: _string(props['title'], 'title'),
  subtitle: props['subtitle'] is String ? props['subtitle']! as String : null,
  reveal: _revealOrNull(props['reveal']),
  color: props['color'] == null
      ? const Color(0xFFFFFFFF)
      : decodeColor(props['color'], path: const ['color']),
  child: props['child'] == null ? null : _childElement(props['child'], anchors),
);

Offset _offset(Object? raw, String field) {
  if (raw == null) {
    throw FluvieSpecError('Expected a point object "$field" {x, y}', path: [field]);
  }
  return decodeOffset(raw, path: [field]);
}

Rect _rect(Object? raw, String field) {
  if (raw == null) {
    throw FluvieSpecError('Expected a rect object "$field" {x, y, w, h}', path: [field]);
  }
  return decodeRect(raw, path: [field]);
}

Color? _colorOrNull(Object? raw) => raw == null ? null : decodeColor(raw, path: const ['color']);

Time? _revealOrNull(Object? raw) => raw == null ? null : decodeTime(raw, path: const ['reveal']);
