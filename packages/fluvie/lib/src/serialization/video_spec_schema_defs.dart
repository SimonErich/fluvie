import 'package:fluvie/src/serialization/animation_spec.dart' show knownAnimationPresets;
import 'package:fluvie/src/serialization/codecs/alignment_codec.dart' show namedAlignments;
import 'package:fluvie/src/serialization/codecs/text_style_codec.dart' show namedFontWeights;
import 'package:fluvie/src/serialization/video_spec_schema_variants.dart'
    show backgroundVariants, elementVariants;

/// Builds the `$defs` block of `videoSpecSchema` from the same codec constants
/// the parser validates against, so the advertised vocabulary cannot drift from
/// what Fluvie actually reads. The element and background variants (generated in
/// `video_spec_schema_variants.dart`) are each closed over exactly the fields
/// `buildElement`/`buildBackground` read.
Map<String, Object?> buildSpecDefs() => {
  'time': {
    'type': 'string',
    'description': 'A unit-tagged duration: "2s", "30f", "500ms", "0.3r", or "0.2r@0.8s".',
  },
  'color': {'type': 'string', 'description': 'A hex color: "#RRGGBB" or "#AARRGGBB".'},
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
    'properties': {
      'color': {r'$ref': r'#/$defs/color'},
      'fontSize': {'type': 'number'},
      'fontWeight': {
        'type': 'string',
        'enum': ['normal', 'bold', ...namedFontWeights.keys],
      },
      'fontFamily': {'type': 'string'},
      'letterSpacing': {'type': 'number'},
      'height': {'type': 'number'},
    },
  },
  'imageSource': {
    'type': 'object',
    'required': ['kind', 'value'],
    'additionalProperties': false,
    'properties': {
      'kind': {
        'type': 'string',
        'enum': ['asset', 'network', 'file'],
      },
      'value': {'type': 'string'},
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
  'background': {
    'description': 'A scene backdrop: a named kind with its own fields.',
    'oneOf': backgroundVariants(),
  },
  'scene': {
    'type': 'object',
    'required': ['duration'],
    'additionalProperties': false,
    'properties': {
      'duration': {r'$ref': r'#/$defs/time'},
      'background': {r'$ref': r'#/$defs/background'},
      'enter': {r'$ref': r'#/$defs/transition'},
      'exit': {r'$ref': r'#/$defs/transition'},
      'motionDefaults': {r'$ref': r'#/$defs/defaults'},
      'children': {
        'type': 'array',
        'items': {r'$ref': r'#/$defs/element'},
      },
    },
  },
  'element': {
    'description': 'One scene child. The allowed fields depend on its "type".',
    'oneOf': elementVariants(),
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
};
