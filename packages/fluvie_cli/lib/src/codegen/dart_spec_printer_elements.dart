part of 'dart_spec_printer.dart';

/// One scene child: the base element constructor, carrying its `shared` hero
/// anchor when it names one, wrapped in `.animate(...)` when it carries
/// animations, an anchor, or a `show` window (the window prints as the
/// call's `window:` argument, one `MotionTarget` exactly as `buildElement`
/// mounts), and in `Placed` when it carries a `transform` (mirroring
/// `buildElement`). ElementId preserves ids and lanes in ordinary Flutter code.
String _element(Map<String, Object?> element, _Anchors anchors) {
  final base = _sharedArg(element, _elementBase(element, anchors), anchors);
  final animate = element['animate'];
  final animations = animate is List
      ? [for (final entry in animate) _animation(_map(entry), anchors)]
      : const <String>[];
  final anchorId = element['anchor'];
  final anchorVar = anchorId is String ? anchors.variableFor(anchorId) : null;
  final show = element['show'];
  final window = show == null ? null : _showWindow(_map(show));
  var code = _effectsArg(element['effects'], base);
  if (animations.isNotEmpty || anchorVar != null || window != null) {
    final args = _args([
      '[${animations.join(', ')}]',
      if (anchorVar != null) 'anchor: $anchorVar',
      if (window != null) 'window: $window',
    ]);
    code = '$code.animate($args)';
  }
  final transform = element['transform'];
  if (transform != null) {
    code = 'Placed(${_args(['placement: ${_placement(_map(transform))}', 'child: $code'])})';
  }
  final id = element['id'];
  if (id is String) {
    code =
        'ElementId(${_args(['id: ${_str(id)}', if (element['lane'] is String) 'lane: ${_str(element['lane']! as String)}', 'child: $code'])})';
  }
  return code;
}

/// The alive-window `TimeRange` of a `show` object, with an absent bound
/// printed as its default — `Time.zero` for `from`, `1.relative` for `to` —
/// the exact desugaring `show({from, to})` applies.
String _showWindow(Map<String, Object?> show) {
  final from = show['from'];
  final to = show['to'];
  return 'TimeRange('
      '${from == null ? 'Time.zero' : _time(from as String)}, '
      '${to == null ? '1.relative' : _time(to as String)})';
}

/// A `Placement(...)` constructor from a `transform` object, emitting only
/// the fields the JSON carries.
String _placement(Map<String, Object?> transform) =>
    'Placement(${_args([
      'x: ${_num(transform['x'])}',
      'y: ${_num(transform['y'])}',
      if (transform['w'] != null) 'width: ${_num(transform['w'])}',
      if (transform['h'] != null) 'height: ${_num(transform['h'])}',
      if (transform['rotation'] != null) 'rotation: ${_num(transform['rotation'])}',
      if (transform['opacity'] != null) 'opacity: ${_num(transform['opacity'])}',
      if (transform['anchor'] != null) 'anchor: Alignment.${transform['anchor']}',
    ])})';

/// Applies a spec `shared` id to the printed [constructor]: every element
/// widget except Flutter's own `Text` takes a `shared:` parameter, so the
/// declared anchor variable rides the constructor exactly as user code writes
/// it — appended as the final argument, which is safe because every
/// [_elementBase] result is one constructor expression ending in `)`. A `Text`
/// has no such parameter, so it wraps in the public `SharedElement` instead
/// (the same widget `wrapShared` mounts).
String _sharedArg(Map<String, Object?> element, String constructor, _Anchors anchors) {
  final shared = element['shared'];
  if (shared is! String) return constructor;
  final variable = anchors.variableFor(shared);
  if (element['type'] == 'Text' || element['type'] == 'SplitText') {
    return 'SharedElement(anchor: $variable, child: $constructor)';
  }
  final head = constructor.substring(0, constructor.length - 1);
  return head.endsWith('(') ? '${head}shared: $variable)' : '$head, shared: $variable)';
}

// [anchors] declares and names the anchor variables; only props that carry an
// anchor id (today Bars' `track`) read it.
String _elementBase(Map<String, Object?> element, _Anchors anchors) {
  final type = element['type'];
  switch (type) {
    case 'SplitText':
      return 'SplitText(${_args([
        _str(element['text']! as String),
        if (element['by'] != null) 'by: TextSplit.${element['by']}',
        if (element['style'] != null) 'style: ${_textStyle(_map(element['style']))}',
        if (element['textAlign'] != null) 'textAlign: TextAlign.${element['textAlign']}',
        if (element['maxLines'] != null) 'maxLines: ${element['maxLines']}',
      ])})';
    case 'Text':
      return _textElement(element);
    case 'Typewriter':
      return 'Typewriter(${_args([
        _str(element['text']! as String),
        if (element['speed'] != null) 'speed: ${_time(element['speed']! as String)}',
        if (element['caret'] == true) 'caret: true',
        if (element['style'] != null) 'style: ${_textStyle(_map(element['style']))}',
      ])})';
    case 'Markdown':
      return 'Markdown(${_args([
        _str(element['source']! as String),
        if (element['reveal'] != null) 'reveal: ${_time(element['reveal']! as String)}',
      ])})';
    case 'Box':
      return 'Box(${_args([
        if (element['color'] != null) 'color: ${_color(element['color'])}',
        if (element['size'] != null) 'size: ${_size(_map(element['size']))}',
        if (element['decoration'] != null) 'decoration: ${_decoration(_map(element['decoration']))}',
      ])})';
    case 'Image':
      return _image(element);
    case 'Shape':
      return _shapeElement(element);
    case 'Arrow':
      return _arrowElement(element);
    case 'Connector':
      return _connectorElement(element);
    case 'Clip':
      return _clipElement(element);
    case 'Counter':
      final counterArgs = _args([
        'to: ${_num(element['to'])}',
        if (element['variant'] == 'currency' && element['symbol'] != null)
          'symbol: ${_str(element['symbol']! as String)}',
        if (element['from'] != null) 'from: ${_num(element['from'])}',
        if (element['reveal'] != null) 'reveal: ${_time(element['reveal']! as String)}',
        if (element['ease'] != null) 'ease: ${_ease(element['ease'])}',
        if (element['style'] != null) 'style: ${_textStyle(_map(element['style']))}',
      ]);
      return switch (element['variant']) {
        null => 'Counter($counterArgs)',
        'currency' => 'Counter.currency($counterArgs)',
        'percent' => 'Counter.percent($counterArgs)',
        final variant => throw FormatException('Unknown counter variant "$variant"'),
      };
    case 'Terminal':
      return _terminalElement(element);
    case 'Code':
      return _codeElement(element);
    case 'Chart':
      return _chartElement(element);
    case 'Mermaid':
      return _mermaidElement(element);
    case 'WebView':
      return _webViewElement(element);
    case 'Html':
      return _htmlElement(element);
    case 'Bars':
      return _barsElement(element, anchors);
    case 'LowerThird':
      return _lowerThirdElement(element, anchors);
    case 'TitleCard':
      return _titleCardElement(element, anchors);
    case 'Snapshot':
      return _snapshotElement(element, anchors);
    case 'DeviceFrame':
      return _deviceFrameElement(element, anchors);
    case 'Callout':
      return _calloutElement(element, anchors);
    case 'Spotlight':
      return _spotlightElement(element, anchors);
    case 'Group':
      return _groupElement(element, anchors);
  }
  throw FormatException('Unknown element "$type"');
}

String _image(Map<String, Object?> element) {
  final source = _map(element['source']);
  final value = _str(source['value']! as String);
  final args = _args([
    value,
    if (element['fit'] != null) 'fit: ${_enumValue('BoxFit', element['fit']! as String)}',
    _numArg('cornerRadius', element['cornerRadius']),
    if (element['crop'] != null) 'crop: ${_rectLiteral(element['crop'])}',
    if (element['frame'] != null) 'frame: ${_photoFrame(_map(element['frame']))}',
  ]);
  // A bundle value is relative to the .fluvie bundle and prints as the asset
  // form: the printed program runs when the bundle's media folder ships as
  // project assets.
  return switch (source['kind']) {
    'asset' || 'bundle' => 'Image.asset($args)',
    'network' => 'Image.network($args)',
    'file' => 'Image.file($args)',
    _ => throw FormatException('Unknown image source kind "${source['kind']}"'),
  };
}

String _size(Map<String, Object?> size) => 'Size(${_num(size['width'])}, ${_num(size['height'])})';
