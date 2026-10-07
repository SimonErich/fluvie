part of 'spec_validation.dart';

/// The element keys [ElementSpec.fromJson] reserves; mirror of its private set.
Set<String> get _reservedElementKeys => ElementSpec.reservedElementKeys;

/// Text-style fields (the `decodeTextStyle` subset): the contents of a `"style"`
/// object, also used to hint when one is mistakenly placed at the top level of a
/// `Text`/`Counter`.
const Set<String> _styleFields = {
  'color',
  'fontSize',
  'fontWeight',
  'fontStyle',
  'fontFamily',
  'letterSpacing',
  'height',
};

/// A style object on an element or span: the literal fields plus an optional
/// type-scale `token` base (a type-scale entry itself stays literal-only).
const Set<String> _styleOrTokenFields = {'token', ..._styleFields};

/// The element types whose `style` is the curated text-style subset.
const Set<String> _styledTypes = {'Text', 'SplitText', 'Counter', 'Typewriter', 'Terminal', 'Code'};

/// The closed nested object shapes, mirrored from the codecs: a `Box` `size`
/// ({width, height}), an `Image` `source` ({kind, value}), a `Terminal` line
/// and chrome, and a `Code` reveal union.
const Set<String> _sizeFields = {'width', 'height'};
const Set<String> _sourceFields = {'kind', 'value'};
const Set<String> _trimFields = {'from', 'to'};
const Set<String> _showFields = {'from', 'to'};
const Set<String> _frameFields = {'style', 'radius', 'elevation', 'caption'};
const Set<String> _terminalLineFields = {'cmd', 'prompt', 'out'};
const Set<String> _terminalChromeFields = {'title', 'showDots'};
const Set<String> _codeRevealFields = {'kind', 'speed', 'perLine'};
const Set<String> _staggerFields = {'each', 'evenly', 'from', 'gap'};
const Set<String> _chartSeriesFields = {'name', 'color', 'data', 'points'};
const Set<String> _chartPointFields = {'x', 'y', 'label'};
const Set<String> _mermaidRevealFields = {'kind', 'window'};
const Set<String> _viewportFields = {'width', 'height', 'deviceScale'};
const Set<String> _textSpanFields = {'text', 'style', 'link'};

/// One element's unknown-property sweep: the top-level content props against
/// [knownElementProps], then each curated nested object as a closed shape.
void _checkElement(Map<String, Object?> json, List<String> path, List<FluvieSpecWarning> out) {
  final type = json['type'];
  if (type is! String) return; // Absent/non-string type: the parser reports it.
  if (type == 'Placeholder') {
    out.add(
      FluvieSpecWarning(
        'A Placeholder is legal only inside a master\'s "children"; '
        'a scene fills its slots through "fills"',
        path: path,
      ),
    );
    return;
  }
  final allowedProps = knownElementProps[type];
  if (allowedProps == null) return; // Unknown type: the parser reports it.
  final allowed = {..._reservedElementKeys, ...allowedProps};
  for (final key in json.keys) {
    if (allowed.contains(key)) continue;
    out.add(FluvieSpecWarning(_message(key, 'a $type', allowedProps, type), path: path));
  }
  _checkEffects(json['effects'], path, out);
  // The curated nested objects are closed shapes too: a typo inside style/size/
  // source is dropped by the codec, so check one level deeper.
  _checkNested(json, 'transform', knownPlacementKeys, 'a transform', path, out);
  _checkNested(json, 'show', _showFields, 'a show window', path, out);
  _checkAnimations(json, path, out);
  if (_styledTypes.contains(type)) {
    _checkNested(json, 'style', _styleOrTokenFields, 'a text style', path, out);
  }
  if (type == 'Text') {
    _checkSpans(json, path, out);
    _checkDecoration(json, path, out);
    _checkNested(json, 'padding', {'horizontal', 'vertical'}, 'text padding', path, out);
  }
  if (type == 'Box') {
    _checkNested(json, 'size', _sizeFields, 'a Box size', path, out);
    _checkDecoration(json, path, out);
  } else if (type == 'Image') {
    _checkNested(json, 'source', _sourceFields, 'an image source', path, out);
    _checkNested(json, 'crop', knownRectKeys, 'an image crop', path, out);
    _checkNested(json, 'frame', _frameFields, 'an image frame', path, out);
  } else if (type == 'Clip') {
    _checkNested(json, 'source', _sourceFields, 'a clip source', path, out);
    _checkNested(json, 'poster', _sourceFields, 'a clip poster', path, out);
    _checkNested(json, 'trim', _trimFields, 'a clip trim', path, out);
  } else if (type == 'Shape' || type == 'Arrow' || type == 'Connector') {
    _checkNested(json, 'from', knownOffsetKeys, 'a point', path, out);
    _checkNested(json, 'to', knownOffsetKeys, 'a point', path, out);
    _checkNested(json, 'center', knownOffsetKeys, 'a point', path, out);
    _checkNested(json, 'rect', knownRectKeys, 'a rect', path, out);
  } else if (type == 'Terminal') {
    _checkNested(json, 'chrome', _terminalChromeFields, 'a terminal chrome', path, out);
    _checkEachNested(json, 'lines', _terminalLineFields, 'a terminal line', path, out);
  } else if (type == 'Code') {
    _checkNested(json, 'reveal', _codeRevealFields, 'a code reveal', path, out);
  } else if (type == 'Chart') {
    _checkChart(json, path, out);
  } else if (type == 'Mermaid') {
    _checkNested(json, 'reveal', _mermaidRevealFields, 'a mermaid reveal', path, out);
  } else if (type == 'WebView') {
    _checkNested(json, 'viewport', _viewportFields, 'a viewport', path, out);
    _checkNested(json, 'scroll', knownOffsetKeys, 'a point', path, out);
    _checkNested(json, 'clip', knownRectKeys, 'a rect', path, out);
  } else if (type == 'Html') {
    _checkNested(json, 'viewport', _viewportFields, 'a viewport', path, out);
  } else if (type == 'Callout') {
    _checkNested(json, 'target', knownOffsetKeys, 'a point', path, out);
    _checkNested(json, 'labelAt', knownOffsetKeys, 'a point', path, out);
  } else if (type == 'Spotlight') {
    _checkNested(json, 'region', knownRectKeys, 'a rect', path, out);
  }
  // A child-bearing type nests one full element; recurse so a typo inside the
  // child (at any depth) reports with its full path.
  if (allowedProps.contains('child')) {
    final child = json['child'];
    if (child is Map<String, Object?>) _checkElement(child, [...path, 'child'], out);
  }
  // A Group nests a whole element list; recurse into every entry the same way.
  if (type == 'Group') _checkGroupChildren(json, path, out);
}

/// A `Group`'s nested elements: each entry of `children` is one full element,
/// checked recursively so a typo at any depth reports with its full path.
void _checkGroupChildren(
  Map<String, Object?> json,
  List<String> path,
  List<FluvieSpecWarning> out,
) {
  final children = json['children'];
  if (children is! List) return; // Wrong type: the builder reports it.
  for (var i = 0; i < children.length; i++) {
    final child = children[i];
    if (child is! Map<String, Object?>) continue;
    _checkElement(child, [...path, 'children', '$i'], out);
  }
}
