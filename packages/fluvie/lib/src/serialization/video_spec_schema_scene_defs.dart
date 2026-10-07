part of 'video_spec_schema_defs.dart';

// Scene composition, transitions and presentation metadata vocabulary.
Map<String, Object?> _buildSceneDefs() => {
  'defaults': {
    'type': 'object',
    'properties': {
      'duration': {r'$ref': r'#/$defs/time'},
      'ease': {r'$ref': r'#/$defs/ease'},
      'stagger': {'type': 'object'},
    },
  },
  'elementTransition': {
    'type': 'object',
    'required': ['between', 'kind', 'duration'],
    'properties': {
      'between': {
        'type': 'array',
        'minItems': 2,
        'maxItems': 2,
        'items': {'type': 'string'},
      },
      'kind': {'type': 'string'},
      'duration': {r'$ref': r'#/$defs/time'},
      'ease': {r'$ref': r'#/$defs/ease'},
      'overlap': {'type': 'boolean'},
    },
  },
  'transition': {
    'type': 'object',
    'required': ['kind'],
    'properties': {
      'kind': {
        'type': 'string',
        'minLength': 1,
        'description': 'cut, crossFade, wipe, zoom, slide, or a registered custom strategy name',
      },
      'duration': {r'$ref': r'#/$defs/time'},
    },
  },
  'background': {
    'description': 'A scene backdrop: a named kind with its own fields.',
    'oneOf': backgroundVariants(),
  },
  'stepEntry': {
    'type': 'object',
    'required': ['elements'],
    'additionalProperties': false,
    'description':
        'One build step: the scene child ids it reveals. The steps list order '
        'is the step order; children in no step are step 0 and show on entry. '
        'An id appears in at most one step. Only a presentation reads steps; '
        'a rendered video plays straight through.',
    'properties': {
      'elements': {
        'type': 'array',
        'minItems': 1,
        'items': {'type': 'string'},
      },
      'notes': {r'$ref': r'#/$defs/notes'},
    },
  },
  'notes': {
    'type': 'object',
    'additionalProperties': false,
    'description':
        'Speaker notes: the full prose "text" and the glanceable "highlights". '
        "A step's text replaces the scene text while that step is active; its "
        "highlights append to the scene's.",
    'properties': {
      'text': {'type': 'string'},
      'highlights': {
        'type': 'array',
        'items': {'type': 'string'},
      },
    },
  },
  'scene': {
    'type': 'object',
    'required': ['duration'],
    'additionalProperties': false,
    'properties': {
      'duration': {r'$ref': r'#/$defs/time'},
      'background': {r'$ref': r'#/$defs/background'},
      'layout': {
        'type': 'string',
        'enum': ['stack', 'canvas'],
        'description': 'How children arrange: the centered stack (default) or a free canvas.',
      },
      'transitions': {
        'type': 'array',
        'items': {r'$ref': r'#/$defs/elementTransition'},
      },
      'enter': {r'$ref': r'#/$defs/transition'},
      'exit': {r'$ref': r'#/$defs/transition'},
      'motionDefaults': {r'$ref': r'#/$defs/defaults'},
      'master': {
        'type': 'string',
        'description': 'The name of the master layout this scene adopts.',
      },
      'fills': {
        'type': 'object',
        'description':
            "The elements filling the adopted master's slots, keyed by slot "
            "name. A fill's own transform overrides the placeholder's.",
        'propertyNames': {'pattern': r'^[a-zA-Z][a-zA-Z0-9]*$'},
        'additionalProperties': {r'$ref': r'#/$defs/element'},
      },
      'audio': {
        'type': 'array',
        'description': 'Audio tracks scoped to this scene, starting with it.',
        'items': {r'$ref': r'#/$defs/audioTrack'},
      },
      'children': {
        'type': 'array',
        'items': {r'$ref': r'#/$defs/element'},
      },
      'steps': {
        'type': 'array',
        'items': {r'$ref': r'#/$defs/stepEntry'},
      },
      'notes': {r'$ref': r'#/$defs/notes'},
    },
  },
  'element': {
    'description': 'One scene child. The allowed fields depend on its "type".',
    'oneOf': elementVariants(),
  },
};
