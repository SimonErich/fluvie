/// Builds the audio-track `$defs` of `videoSpecSchema`: the `audioTrack`
/// oneOf (a closed `music` variant and a closed `sfx` variant, mirroring the
/// `Audio.music`/`Audio.sfx` constructors field for field) and the `trigger`
/// vocabulary the sfx `at` resolves with. The source object is the same
/// `{kind, value}` shape images and clips use (`#/$defs/imageSource`).
Map<String, Object?> buildAudioDefs() => {
  'audioAutomation': {
    'type': 'object',
    'additionalProperties': false,
    'properties': {
      'volume': {
        'oneOf': [
          {'type': 'number'},
          {r'$ref': r'#/$defs/keyframedNumber'},
        ],
      },
    },
  },
  'audioTrack': {
    'description':
        'One audio track: a music bed or a one-shot sound effect. Placement '
        'in time comes from the owner — a video-level track spans the video, '
        'a scene-level track starts with its scene.',
    'oneOf': [_musicVariant(), _sfxVariant()],
  },
  'trigger': {
    'description': 'When something starts: a keyword, or an object tagged by "kind".',
    'oneOf': [
      {
        'type': 'string',
        'enum': ['auto', 'sceneStart', 'sceneEnd', 'previous'],
      },
      {
        'type': 'object',
        'required': ['kind'],
        'properties': {
          'kind': {
            'type': 'string',
            'enum': ['at', 'beat', 'whenEnds', 'whenStarts'],
          },
          'time': {r'$ref': r'#/$defs/time'},
          'every': {'type': 'integer', 'minimum': 1},
          'track': {'type': 'string'},
          'anchor': {'type': 'string'},
        },
      },
    ],
  },
};

Map<String, Object?> _musicVariant() => {
  'type': 'object',
  'required': ['kind', 'source'],
  'additionalProperties': false,
  'description': 'A music bed playing for the lifetime of its owner.',
  'properties': {
    'kind': {'type': 'string', 'const': 'music'},
    'at': {r'$ref': r'#/$defs/trigger'},
    'source': {r'$ref': r'#/$defs/imageSource'},
    'volume': _volume(),
    'automation': {r'$ref': r'#/$defs/audioAutomation'},
    'fadeIn': {r'$ref': r'#/$defs/time'},
    'fadeOut': {r'$ref': r'#/$defs/time'},
    'loop': {'type': 'boolean', 'default': false},
    'trim': {r'$ref': r'#/$defs/trim'},
    'lane': {r'$ref': r'#/$defs/laneRef'},
    'track': {
      'type': 'string',
      'description':
          "An anchor id naming this track's analysed beat grid, so "
          '"beat" triggers can resolve against it.',
    },
  },
};

Map<String, Object?> _sfxVariant() => {
  'type': 'object',
  'required': ['kind', 'source'],
  'additionalProperties': false,
  'description':
      'A one-shot sound effect fired at a trigger; a missing "at" means the '
      "owner's start.",
  'properties': {
    'kind': {'type': 'string', 'const': 'sfx'},
    'source': {r'$ref': r'#/$defs/imageSource'},
    'at': {r'$ref': r'#/$defs/trigger'},
    'volume': _volume(),
    'automation': {r'$ref': r'#/$defs/audioAutomation'},
    'lane': {r'$ref': r'#/$defs/laneRef'},
  },
};

Map<String, Object?> _volume() => {
  'type': 'number',
  'minimum': 0,
  'default': 1,
  'description': 'Linear gain; 1 plays the file as authored.',
};
