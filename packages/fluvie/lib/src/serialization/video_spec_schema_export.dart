import 'package:fluvie/src/core/encoder_options.dart';
import 'package:fluvie/src/core/quality.dart';

/// Closed export variants, including the typed MP4 encoder choices.
Map<String, Object?> exportSchema() => {
  'oneOf': [
    {
      'type': 'object',
      'required': ['mode'],
      'additionalProperties': false,
      'not': {
        'required': ['crf', 'bitRate'],
      },
      'properties': {
        'mode': {'const': 'mp4'},
        'quality': {
          'type': 'string',
          'enum': [for (final q in Quality.values) q.name],
        },
        'codec': {
          'type': 'string',
          'enum': [for (final v in ExportCodec.values) v.name],
        },
        'crf': {'type': 'integer', 'minimum': 0, 'maximum': 51},
        'bitRate': {'type': 'integer', 'minimum': 1},
        'preset': {
          'type': 'string',
          'enum': [for (final v in EncoderPreset.values) v.name],
        },
        'pixelFormat': {
          'type': 'string',
          'enum': [for (final v in ExportPixelFormat.values) v.name],
        },
      },
    },
    {
      'type': 'object',
      'required': ['mode'],
      'additionalProperties': false,
      'properties': {
        'mode': {'const': 'gif'},
        'fps': {'type': 'integer', 'minimum': 1},
      },
    },
    {
      'type': 'object',
      'required': ['mode'],
      'additionalProperties': false,
      'properties': {
        'mode': {'const': 'imageSequence'},
        'format': {'const': 'png'},
      },
    },
    {
      'type': 'object',
      'required': ['mode'],
      'additionalProperties': false,
      'properties': {
        'mode': {'const': 'transparent'},
      },
    },
  ],
};
