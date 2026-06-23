import 'package:fluvie/src/serialization/codecs/video_size_codec.dart' show namedVideoSizes;
import 'package:fluvie/src/serialization/video_spec_schema_defs.dart' show buildSpecDefs;

/// A JSON Schema (draft-07) describing the `VideoSpec` document.
///
/// `fluvie` owns the contract so it cannot drift from the codecs: the element
/// types, animation presets, size presets, and every element/background field
/// come straight from the same constants the parser validates against (see
/// `buildSpecDefs`). Each element and background variant is closed
/// (`additionalProperties: false`) over exactly the fields Fluvie reads, so the
/// model is told precisely which properties belong to each `type`/`kind`.
///
/// The AI authoring package feeds this schema to a model as the structured
/// vocabulary; `VideoSpec.fromJson` (structure and types) plus `unknownSpecProps`
/// (unknown fields) remain the authoritative validators at parse time.
final Map<String, Object?> videoSpecSchema = {
  r'$schema': 'http://json-schema.org/draft-07/schema#',
  'title': 'Fluvie VideoSpec',
  'type': 'object',
  'required': ['scenes'],
  'additionalProperties': false,
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
  r'$defs': buildSpecDefs(),
};
