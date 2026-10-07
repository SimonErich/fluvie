part of 'video_spec_schema_variants.dart';

// The per-property schema vocabulary, derived from the same enums and codec
// constants the parser reads so the advertised names cannot drift.

/// The `BoxFit` names a `fit` field accepts, derived from the enum so the schema
/// cannot drift from the codec.
final List<String> _boxFitNames = [for (final fit in BoxFit.values) fit.name];

/// The `TextAlign` names a `textAlign` field accepts, derived from the enum.
final List<String> _textAlignNames = [for (final align in TextAlign.values) align.name];

/// The `AudioBand` names a `band` field accepts, derived from the enum.
final List<String> _audioBandNames = [for (final band in AudioBand.values) band.name];

Object _elementPropSchema(String type, String prop) => switch (prop) {
  'automation' => {r'$ref': r'#/$defs/audioAutomation'},
  'by' when type == 'SplitText' => {
    'type': 'string',
    'enum': ['character', 'word', 'line'],
  },
  'text' => {'type': 'string'},
  'spans' => {
    'type': 'array',
    'minItems': 1,
    'description': 'Styled inline spans; exactly one of "text" or "spans".',
    'items': {r'$ref': r'#/$defs/textSpan'},
  },
  // The wrapper elements nest one full element; recursion through the ref is
  // free in JSON Schema. A Group nests a whole list the same way.
  'child' => {r'$ref': r'#/$defs/element'},
  'children' => {
    'type': 'array',
    'description': "The grouped elements; each child's transform is a fraction of the group's box.",
    'items': {r'$ref': r'#/$defs/element'},
  },
  'variant' when type == 'DeviceFrame' => {
    'type': 'string',
    'enum': ['phone', 'browser', 'tablet'],
  },
  'notch' => {'type': 'boolean', 'description': 'Phone chrome only; defaults on.'},
  'url' => {'type': 'string', 'description': 'Browser chrome only; the address-bar text.'},
  'label' => {'type': 'string'},
  'target' || 'labelAt' => {r'$ref': r'#/$defs/point'},
  'region' => {r'$ref': r'#/$defs/rect'},
  'style' => {r'$ref': r'#/$defs/textStyle'},
  'color' => {r'$ref': r'#/$defs/color'},
  'size' when type == 'Box' => {r'$ref': r'#/$defs/size'},
  // Markdown, Code, Mermaid, and Html carry literal text, not a media reference.
  'source' when type == 'Markdown' || type == 'Code' || type == 'Mermaid' || type == 'Html' => {
    'type': 'string',
  },
  'source' => {r'$ref': r'#/$defs/imageSource'},
  'uri' => {
    'type': 'string',
    'description':
        'An absolute http(s) page URL, captured at the declared viewport '
        '(experimental: needs an injected snapshot service).',
  },
  'viewport' => {r'$ref': r'#/$defs/viewport'},
  'scroll' => {r'$ref': r'#/$defs/point'},
  'clip' => {r'$ref': r'#/$defs/rect'},
  'reveal' when type == 'Mermaid' => {r'$ref': r'#/$defs/mermaidReveal'},
  'lines' => {
    'type': 'array',
    'minItems': 1,
    'items': {r'$ref': r'#/$defs/terminalLine'},
  },
  'prompt' || 'after' || 'language' => {'type': 'string'},
  'chrome' => {r'$ref': r'#/$defs/terminalChrome'},
  'typingSpeed' || 'lineGap' => {r'$ref': r'#/$defs/time'},
  'theme' => {
    'type': 'string',
    'enum': ['dark', 'light'],
  },
  'reveal' when type == 'Code' => {r'$ref': r'#/$defs/codeReveal'},
  'focusLines' || 'highlightLines' => {
    'type': 'array',
    'items': {'type': 'integer', 'minimum': 1},
  },
  'poster' => {r'$ref': r'#/$defs/imageSource'},
  'fit' => {'type': 'string', 'enum': _boxFitNames},
  'textAlign' => {'type': 'string', 'enum': _textAlignNames},
  'padding' => {
    'type': 'object',
    'additionalProperties': false,
    'properties': {
      'horizontal': {'type': 'number', 'minimum': 0},
      'vertical': {'type': 'number', 'minimum': 0},
    },
  },
  'decoration' => {r'$ref': r'#/$defs/decoration'},
  'ease' => {r'$ref': r'#/$defs/ease'},
  'variant' when type == 'Chart' => {
    'type': 'string',
    'enum': ['bar', 'pie', 'donut', 'line', 'area', 'scatter'],
  },
  'variant' => {
    'type': 'string',
    'enum': ['currency', 'percent'],
  },
  'data' => {
    'type': 'object',
    'minProperties': 1,
    'description': 'An ordered category-to-value map.',
    'additionalProperties': {'type': 'number'},
  },
  'series' => {
    'type': 'array',
    'minItems': 1,
    'items': {r'$ref': r'#/$defs/chartSeries'},
  },
  'points' => {
    'type': 'array',
    'minItems': 1,
    'items': {r'$ref': r'#/$defs/chartPoint'},
  },
  'stagger' => {'type': 'object'},
  'innerRadius' => {'type': 'number', 'exclusiveMinimum': 0, 'exclusiveMaximum': 1},
  'count' => {'type': 'integer', 'minimum': 1},
  'band' => {'type': 'string', 'enum': _audioBandNames},
  'gain' => {'type': 'number'},
  'track' => {
    'type': 'string',
    'description':
        'The Audio.track anchor id this element reacts to; omit for the first audible declared track.',
  },
  'name' || 'title' || 'subtitle' => {'type': 'string'},
  'symbol' => {'type': 'string'},
  'fadeIn' || 'fadeOut' => {r'$ref': r'#/$defs/time'},
  'maxWidth' => {'type': 'number', 'exclusiveMinimum': 0},
  'maxLines' => {'type': 'integer', 'minimum': 1},
  // `speed` means two different things: a Clip's playback rate (a number,
  // negative to reverse) and a Typewriter's typing duration (a Time). The
  // switch is keyed on the prop name, so the clip arm has to come first or the
  // rate would inherit the time-string schema.
  'speed' when type == 'Clip' => {
    'oneOf': [
      {
        'type': 'number',
        'not': {'const': 0},
      },
      {
        'allOf': [
          {r'$ref': r'#/$defs/keyframedNumber'},
          {
            'properties': {
              'values': {
                'items': {'type': 'number', 'exclusiveMinimum': 0},
              },
            },
          },
        ],
      },
    ],
    'description':
        'Playback rate: 1 is source speed, 0.5 half, 2 double. '
        'A negative scalar rate plays the trim backwards. Positive keyframed rates integrate source time for a speed ramp.',
  },
  'speed' => {r'$ref': r'#/$defs/time'},
  'caret' => {'type': 'boolean'},
  // Counter counts numbers; the annotations point at canvas positions.
  'to' || 'from' when type == 'Counter' => {'type': 'number'},
  'to' || 'from' || 'center' => {r'$ref': r'#/$defs/point'},
  'reveal' => {r'$ref': r'#/$defs/time'},
  'kind' => {
    'type': 'string',
    'enum': ['line', 'rect', 'circle', 'path'],
  },
  'rect' || 'crop' => {r'$ref': r'#/$defs/rect'},
  'radius' || 'strokeWidth' || 'headLength' || 'cornerRadius' || 'volume' => {'type': 'number'},
  'path' => {
    'type': 'string',
    'description': 'Absolute SVG path data: M, L, H, V, C, Q, Z.',
  },
  'elbow' => {'type': 'boolean'},
  'trim' => {r'$ref': r'#/$defs/trim'},
  'frame' => {r'$ref': r'#/$defs/frame'},
  _ => const <String, Object?>{},
};
