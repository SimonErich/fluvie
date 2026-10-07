/// @docImport 'package:fluvie/src/serialization/element_builder.dart';
library;

/// The element vocabulary of the spec: which types exist and which content
/// properties each one reads — the single source of truth shared by the
/// parser's unknown-property check and `videoSpecSchema`; it must stay in step
/// with what [buildElement] actually reads in `element_builder.dart`.

/// The element types the spec can build.
const Set<String> knownElementTypes = {
  'Text',
  'SplitText',
  'Box',
  'Image',
  'Counter',
  'Shape',
  'Arrow',
  'Connector',
  'Clip',
  'Typewriter',
  'Markdown',
  'Terminal',
  'Code',
  'Chart',
  'Mermaid',
  'WebView',
  'Html',
  'Bars',
  'LowerThird',
  'TitleCard',
  'Snapshot',
  'DeviceFrame',
  'Callout',
  'Spotlight',
  'Group',
};

/// The content properties each element type reads, beyond the reserved keys
/// (`type`, `anchor`, `animate`). This is the single source of truth shared by
/// the parser's unknown-property check and `videoSpecSchema`; it must stay in
/// step with what `buildElement` actually reads in `element_builder.dart`.
const Map<String, Set<String>> knownElementProps = {
  'Text': {'text', 'spans', 'style', 'textAlign', 'maxLines', 'decoration', 'padding', 'maxWidth'},
  'SplitText': {'text', 'by', 'style', 'textAlign', 'maxLines'},
  'Typewriter': {'text', 'speed', 'caret', 'style'},
  'Markdown': {'source', 'reveal'},
  'Terminal': {'lines', 'prompt', 'chrome', 'typingSpeed', 'lineGap', 'style'},
  'Chart': {'variant', 'data', 'series', 'points', 'reveal', 'stagger', 'innerRadius'},
  'Mermaid': {'source', 'theme', 'reveal', 'fit'},
  'WebView': {'uri', 'viewport', 'scroll', 'clip', 'fit'},
  'Html': {'source', 'viewport', 'fit'},
  'Bars': {'count', 'band', 'gain', 'track'},
  'LowerThird': {'name', 'title', 'reveal', 'color', 'child'},
  'TitleCard': {'title', 'subtitle', 'reveal', 'color', 'child'},
  'Snapshot': {'child', 'fit'},
  'DeviceFrame': {'variant', 'child', 'notch', 'url'},
  'Callout': {'label', 'target', 'child', 'labelAt', 'color'},
  'Spotlight': {'region', 'child', 'reveal', 'color'},
  'Code': {
    'source',
    'after',
    'language',
    'theme',
    'reveal',
    'focusLines',
    'highlightLines',
    'style',
  },
  'Box': {'color', 'size', 'decoration'},
  'Image': {'source', 'fit', 'cornerRadius', 'crop', 'frame'},
  'Counter': {'to', 'from', 'reveal', 'ease', 'variant', 'symbol', 'style'},
  'Shape': {
    'kind',
    'from',
    'to',
    'rect',
    'center',
    'radius',
    'path',
    'color',
    'strokeWidth',
    'reveal',
  },
  'Arrow': {'from', 'to', 'color', 'strokeWidth', 'headLength', 'reveal'},
  'Connector': {'from', 'to', 'elbow', 'color', 'strokeWidth', 'reveal'},
  'Clip': {'source', 'trim', 'fit', 'volume', 'automation', 'fadeIn', 'fadeOut', 'poster', 'speed'},
  'Group': {'children'},
};
