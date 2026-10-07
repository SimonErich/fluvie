import 'package:fluvie/src/serialization/codecs/video_size_codec.dart' show namedVideoSizes;
import 'package:fluvie/src/serialization/video_spec_schema_defs.dart' show buildSpecDefs;
import 'package:fluvie/src/serialization/video_spec_schema_export.dart';

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
    'export': exportSchema(),
    'motionDefaults': {r'$ref': r'#/$defs/defaults'},
    'transition': {r'$ref': r'#/$defs/transition'},
    'theme': {r'$ref': r'#/$defs/theme'},
    'masters': {
      'type': 'object',
      'description':
          'Named master layouts scenes adopt through their "master" key; '
          'applied at build time with no copies.',
      'propertyNames': {'pattern': r'^[a-zA-Z][a-zA-Z0-9]*$'},
      'additionalProperties': {r'$ref': r'#/$defs/master'},
    },
    'audio': {
      'type': 'array',
      'description': 'Composition-wide audio tracks, mixed video-first with scene tracks.',
      'items': {r'$ref': r'#/$defs/audioTrack'},
    },
    'lanes': {
      'type': 'array',
      'description':
          'The timeline rows this document declares. Elements and audio '
          'tracks point at one by id through their "lane".',
      'items': {r'$ref': r'#/$defs/lane'},
    },
    'overlays': {
      'type': 'array',
      'description':
          "Elements that live outside every scene, on the whole video's clock. "
          'Their "show" windows resolve against the video, not a scene, so '
          'they cross every boundary as one instance.',
      'items': {r'$ref': r'#/$defs/overlayElement'},
    },
    'scenes': {
      'type': 'array',
      'minItems': 1,
      'items': {r'$ref': r'#/$defs/scene'},
    },
    'editor': {
      'type': 'object',
      'description':
          "An editing tool's own block: preserved verbatim, never "
          'interpreted by Fluvie, and excluded from the content digest.',
    },
  },
  r'$defs': buildSpecDefs(),
};
