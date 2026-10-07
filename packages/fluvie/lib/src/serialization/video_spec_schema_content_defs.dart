/// Builds the `$defs` entries for the content-element shapes (terminal lines
/// and chrome, the code reveal union), spread into `buildSpecDefs` so the
/// schema's vocabulary stays one map while each family keeps its own file.
Map<String, Object?> buildContentDefs() => {
  'terminalLine': {
    'description': 'One terminal line: a typed command or a block of streamed output.',
    'oneOf': [
      {
        'type': 'object',
        'required': ['cmd'],
        'additionalProperties': false,
        'properties': {
          'cmd': {'type': 'string'},
          'prompt': {'type': 'string'},
        },
      },
      {
        'type': 'object',
        'required': ['out'],
        'additionalProperties': false,
        'properties': {
          'out': {'type': 'string'},
        },
      },
    ],
  },
  'terminalChrome': {
    'type': 'object',
    'additionalProperties': false,
    'description': 'The optional terminal window bar: a title and the traffic-light dots.',
    'properties': {
      'title': {'type': 'string'},
      'showDots': {'type': 'boolean'},
    },
  },
  'mermaidReveal': {
    'description':
        'How an (experimental) Mermaid diagram reveals: all at once, fading '
        'its nodes in, or drawing its edges in over a window.',
    'oneOf': [
      {
        'type': 'object',
        'required': ['kind'],
        'additionalProperties': false,
        'properties': {
          'kind': {'const': 'none'},
        },
      },
      {
        'type': 'object',
        'required': ['kind', 'window'],
        'additionalProperties': false,
        'properties': {
          'kind': {
            'type': 'string',
            'enum': ['fadeNodes', 'drawEdges'],
          },
          'window': {r'$ref': r'#/$defs/time'},
        },
      },
    ],
  },
  'viewport': {
    'type': 'object',
    'required': ['width', 'height'],
    'additionalProperties': false,
    'description':
        'The fixed pixel box an (experimental) WebView/Html snapshot is laid '
        'out and captured in.',
    'properties': {
      'width': {'type': 'integer', 'minimum': 1},
      'height': {'type': 'integer', 'minimum': 1},
      'deviceScale': {'type': 'number', 'exclusiveMinimum': 0},
    },
  },
  'chartSeries': {
    'type': 'object',
    'required': ['name'],
    'additionalProperties': false,
    'description':
        'One named chart series: a category-to-value "data" map or a "points" '
        'list (exactly one), with an optional color.',
    'properties': {
      'name': {'type': 'string'},
      'color': {r'$ref': r'#/$defs/color'},
      'data': {
        'type': 'object',
        'additionalProperties': {'type': 'number'},
      },
      'points': {
        'type': 'array',
        'items': {r'$ref': r'#/$defs/chartPoint'},
      },
    },
  },
  'chartPoint': {
    'type': 'object',
    'required': ['x', 'y'],
    'additionalProperties': false,
    'description': 'One (x, y) sample in data units, with an optional label.',
    'properties': {
      'x': {'type': 'number'},
      'y': {'type': 'number'},
      'label': {'type': 'string'},
    },
  },
  'codeReveal': {
    'description': 'How code appears: all at once, glyph by glyph, or line by line.',
    'oneOf': [
      {
        'type': 'object',
        'required': ['kind'],
        'additionalProperties': false,
        'properties': {
          'kind': {'const': 'instant'},
        },
      },
      {
        'type': 'object',
        'required': ['kind', 'speed'],
        'additionalProperties': false,
        'properties': {
          'kind': {'const': 'typing'},
          'speed': {r'$ref': r'#/$defs/time'},
        },
      },
      {
        'type': 'object',
        'required': ['kind', 'perLine'],
        'additionalProperties': false,
        'properties': {
          'kind': {'const': 'lineByLine'},
          'perLine': {r'$ref': r'#/$defs/time'},
        },
      },
    ],
  },
  'decoration': {
    'type': 'object',
    'additionalProperties': false,
    'description': 'A Box fill: color, corner radius, border, gradient, shadow.',
    'properties': {
      'color': {r'$ref': r'#/$defs/color'},
      'cornerRadius': {'type': 'number'},
      'border': {
        'type': 'object',
        'additionalProperties': false,
        'properties': {
          'color': {r'$ref': r'#/$defs/color'},
          'width': {'type': 'number'},
        },
      },
      'gradient': {
        'type': 'object',
        'required': ['colors'],
        'additionalProperties': false,
        'properties': {
          'colors': {
            'type': 'array',
            'minItems': 2,
            'items': {r'$ref': r'#/$defs/color'},
          },
          'stops': {
            'type': 'array',
            'items': {'type': 'number', 'minimum': 0, 'maximum': 1},
          },
          'begin': {r'$ref': r'#/$defs/alignment'},
          'end': {r'$ref': r'#/$defs/alignment'},
        },
      },
      'shadow': {
        'type': 'object',
        'additionalProperties': false,
        'properties': {
          'color': {r'$ref': r'#/$defs/color'},
          'blur': {'type': 'number'},
          'spread': {'type': 'number'},
          'offset': {r'$ref': r'#/$defs/point'},
        },
      },
    },
  },
};
