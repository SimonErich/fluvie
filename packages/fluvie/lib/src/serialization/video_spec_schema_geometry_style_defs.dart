part of 'video_spec_schema_defs.dart';

// Scalar, geometry and text-style schema vocabulary.
Map<String, Object?> _buildGeometryStyleDefs() => {
  'time': {
    'type': 'string',
    'description': 'A unit-tagged duration: "2s", "30f", "500ms", "0.3r", or "0.2r@0.8s".',
  },
  'dimensions': {
    'type': 'object',
    'required': ['width', 'height'],
    'additionalProperties': false,
    'properties': {
      'width': {'type': 'integer'},
      'height': {'type': 'integer'},
    },
  },
  'size': {
    'type': 'object',
    'required': ['width', 'height'],
    'additionalProperties': false,
    'description': 'A Box size: each side is a fraction of the parent from 0 to 1.',
    'properties': {
      'width': {'type': 'number', 'minimum': 0, 'maximum': 1},
      'height': {'type': 'number', 'minimum': 0, 'maximum': 1},
    },
  },
  'textStyle': {
    'type': 'object',
    'additionalProperties': false,
    'description':
        'A text style; an optional "token" adopts a type-scale entry whole, '
        'with sibling literal fields winning per field.',
    'properties': {
      'token': {'type': 'string', 'description': 'A type-scale reference the style is based on.'},
      ..._textStyleProps(),
    },
  },
  'textStyleLiteral': {
    'type': 'object',
    'additionalProperties': false,
    'description': 'A fully literal text style (a type-scale entry cannot reference tokens).',
    'properties': _textStyleProps(literalColors: true),
  },
  'textSpan': {
    'type': 'object',
    'additionalProperties': false,
    'required': ['text'],
    'description':
        'One styled run inside a rich Text. A "link" underlines the span and is '
        'carried on its semantics label; spans are never interactive in a render.',
    'properties': {
      'text': {'type': 'string'},
      'style': {r'$ref': r'#/$defs/textStyle'},
      'link': {'type': 'string'},
    },
  },
  'imageSource': {
    'type': 'object',
    'required': ['kind', 'value'],
    'additionalProperties': false,
    'description':
        'One declared media origin. A "bundle" value is relative to the .fluvie '
        'bundle holding the document and resolves only inside it.',
    'properties': {
      'kind': {
        'type': 'string',
        'enum': ['asset', 'network', 'file', 'bundle'],
      },
      'value': {'type': 'string'},
    },
  },
  'point': {
    'type': 'object',
    'required': ['x', 'y'],
    'additionalProperties': false,
    'description': 'A canvas position in logical pixels.',
    'properties': {
      'x': {'type': 'number'},
      'y': {'type': 'number'},
    },
  },
  'rect': {
    'type': 'object',
    'required': ['x', 'y', 'w', 'h'],
    'additionalProperties': false,
    'description': 'A rectangle: logical pixels for geometry, 0..1 source fractions for a crop.',
    'properties': {
      'x': {'type': 'number'},
      'y': {'type': 'number'},
      'w': {'type': 'number'},
      'h': {'type': 'number'},
    },
  },
  'trim': {
    'type': 'object',
    'required': ['from', 'to'],
    'additionalProperties': false,
    'description': 'The portion of a clip to play, in source time.',
    'properties': {
      'from': {r'$ref': r'#/$defs/time'},
      'to': {r'$ref': r'#/$defs/time'},
    },
  },
  'show': {
    'type': 'object',
    'additionalProperties': false,
    'minProperties': 1,
    'description':
        "The element's alive-window inside its scene: it appears at \"from\" "
        '(default: the scene start) and disappears at "to" (default: the '
        'scene end). At least one bound is required.',
    'properties': {
      'from': {r'$ref': r'#/$defs/time'},
      'to': {r'$ref': r'#/$defs/time'},
    },
  },
  'frame': {
    'type': 'object',
    'required': ['style'],
    'additionalProperties': false,
    'description': 'A decorative photo frame around an image.',
    'properties': {
      'style': {
        'type': 'string',
        'enum': ['none', 'rounded', 'card', 'polaroid'],
      },
      'radius': {'type': 'number'},
      'elevation': {'type': 'number'},
      'caption': {'type': 'string'},
    },
  },
  'alignment': {
    'description': 'A named alignment, or an explicit {x, y} from -1 to 1.',
    'oneOf': [
      {'type': 'string', 'enum': namedAlignments.keys.toList()},
      {
        'type': 'object',
        'required': ['x', 'y'],
        'additionalProperties': false,
        'properties': {
          'x': {'type': 'number'},
          'y': {'type': 'number'},
        },
      },
    ],
  },
};

/// The shared text-style field vocabulary (the `decodeTextStyle` subset).
/// [literalColors] pins the color to a literal for the type-scale form, where
/// tokens cannot reference tokens.
Map<String, Object?> _textStyleProps({bool literalColors = false}) => {
  'color': {r'$ref': literalColors ? r'#/$defs/colorLiteral' : r'#/$defs/color'},
  'fontSize': {'type': 'number'},
  'fontWeight': {
    'type': 'string',
    'enum': ['normal', 'bold', ...namedFontWeights.keys],
  },
  'fontStyle': {
    'type': 'string',
    'enum': ['normal', 'italic'],
  },
  'fontFamily': {'type': 'string'},
  'letterSpacing': {'type': 'number'},
  'height': {'type': 'number'},
};
