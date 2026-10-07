/// The theme-token `$defs` of `videoSpecSchema`: the `theme` block itself,
/// the color literal/token split, and the token-name rule — kept beside the
/// other defs so the advertised vocabulary stays in one place.
///
/// The `color` def here *replaces* the plain hex def: every color field in
/// the schema is a literal or a closed `{"token": ...}` reference, while the
/// palette itself only accepts literals (tokens cannot reference tokens).
Map<String, Object?> buildThemeDefs() => {
  'theme': {
    'type': 'object',
    'additionalProperties': false,
    'description':
        'The deck theme: named design tokens. Color fields reference the '
        'palette as {"token": "<name>"}; style objects reference the type '
        'scale through their "token" field. Tokens resolve at build time and '
        'count into the render digest.',
    'properties': {
      'palette': {
        'type': 'object',
        'description': 'Named literal colors.',
        'propertyNames': {'pattern': _tokenNamePattern},
        'additionalProperties': {r'$ref': r'#/$defs/colorLiteral'},
      },
      'typeScale': {
        'type': 'object',
        'description': 'Named literal text styles.',
        'propertyNames': {'pattern': _tokenNamePattern},
        'additionalProperties': {r'$ref': r'#/$defs/textStyleLiteral'},
      },
      'spacing': {
        'type': 'object',
        'description':
            'Named sizes for editing tools; stored, validated, and digested, '
            'resolved by nothing in the engine yet.',
        'propertyNames': {'pattern': _tokenNamePattern},
        'additionalProperties': {'type': 'number'},
      },
      'motion': {r'$ref': r'#/$defs/defaults'},
    },
  },
  'colorLiteral': {'type': 'string', 'description': 'A hex color: "#RRGGBB" or "#AARRGGBB".'},
  'colorToken': {
    'type': 'object',
    'required': ['token'],
    'additionalProperties': false,
    'description': 'A palette reference, resolved at build time; unknown names fail loudly.',
    'properties': {
      'token': {'type': 'string'},
    },
  },
  'color': {
    'description': 'A hex color literal, or a {"token": "<name>"} palette reference.',
    'oneOf': [
      {r'$ref': r'#/$defs/colorLiteral'},
      {r'$ref': r'#/$defs/colorToken'},
    ],
  },
};

/// The token-name rule the parser enforces: a letter, then letters or digits.
const String _tokenNamePattern = r'^[a-zA-Z][a-zA-Z0-9]*$';
