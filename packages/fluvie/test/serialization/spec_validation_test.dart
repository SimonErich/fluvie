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
      expect(_messages(warnings), contains('allowed: color, size'));
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
