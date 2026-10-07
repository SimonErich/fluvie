part of 'video_spec_schema_defs.dart';

// Element runtime, lanes, effects and animation schema vocabulary.
Map<String, Object?> _buildRuntimeDefs() => {
  'keyframedNumber': {
    'type': 'object',
    'required': ['values', 'positions'],
    'additionalProperties': false,
    'description':
        'A number that changes over its element life: ordered stops, one '
        'position per stop, and one easing per segment between them. The same '
        'vocabulary the "keyframes" animation form uses.',
    'properties': {
      'values': {
        'type': 'array',
        'minItems': 2,
        'items': {'type': 'number'},
      },
      'positions': {
        'type': 'array',
        'minItems': 2,
        'items': {r'$ref': r'#/$defs/time'},
      },
      'easings': {
        'type': 'array',
        'items': {r'$ref': r'#/$defs/ease'},
      },
    },
  },
  'effect': {
    'description':
        'One entry of an element effect stack. The allowed fields depend on '
        'its "kind"; a disabled effect stays in the document and renders '
        'nothing.',
    'oneOf': effectVariants(),
  },
  'overlayElement': {
    'description':
        'One overlay: a scene child without "shared". An overlay already runs '
        'the whole video, so it has no boundary to morph across.',
    'oneOf': overlayElementVariants(),
  },
  'lane': {
    'type': 'object',
    'required': ['id'],
    'additionalProperties': false,
    'description':
        'One timeline row. A lane says where material is shown, never what '
        'order it paints in: paint order is the "children" list. Only "muted" '
        'reaches the render.',
    'properties': {
      'id': {'type': 'string', 'minLength': 1},
      'name': {'type': 'string'},
      'kind': {
        'type': 'string',
        'enum': ['video', 'audio'],
        'default': 'video',
      },
      'locked': {'type': 'boolean', 'default': false},
      'muted': {'type': 'boolean', 'default': false},
      'gain': {'type': 'number', 'minimum': 0, 'default': 1},
      'height': {'type': 'number', 'exclusiveMinimum': 0},
    },
  },
  'laneRef': {
    'type': 'string',
    'description':
        'The id of a lane declared in the document\'s "lanes". The key is '
        '"lane" and never "track": "track" is already a content property.',
  },
  'transform': {
    'type': 'object',
    'description':
        'Fractional placement on the canvas: the anchor point of the element '
        'lands at (x, y); w/h size it (omit for intrinsic); rotation is in '
        'degrees around the element center.',
    'required': ['x', 'y'],
    'additionalProperties': false,
    'properties': {
      'x': {'type': 'number'},
      'y': {'type': 'number'},
      'w': {'type': 'number', 'exclusiveMinimum': 0},
      'h': {'type': 'number', 'exclusiveMinimum': 0},
      'rotation': {'type': 'number'},
      'opacity': {'type': 'number', 'minimum': 0, 'maximum': 1},
      'anchor': {'type': 'string'},
    },
  },
  'keyframe': {
    'type': 'object',
    'additionalProperties': false,
    'description':
        'One animation stop: only the overridden fields are present; an absent '
        'field stays at its natural value. "origin" defaults to center.',
    'properties': {
      'opacity': {'type': 'number'},
      'x': {'type': 'number'},
      'y': {'type': 'number'},
      'scale': {'type': 'number'},
      'scaleX': {'type': 'number'},
      'scaleY': {'type': 'number'},
      'rotation': {'type': 'number'},
      'skewX': {'type': 'number'},
      'skewY': {'type': 'number'},
      'blur': {'type': 'number'},
      'color': {r'$ref': r'#/$defs/color'},
      'origin': {r'$ref': r'#/$defs/alignment'},
    },
  },
  'animation': {
    'type': 'object',
    'additionalProperties': true,
    'description':
        'A named preset (with its arguments), a multi-stop "keyframes" '
        'animation, or a raw from/to keyframe animation. In the keyframes '
        'form the stop positions are "positions" (one time per stop, strictly '
        'increasing) and "easings" shapes each segment (one per segment); '
        '"at" always stays the start trigger. '
        'A shader preset\'s "asset" must be a plain relative asset path: no '
        'absolute paths, no "..", and no URL schemes.',
    'properties': {
      'preset': {'type': 'string', 'enum': knownAnimationPresets.toList()},
      'from': {'type': 'object'},
      'to': {'type': 'object'},
      ..._keyframesFormProps(),
      'duration': {r'$ref': r'#/$defs/time'},
      'ease': {r'$ref': r'#/$defs/ease'},
      'delay': {r'$ref': r'#/$defs/time'},
    },
  },
};

/// The `keyframes`-form properties of the animation def, keyed by the same
/// [knownKeyframesFormKeys] the unknown-property check reads so the two can
/// never drift.
Map<String, Object?> _keyframesFormProps() => {
  for (final key in knownKeyframesFormKeys)
    key: switch (key) {
      'keyframes' => {
        'type': 'array',
        'minItems': 2,
        'items': {r'$ref': r'#/$defs/keyframe'},
      },
      'easings' => {
        'type': 'array',
        'description': 'One named or cubic ease per segment (stop count minus one).',
        'items': {r'$ref': r'#/$defs/ease'},
      },
      'positions' => {
        'type': 'array',
        'description': 'One time per stop, strictly increasing.',
        'items': {r'$ref': r'#/$defs/time'},
      },
      _ => {
        'type': 'string',
        'enum': ['enter', 'exit', 'during'],
      },
    },
};
