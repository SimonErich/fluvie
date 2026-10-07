/// The master-layout `$defs` of `videoSpecSchema`: the master shape, the
/// placeholder slot, and the master-child union — kept beside the other defs
/// so the advertised vocabulary stays in one place.
///
/// A master child is either fixed chrome (a full element carrying no
/// identity keys — `id`, `anchor`, and `shared` belong to the scene's own
/// fills and children) or a named `Placeholder` a scene fills through its
/// `fills` map, with scene-level overrides: a fill's `transform` beats the
/// placeholder's, and the placeholder's `style` merges under the fill's.
Map<String, Object?> buildMasterDefs() => {
  'master': {
    'type': 'object',
    'additionalProperties': false,
    'description':
        'A reusable slide layout scenes adopt through their "master" key. '
        'Applied at build time with no copies, so editing a master changes '
        'every adopting scene.',
    'properties': {
      'background': {r'$ref': r'#/$defs/background'},
      'layout': {
        'type': 'string',
        'enum': ['stack', 'canvas'],
        'description': 'The authoring intent for the master editing canvas.',
      },
      'children': {
        'type': 'array',
        'items': {r'$ref': r'#/$defs/masterElement'},
      },
    },
  },
  'placeholder': {
    'type': 'object',
    'additionalProperties': false,
    'required': ['type', 'slot'],
    'description':
        'A named slot inside a master. The fill lands at "transform" unless '
        'it carries its own; "style" defaults merge under the fill\'s style '
        'per field. Legal only inside master definitions.',
    'properties': {
      'type': {'const': 'Placeholder'},
      'slot': {'type': 'string', 'pattern': _identifierPattern},
      'transform': {r'$ref': r'#/$defs/transform'},
      'style': {r'$ref': r'#/$defs/textStyle'},
    },
  },
  'masterElement': {
    'description':
        'One master child: fixed chrome (an element with no id, anchor, or '
        'shared) or a named Placeholder.',
    'oneOf': [
      {
        'allOf': [
          {r'$ref': r'#/$defs/element'},
          {
            'not': {
              'anyOf': [
                {
                  'required': ['id'],
                },
                {
                  'required': ['anchor'],
                },
                {
                  'required': ['shared'],
                },
              ],
            },
          },
        ],
      },
      {r'$ref': r'#/$defs/placeholder'},
    ],
  },
};

/// The name rule masters and slots share with theme tokens: a letter, then
/// letters or digits.
const String _identifierPattern = r'^[a-zA-Z][a-zA-Z0-9]*$';
