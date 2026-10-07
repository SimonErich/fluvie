import 'package:fluvie/src/serialization/animation_spec.dart'
    show knownAnimationPresets, knownKeyframesFormKeys;
import 'package:fluvie/src/serialization/codecs/alignment_codec.dart' show namedAlignments;
import 'package:fluvie/src/serialization/codecs/curve_codec.dart' show namedEases;
import 'package:fluvie/src/serialization/codecs/text_style_codec.dart' show namedFontWeights;
import 'package:fluvie/src/serialization/video_spec_schema_audio_defs.dart' show buildAudioDefs;
import 'package:fluvie/src/serialization/video_spec_schema_content_defs.dart' show buildContentDefs;
import 'package:fluvie/src/serialization/video_spec_schema_master_defs.dart' show buildMasterDefs;
import 'package:fluvie/src/serialization/video_spec_schema_theme_defs.dart' show buildThemeDefs;
import 'package:fluvie/src/serialization/video_spec_schema_variants.dart'
    show backgroundVariants, effectVariants, elementVariants, overlayElementVariants;

part 'video_spec_schema_geometry_style_defs.dart';
part 'video_spec_schema_scene_defs.dart';
part 'video_spec_schema_runtime_defs.dart';

/// Builds the `$defs` block of `videoSpecSchema` from the same codec constants
/// the parser validates against, so the advertised vocabulary cannot drift from
/// what Fluvie actually reads. The element and background variants (generated in
/// `video_spec_schema_variants.dart`) are each closed over exactly the fields
/// `buildElement`/`buildBackground` read.
Map<String, Object?> buildSpecDefs() => {
  'ease': {
    'oneOf': [
      {'type': 'string', 'enum': namedEases.keys.toList()},
      {
        'type': 'object',
        'required': ['cubic'],
        'additionalProperties': false,
        'properties': {
          'cubic': {
            'type': 'array',
            'minItems': 4,
            'maxItems': 4,
            'additionalItems': false,
            'items': [
              {'type': 'number', 'minimum': 0, 'maximum': 1},
              {'type': 'number'},
              {'type': 'number', 'minimum': 0, 'maximum': 1},
              {'type': 'number'},
            ],
          },
        },
      },
    ],
  },
  ...buildAudioDefs(),
  ...buildContentDefs(),
  ...buildMasterDefs(),
  ...buildThemeDefs(),
  ..._buildGeometryStyleDefs(),
  ..._buildSceneDefs(),
  ..._buildRuntimeDefs(),
};
