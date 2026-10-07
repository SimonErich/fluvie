part of 'element_builder.dart';

// [anchors] is the document's shared table: any prop that names a timeline
// (today only Bars' `track`) must resolve through it so anchor identity
// survives serialization.
Widget _base(ElementSpec spec, AnchorTable anchors) {
  final props = spec.props;
  switch (spec.type) {
    case 'SplitText':
      return SplitText(
        _string(props['text'], 'text'),
        by: props['by'] == null
            ? TextSplit.word
            : decodeEnum(TextSplit.values, props['by'], 'text split', path: const ['by']),
        style: props['style'] == null
            ? null
            : decodeTextStyle(props['style'], path: const ['style']),
        textAlign: props['textAlign'] == null
            ? TextAlign.start
            : decodeEnum(
                TextAlign.values,
                props['textAlign'],
                'textAlign',
                path: const ['textAlign'],
              ),
        maxLines: _maybeInt(props['maxLines'], 'maxLines'),
      );
    case 'Text':
      return _text(props);
    case 'Typewriter':
      return Typewriter(
        _string(props['text'], 'text'),
        speed: props['speed'] == null
            ? const Time.frames(2)
            : decodeTime(props['speed'], path: const ['speed']),
        caret: _boolOr(props['caret'], false, 'caret'),
        style: props['style'] == null
            ? null
            : decodeTextStyle(props['style'], path: const ['style']),
      );
    case 'Markdown':
      return Markdown(
        _string(props['source'], 'source'),
        reveal: props['reveal'] == null
            ? null
            : decodeTime(props['reveal'], path: const ['reveal']),
      );
    case 'Box':
      if (props['color'] != null && props['decoration'] != null) {
        throw FluvieSpecError(
          'A Box takes "color" or "decoration", not both; put the color '
          'inside the decoration',
          path: const ['decoration'],
        );
      }
      return Box(
        color: props['color'] == null ? null : decodeColor(props['color'], path: const ['color']),
        size: _size(props['size']),
        decoration: props['decoration'] == null
            ? null
            : decodeBoxDecoration(props['decoration'], path: const ['decoration']),
      );
    case 'Image':
      return _image(props);
    // The annotations paint in scene pixels, so their box must BE the scene
    // (or the placed rect): expanded, the painter origin is the box origin.
    case 'Shape':
      return SizedBox.expand(child: _shape(props));
    case 'Arrow':
      return SizedBox.expand(child: _arrow(props));
    case 'Connector':
      return SizedBox.expand(child: _connector(props));
    case 'Clip':
      return _clip(props);
    case 'Counter':
      return _counter(props);
    case 'Terminal':
      return _terminalElement(props);
    case 'Code':
      return _codeElement(props);
    case 'Chart':
      return _chartElement(props);
    case 'Mermaid':
      return _mermaidElement(props);
    case 'WebView':
      return _webViewElement(props);
    case 'Html':
      return _htmlElement(props);
    case 'Bars':
      return _bars(props, anchors);
    case 'LowerThird':
      return _lowerThird(props, anchors);
    case 'TitleCard':
      return _titleCard(props, anchors);
    case 'Snapshot':
      return _snapshot(props, anchors);
    case 'DeviceFrame':
      return _deviceFrame(props, anchors);
    case 'Callout':
      return _callout(props, anchors);
    case 'Spotlight':
      return _spotlight(props, anchors);
    case 'Group':
      return _group(props, anchors);
  }
  // coverage:ignore-line unreachable ElementSpec fromJson validates the type before this dispatch
  throw FluvieSpecError('Unknown element "${spec.type}"');
}
