import 'package:fluvie/src/serialization/animation_spec.dart' show knownAnimationPresets;
import 'package:fluvie/src/serialization/codecs/video_size_codec.dart' show namedVideoSizes;
import 'package:fluvie/src/serialization/element_spec.dart' show knownElementTypes;

/// A JSON Schema (draft-07) describing the `VideoSpec` document.
///
/// `fluvie` owns the contract so it cannot drift from the codecs: the element
/// types, animation presets, and size presets come straight from the same sets
/// the parser validates against. The AI authoring package feeds this schema to
/// a model as the structured-output contract; `VideoSpec.fromJson` remains the
/// authoritative validator at parse time.
final Map<String, Object?> videoSpecSchema = {
  r'$schema': 'http://json-schema.org/draft-07/schema#',
  'title': 'Fluvie VideoSpec',
  'type': 'object',
  'required': ['scenes'],
  'properties': {
    'fluvieSpec': {'type': 'integer', 'const': 1},
    'size': {
      'description': 'A preset name or an explicit {width, height}.',
      'oneOf': [
        {'type': 'string', 'enum': namedVideoSizes.keys.toList()},
        {r'$ref': r'#/$defs/dimensions'},
      ],
    },
    'fps': {'type': 'integer', 'minimum': 1, 'default': 30},
    'poster': {r'$ref': r'#/$defs/time'},
    'export': {'type': 'object'},
    'motionDefaults': {r'$ref': r'#/$defs/defaults'},
    'transition': {r'$ref': r'#/$defs/transition'},
    'scenes': {
      'type': 'array',
      'minItems': 1,
      'items': {r'$ref': r'#/$defs/scene'},
    },
  },
  r'$defs': {
    'time': {
      'type': 'string',
      'description': 'A unit-tagged duration: "2s", "30f", "500ms", "0.3r", or "0.2r@0.8s".',
    },
    'color': {'type': 'string', 'description': 'A hex color: "#RRGGBB" or "#AARRGGBB".'},
    'dimensions': {
      'type': 'object',
      'required': ['width', 'height'],
      'properties': {
        'width': {'type': 'integer'},
        'height': {'type': 'integer'},
      },
    },
    'defaults': {
      'type': 'object',
      'properties': {
        'duration': {r'$ref': r'#/$defs/time'},
        'ease': {'type': 'string'},
        'stagger': {'type': 'object'},
      },
    },
    'transition': {
      'type': 'object',
      'required': ['kind'],
      'properties': {
        'kind': {
          'type': 'string',
          'enum': ['cut', 'crossFade', 'wipe', 'zoom', 'slide'],
        },
        'duration': {r'$ref': r'#/$defs/time'},
      },
    },
    'scene': {
      'type': 'object',
      'required': ['duration'],
      'properties': {
        'duration': {r'$ref': r'#/$defs/time'},
        'background': {'type': 'object'},
        'enter': {r'$ref': r'#/$defs/transition'},
        'exit': {r'$ref': r'#/$defs/transition'},
        'children': {
          'type': 'array',
          'items': {r'$ref': r'#/$defs/element'},
        },
      },
    },
    'element': {
      'type': 'object',
      'required': ['type'],
      'additionalProperties': true,
      'properties': {
        'type': {'type': 'string', 'enum': knownElementTypes.toList()},
        'anchor': {'type': 'string'},
        'animate': {
          'type': 'array',
          'items': {r'$ref': r'#/$defs/animation'},
        },
      },
    },
    'animation': {
      'type': 'object',
      'additionalProperties': true,
      'description': 'A named preset (with its arguments) or a raw from/to keyframe animation.',
      'properties': {
        'preset': {'type': 'string', 'enum': knownAnimationPresets.toList()},
        'from': {'type': 'object'},
        'to': {'type': 'object'},
        'duration': {r'$ref': r'#/$defs/time'},
        'ease': {'type': 'string'},
        'delay': {r'$ref': r'#/$defs/time'},
      },
    },
  },
};
