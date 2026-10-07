import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/fluvie.dart';

const Map<String, Object?> _gradientBg = {
  'kind': 'gradient',
  'colors': ['#2c3e50', '#000000'],
  'begin': 'topCenter',
  'end': 'bottomCenter',
};

const List<Object?> _cleanChildren = [
  {
    'type': 'Text',
    'text': 'Hi',
    'style': {'fontSize': 96, 'fontWeight': 'bold', 'color': '#ffffff'},
    'animate': [
      {'preset': 'fadeIn', 'duration': '1.5s'},
    ],
  },
];

Map<String, Object?> _spec({
  List<Object?> children = _cleanChildren,
  Map<String, Object?> background = _gradientBg,
  Map<String, Object?> extraTop = const {},
  Map<String, Object?> extraScene = const {},
}) => {
  'fluvieSpec': 1,
  'size': 'reels',
  'fps': 30,
  ...extraTop,
  'scenes': [
    {'duration': '6s', 'background': background, 'children': children, ...extraScene},
  ],
};

String _messages(List<FluvieSpecWarning> warnings) => warnings.map((w) => w.toString()).join('\n');

void main() {
  group('source-of-truth constants', () {
    test('knownElementProps covers exactly the known element types', () {
      expect(knownElementProps.keys.toSet(), knownElementTypes);
    });

    test('knownBackgroundProps covers exactly the known background kinds', () {
      expect(knownBackgroundProps.keys.toSet(), knownBackgroundKinds);
    });
  });

  group('unknownSpecProps', () {
    test('a schema-correct spec has no unknown properties', () {
      expect(unknownSpecProps(_spec()), isEmpty);
    });

    test('flags an unrecognized Box property and names the allowed keys', () {
      final warnings = unknownSpecProps(
        _spec(
          children: const [
            {
              'type': 'Box',
              'fill': {'kind': 'gradient'},
              'width': '100%',
            },
          ],
        ),
      );

      expect(warnings, hasLength(2));
      expect(_messages(warnings), contains('"fill"'));
      expect(_messages(warnings), contains('"width"'));
      expect(_messages(warnings), contains('allowed: color, decoration, size'));
      expect(warnings.first.path, ['scenes', '0', 'children', '0']);
    });

    test('hints at nesting a stray style field under "style" on a Text', () {
      final messages = _messages(
        unknownSpecProps(
          _spec(
            children: const [
              {'type': 'Text', 'text': 'Hi', 'fontSize': 140, 'color': '#fff'},
            ],
          ),
        ),
      );

      expect(messages, contains('"fontSize"'));
      expect(messages, contains('nest it inside "style"'));
      expect(messages, contains('"color"'));
    });

    test('flags a typo inside a nested style object, located at the style path', () {
      final warnings = unknownSpecProps(
        _spec(
          children: const [
            {
              'type': 'Text',
              'text': 'Hi',
              'style': {'fontSise': 12},
            },
          ],
        ),
      );

      expect(_messages(warnings), contains('"fontSise"'));
      expect(_messages(warnings), contains('Did you mean "fontSize"?'));
      expect(warnings.single.path, ['scenes', '0', 'children', '0', 'style']);
    });

    test('flags a typo inside an Image source object', () {
      final warnings = unknownSpecProps(
        _spec(
          children: const [
            {
              'type': 'Image',
              'source': {'kind': 'network', 'value': 'x', 'url': 'y'},
            },
          ],
        ),
      );

      expect(_messages(warnings), contains('"url"'));
      expect(warnings.single.path, ['scenes', '0', 'children', '0', 'source']);
    });

    test('suggests the nearest key for a typo', () {
      final messages = _messages(
        unknownSpecProps(
          _spec(
            children: const [
              {'type': 'Box', 'colour': '#fff'},
            ],
          ),
        ),
      );

      expect(messages, contains('Did you mean "color"?'));
    });

    test('flags an unrecognized background property', () {
      final messages = _messages(
        unknownSpecProps(
          _spec(
            background: const {
              'kind': 'gradient',
              'colors': ['#000000'],
              'angle': 180,
            },
          ),
        ),
      );

      expect(messages, contains('"angle"'));
    });

    test('gradient stop offsets are known on backgrounds and decorations', () {
      expect(
        unknownSpecProps(
          _spec(
            background: const {
              'kind': 'radial',
              'colors': ['#000000', '#ffffff'],
              'stops': [0.1, 0.8],
            },
            children: const [
              {
                'type': 'Box',
                'decoration': {
                  'gradient': {
                    'colors': ['#101018', '#2D3436'],
                    'stops': [0, 0.35],
                  },
                },
              },
            ],
          ),
        ),
        isEmpty,
      );
    });

    test('flags an unrecognized top-level and scene key', () {
      final messages = _messages(
        unknownSpecProps(
          _spec(extraTop: const {'title': 'oops'}, extraScene: const {'name': 'intro'}),
        ),
      );

      expect(messages, contains('"title"'));
      expect(messages, contains('"name"'));
    });

    test('skips a malformed node and leaves its structural error to the parser', () {
      expect(unknownSpecProps(const {'scenes': 'nope'}), isEmpty);
      expect(
        unknownSpecProps(const {
          'scenes': [
            {'duration': '1s', 'children': 'nope'},
          ],
        }),
        isEmpty,
      );
    });

    test('flags a stray argument on an animation preset', () {
      final warnings = unknownSpecProps(
        _spec(
          children: const [
            {
              'type': 'Box',
              'animate': [
                {'preset': 'fadeIn', 'sigma': 4},
              ],
            },
          ],
        ),
      );

      expect(_messages(warnings), contains('"sigma"'));
      expect(_messages(warnings), contains('a fadeIn animation'));
      expect(warnings.single.path, ['scenes', '0', 'children', '0', 'animate', '0']);
    });

    test('accepts every wave-2 preset argument, including open shader uniforms', () {
      expect(
        unknownSpecProps(
          _spec(
            children: const [
              {
                'type': 'Box',
                'animate': [
                  {'preset': 'scaleY', 'on': 'mid', 'gain': 1.5, 'track': 'music'},
                  {'preset': 'pulse', 'on': 'bass', 'gain': 1.2, 'track': 'music'},
                  {'preset': 'along', 'path': 'M 0 0 L 1 1', 'orient': false, 'phase': 'during'},
                  {
                    'preset': 'shader',
                    'asset': 'shaders/ripple.frag',
                    'uniforms': {'anySlotName': 3},
                  },
                  {
                    'preset': 'particles',
                    'spec': {'kind': 'snow', 'count': 12},
                  },
                ],
              },
            ],
          ),
        ),
        isEmpty,
      );
    });

    test('flags a typo inside a particles spec, located at the spec path', () {
      final warnings = unknownSpecProps(
        _spec(
          children: const [
            {
              'type': 'Box',
              'animate': [
                {
                  'preset': 'particles',
                  'spec': {'kind': 'confetti', 'countt': 3},
                },
              ],
            },
          ],
        ),
      );

      expect(_messages(warnings), contains('Did you mean "count"?'));
      expect(warnings.single.path, ['scenes', '0', 'children', '0', 'animate', '0', 'spec']);
    });

    test('leaves raw keyframes and unknown presets to the parser', () {
      expect(
        unknownSpecProps(
          _spec(
            children: const [
              {
                'type': 'Box',
                'animate': [
                  {
                    'from': {'opacity': 0, 'blur': 8},
                  },
                  {'preset': 'teleport', 'warp': 9},
                  'nope',
                ],
              },
            ],
          ),
        ),
        isEmpty,
      );
    });

    test('does not flag a valid prop that is invalid only on a sibling type', () {
      // "color" is valid on a Box even though it is invalid (must nest) on a Text.
      expect(
        unknownSpecProps(
          _spec(
            children: const [
              {'type': 'Box', 'color': '#fff'},
            ],
          ),
        ),
        isEmpty,
      );
    });
  });

  group('unknownSpecProps over masters', () {
    Map<String, Object?> masteredSpec({
      Map<String, Object?>? master,
      Map<String, Object?> extraScene = const {},
    }) => _spec(
      extraTop: {
        'masters': {
          'content':
              master ??
              const {
                'background': {'kind': 'color', 'color': '#FF101018'},
                'children': [
                  {'type': 'Box', 'color': '#FF6C5CE7'},
                  {
                    'type': 'Placeholder',
                    'slot': 'title',
                    'transform': {'x': 0.5, 'y': 0.3},
                    'style': {'fontSize': 34},
                  },
                ],
              },
        },
      },
      extraScene: {
        'master': 'content',
        'fills': {
          'title': {'type': 'Text', 'text': 'Filled'},
        },
        ...extraScene,
      },
    );

    test('a clean mastered spec has no unknown properties', () {
      expect(unknownSpecProps(masteredSpec()), isEmpty);
    });

    test('flags an unknown key on a master, located at the master', () {
      final warnings = unknownSpecProps(
        masteredSpec(
          master: const {
            'children': [
              {'type': 'Placeholder', 'slot': 'title'},
            ],
            'chidren': <Object?>[],
          },
        ),
      );
      expect(warnings, hasLength(1));
      expect(warnings.single.path, ['masters', 'content']);
      expect(warnings.single.message, contains('"chidren"'));
      expect(warnings.single.message, contains('"children"'));
    });

    test('flags unknown keys on a placeholder and typos in its transform and style', () {
      final warnings = unknownSpecProps(
        masteredSpec(
          master: const {
            'children': [
              {
                'type': 'Placeholder',
                'slot': 'title',
                'fill': 'body',
                'transform': {'x': 0.5, 'y': 0.3, 'rotate': 4},
                'style': {'fontSiez': 34},
              },
            ],
          },
        ),
      );
      expect(_messages(warnings), contains('"fill"'));
      expect(_messages(warnings), contains('"rotate"'));
      expect(_messages(warnings), contains('"fontSiez"'));
      expect(warnings.first.path, ['masters', 'content', 'children', '0']);
    });

    test('flags identity keys on master children, nested ones included', () {
      final warnings = unknownSpecProps(
        masteredSpec(
          master: const {
            'children': [
              {'type': 'Box', 'color': '#FF000000', 'id': 'chrome'},
              {
                'type': 'Group',
                'children': [
                  {'type': 'Box', 'color': '#FF000000', 'anchor': 'a'},
                ],
              },
              {'type': 'Placeholder', 'slot': 'title'},
            ],
          },
        ),
      );
      expect(warnings, hasLength(2));
      expect(warnings[0].message, contains('"id"'));
      expect(warnings[0].path, ['masters', 'content', 'children', '0']);
      expect(warnings[1].message, contains('"anchor"'));
      expect(warnings[1].path, ['masters', 'content', 'children', '1', 'children', '0']);
    });

    test('sweeps master chrome elements and the master background as usual', () {
      final warnings = unknownSpecProps(
        masteredSpec(
          master: const {
            'background': {'kind': 'color', 'colour': '#FF101018'},
            'children': [
              {'type': 'Box', 'colour': '#FF000000'},
              {'type': 'Placeholder', 'slot': 'title'},
            ],
          },
        ),
      );
      expect(_messages(warnings), contains('"colour"'));
      expect(warnings.map((w) => w.path), [
        ['masters', 'content', 'background'],
        ['masters', 'content', 'children', '0'],
      ]);
    });

    test('flags a Placeholder outside a master', () {
      final warnings = unknownSpecProps(
        _spec(
          children: const [
            {'type': 'Placeholder', 'slot': 'title'},
          ],
        ),
      );
      expect(warnings, hasLength(1));
      expect(warnings.single.message, contains('master'));
      expect(warnings.single.path, ['scenes', '0', 'children', '0']);
    });

    test('flags an unknown master name and an unknown fill slot', () {
      final unknownName = unknownSpecProps(masteredSpec(extraScene: const {'master': 'missing'}));
      expect(_messages(unknownName), contains('"missing"'));
      expect(unknownName.single.path, ['scenes', '0', 'master']);

      final unknownSlot = unknownSpecProps(
        masteredSpec(
          extraScene: const {
            'fills': {
              'footer': {'type': 'Text', 'text': 'x'},
            },
          },
        ),
      );
      expect(_messages(unknownSlot), allOf(contains('"footer"'), contains('"title"')));
      expect(unknownSlot.single.path, ['scenes', '0', 'fills', 'footer']);
    });

    test('a step may reveal a fill by its id', () {
      final warnings = unknownSpecProps(
        masteredSpec(
          extraScene: const {
            'fills': {
              'title': {'type': 'Text', 'id': 'fill-title', 'text': 'x'},
            },
            'steps': [
              {
                'elements': ['fill-title'],
              },
            ],
          },
        ),
      );
      expect(warnings, isEmpty);
    });

    test('sweeps fill elements like any other element', () {
      final warnings = unknownSpecProps(
        masteredSpec(
          extraScene: const {
            'fills': {
              'title': {'type': 'Text', 'text': 'x', 'txetAlign': 'center'},
            },
          },
        ),
      );
      expect(warnings, hasLength(1));
      expect(warnings.single.message, contains('"txetAlign"'));
      expect(warnings.single.path, ['scenes', '0', 'fills', 'title']);
    });
  });

  group('assertNoUnknownSpecProps', () {
    test('returns normally for a clean spec', () {
      expect(() => assertNoUnknownSpecProps(_spec()), returnsNormally);
    });

    test('throws a FluvieSpecError enumerating every unknown property', () {
      expect(
        () => assertNoUnknownSpecProps(
          _spec(
            children: const [
              {'type': 'Box', 'fill': 1, 'width': 2},
            ],
          ),
        ),
        throwsA(
          isA<FluvieSpecError>()
              .having((e) => e.message, 'message', contains('2 properties'))
              .having((e) => e.message, 'message', contains('"fill"'))
              .having((e) => e.message, 'message', contains('"width"')),
        ),
      );
    });
  });
}
