part of 'dart_spec_printer.dart';

/// A `Shape.<kind>(...)` constructor, mirroring `_shape` in fluvie's builder.
String _shapeElement(Map<String, Object?> element) {
  final shared = <String?>[
    if (element['color'] != null) 'color: ${_color(element['color'])}',
    _numArg('strokeWidth', element['strokeWidth']),
    if (element['reveal'] != null) 'reveal: ${_time(element['reveal']! as String)}',
  ];
  return switch (element['kind']) {
    'line' =>
      'Shape.line(${_args([
        'from: ${_point(element['from'])}',
        'to: ${_point(element['to'])}',
        ...shared,
      ])})',
    'rect' => 'Shape.rect(${_args(['rect: ${_rectLiteral(element['rect'])}', ...shared])})',
    'circle' =>
      'Shape.circle(${_args([
        'center: ${_point(element['center'])}',
        _numArg('radius', element['radius']),
        ...shared,
      ])})',
    'path' =>
      'Shape.path(${_args([
        'path: pathFromSvg(${_str(element['path']! as String)})',
        ...shared,
      ])})',
    _ => throw FormatException('Unknown Shape kind "${element['kind']}"'),
  };
}

/// An `Arrow.to(...)` constructor.
String _arrowElement(Map<String, Object?> element) =>
    'Arrow.to(${_args([
      'from: ${_point(element['from'])}',
      'to: ${_point(element['to'])}',
      if (element['color'] != null) 'color: ${_color(element['color'])}',
      _numArg('strokeWidth', element['strokeWidth']),
      _numArg('headLength', element['headLength']),
      if (element['reveal'] != null) 'reveal: ${_time(element['reveal']! as String)}',
    ])})';

/// A `Connector(...)` constructor.
String _connectorElement(Map<String, Object?> element) =>
    'Connector(${_args([
      'from: ${_point(element['from'])}',
      'to: ${_point(element['to'])}',
      if (element['elbow'] == true) 'elbow: true',
      if (element['color'] != null) 'color: ${_color(element['color'])}',
      _numArg('strokeWidth', element['strokeWidth']),
      if (element['reveal'] != null) 'reveal: ${_time(element['reveal']! as String)}',
    ])})';

/// A `Clip.<kind>(...)` constructor with trim, fit, audio policy, speed, and
/// poster.
/// A bundle source prints as the asset form (the bundle's media folder ships
/// as project assets), like every other printed bundle value.
String _clipElement(Map<String, Object?> element) {
  final source = _map(element['source']);
  final value = source['value']! as String;
  final args = _args([
    switch (source['kind']) {
      'asset' || 'file' || 'bundle' => _str(value),
      'network' => 'Uri.parse(${_str(value)})',
      _ => throw FormatException('Unknown clip source kind "${source['kind']}"'),
    },
    if (element['trim'] != null) 'trim: ${_trimRange(_map(element['trim']))}',
    if (element['fit'] != null) 'fit: ${_enumValue('BoxFit', element['fit']! as String)}',
    if (_clipAudioPolicy(element) case final String policy) 'audio: $policy',
    if (element['poster'] != null) 'poster: ${_mediaSourceLiteral(_map(element['poster']))}',
    if (element['speed'] is Map<String, Object?>)
      'speedRamp: ${_keyframed(element['speed']! as Map<String, Object?>)}'
    else
      _numArg('speed', element['speed']),
  ]);
  return switch (source['kind']) {
    'asset' || 'bundle' => 'Clip.asset($args)',
    'network' => 'Clip.network($args)',
    _ => 'Clip.file($args)',
  };
}

/// Lane gain scales the complete native policy, including automation.
String? _clipAudioPolicy(Map<String, Object?> element) {
  final gain = _clipLaneMix[element['lane']] ?? 1;
  final volume = element['volume'];
  if (volume is num && volume == 0 || gain == 0) return 'ClipAudio.muted()';
  if (volume == null &&
      element['fadeIn'] == null &&
      element['fadeOut'] == null &&
      element['automation'] == null &&
      gain == 1) {
    return null;
  }
  final included =
      'ClipAudio.included(${_args([
        if (volume is num) 'volume: ${_num(volume)}',
        if (element['automation'] != null) 'automation: ${_audioAutomation(_map(element['automation']))}',
        if (element['fadeIn'] != null) 'fadeIn: ${_time(element['fadeIn']! as String)}',
        if (element['fadeOut'] != null) 'fadeOut: ${_time(element['fadeOut']! as String)}',
      ])})';
  return gain == 1 ? included : '$included.scaledBy(${_num(gain)})';
}

/// A `Bars(...)` constructor; `track` is an anchor id printed as the declared
/// anchor variable (declarations are pre-collected by `_Anchors.collect`).
String _barsElement(Map<String, Object?> element, _Anchors anchors) {
  final track = element['track'];
  return 'Bars(${_args([
    _numArg('count', element['count']),
    if (element['band'] != null) 'band: ${_enumValue('AudioBand', element['band']! as String)}',
    if (track is String) 'track: ${anchors.variableFor(track)}',
    _numArg('gain', element['gain']),
  ])})';
}

/// A `LowerThird(...)` constructor, with its optional nested `child`.
String _lowerThirdElement(Map<String, Object?> element, _Anchors anchors) =>
    'LowerThird(${_args([
      'name: ${_str(element['name']! as String)}',
      if (element['title'] != null) 'title: ${_str(element['title']! as String)}',
      if (element['reveal'] != null) 'reveal: ${_time(element['reveal']! as String)}',
      if (element['color'] != null) 'color: ${_color(element['color'])}',
      if (element['child'] != null) _childArg(element, anchors),
    ])})';

/// A `TitleCard(...)` constructor, with its optional nested `child`.
String _titleCardElement(Map<String, Object?> element, _Anchors anchors) =>
    'TitleCard(${_args([
      'title: ${_str(element['title']! as String)}',
      if (element['subtitle'] != null) 'subtitle: ${_str(element['subtitle']! as String)}',
      if (element['reveal'] != null) 'reveal: ${_time(element['reveal']! as String)}',
      if (element['color'] != null) 'color: ${_color(element['color'])}',
      if (element['child'] != null) _childArg(element, anchors),
    ])})';

/// An `Offset(x, y)` literal from a `{x, y}` object.
String _point(Object? raw) {
  final map = _map(raw);
  return 'Offset(${_num(map['x'])}, ${_num(map['y'])})';
}

/// A `Rect.fromLTWH(...)` literal from an `{x, y, w, h}` object.
String _rectLiteral(Object? raw) {
  final map = _map(raw);
  return 'Rect.fromLTWH('
      '${_num(map['x'])}, ${_num(map['y'])}, ${_num(map['w'])}, ${_num(map['h'])})';
}

/// A `TimeRange(from, to)` literal from a `{from, to}` object.
String _trimRange(Map<String, Object?> trim) =>
    'TimeRange(${_time(trim['from']! as String)}, ${_time(trim['to']! as String)})';

/// A `MediaSource.<kind>(...)` literal from a `{kind, value}` object. A
/// bundle value prints as the asset form, like every printed bundle source.
String _mediaSourceLiteral(Map<String, Object?> source) {
  final value = _str(source['value']! as String);
  return switch (source['kind']) {
    'asset' || 'bundle' => 'MediaSource.asset($value)',
    'network' => 'MediaSource.network(Uri.parse($value))',
    'file' => 'MediaSource.file($value)',
    _ => throw FormatException('Unknown media source kind "${source['kind']}"'),
  };
}

/// A `PhotoFrame.<style>(...)` literal from a `{style, ...}` object.
String _photoFrame(Map<String, Object?> frame) => switch (frame['style']) {
  'none' => 'PhotoFrame.none()',
  'rounded' => 'PhotoFrame.rounded(${_args([_numArg('radius', frame['radius'])])})',
  'card' =>
    'PhotoFrame.card(${_args([
      _numArg('radius', frame['radius']),
      _numArg('elevation', frame['elevation']),
    ])})',
  'polaroid' =>
    'PhotoFrame.polaroid(${_args([
      if (frame['caption'] != null) 'caption: ${_str(frame['caption']! as String)}',
    ])})',
  _ => throw FormatException('Unknown frame style "${frame['style']}"'),
};
