part of 'video_spec_schema_variants.dart';

/// The per-kind effect `oneOf` for the schema's `effect` def: one closed
/// variant per [EffectSpecKind], listing exactly the parameters that kind
/// reads and the range each number runs over.
List<Object?> effectVariants() => [
  for (final kind in EffectSpecKind.values)
    {
      'type': 'object',
      'required': ['kind'],
      'additionalProperties': false,
      'properties': {
        'kind': {'const': kind.name},
        'enabled': {'type': 'boolean', 'default': true},
        for (final param in kind.params)
          param.name: {
            'description':
                'A number from ${param.min} to ${param.max}, or a keyframed '
                'value that ramps between them over the element life.',
            'oneOf': [
              {
                'type': 'number',
                'minimum': param.min,
                'maximum': param.max,
                'default': param.defaultValue,
              },
              {
                // The shared shape with this parameter's own range on every
                // stop, because a ramp to 5 is refused exactly like a 5.
                'allOf': [
                  {r'$ref': r'#/$defs/keyframedNumber'},
                  {
                    'properties': {
                      'values': {
                        'items': {'minimum': param.min, 'maximum': param.max},
                      },
                    },
                  },
                ],
              },
            ],
          },
        for (final flag in kind.flags) flag: {'type': 'boolean', 'default': false},
        for (final text in kind.strings) text: {'type': 'string', 'minLength': 1},
        for (final entry in kind.enums.entries) entry.key: {'type': 'string', 'enum': entry.value},
        for (final object in kind.objects)
          object: object == 'particles'
              ? {r'$ref': r'#/$defs/particles'}
              : object == 'curves'
              ? _curvesSchema
              : {
                  'type': 'object',
                  'additionalProperties': {'type': 'number'},
                },
      },
    },
];

final Map<String, Object?> _curvesSchema = {
  'type': 'object',
  'additionalProperties': false,
  'properties': {
    for (final channel in ['master', 'red', 'green', 'blue'])
      channel: {
        'type': 'array',
        'minItems': 2,
        'maxItems': 64,
        'items': {
          'type': 'array',
          'minItems': 2,
          'maxItems': 2,
          'items': {'type': 'number', 'minimum': 0, 'maximum': 1},
        },
      },
  },
};
