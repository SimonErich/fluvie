import 'package:fluvie_cli/src/codegen/dart_spec_printer.dart';
import 'package:test/test.dart';

/// The printer half of masters: printed Dart is the render, so an adopting
/// scene prints RESOLVED — master chrome, filled placeholders, then the
/// scene's own children — behind a leading comment naming the master.
/// Parity holds because the printer mirrors `resolveSceneMaster` over JSON:
/// the scene background wins, a fill's transform beats the placeholder's,
/// and the placeholder style merges under the fill's per field.
Map<String, Object?> _doc({
  Map<String, Object?>? masters,
  List<Object?> scenes = const [],
  Map<String, Object?>? theme,
}) => {
  'fluvieSpec': 1,
  'size': {'width': 480, 'height': 270},
  'fps': 30,
  'theme': ?theme,
  'masters': ?masters,
  'scenes': scenes,
};

const Map<String, Object?> _masters = {
  'content': {
    'background': {'kind': 'color', 'color': '#FF101018'},
    'layout': 'canvas',
    'children': [
      {
        'type': 'Box',
        'color': '#FF6C5CE7',
        'transform': {'x': 0.5, 'y': 0.94, 'w': 1.0, 'h': 0.06},
      },
      {
        'type': 'Placeholder',
        'slot': 'title',
        'transform': {'x': 0.5, 'y': 0.3, 'w': 0.9, 'h': 0.3},
        'style': {'color': '#FFF5F6FA', 'fontSize': 34.0, 'fontWeight': 'w700'},
      },
      {
        'type': 'Placeholder',
        'slot': 'body',
        'transform': {'x': 0.5, 'y': 0.62, 'w': 0.86, 'h': 0.25},
      },
    ],
  },
};

const String _comment = '// master "content" applied for the printed build';

Map<String, Object?> _adopting({Map<String, Object?>? fills, List<Object?>? children}) => {
  'duration': '90f',
  'layout': 'canvas',
  'master': 'content',
  'fills':
      fills ??
      const {
        'title': {
          'type': 'Text',
          'id': 's1-title',
          'text': 'Adopted',
          'transform': {'x': 0.5, 'y': 0.14, 'w': 0.9, 'h': 0.24},
        },
      },
  'children': ?children,
};

void main() {
  test('an adopting scene prints resolved, behind the master comment', () {
    final code = printVideoSpecJson(
      _doc(
        masters: _masters,
        scenes: [
          _adopting(
            children: const [
              {
                'type': 'Box',
                'id': 's1-extra',
                'color': '#FFFFD166',
                'transform': {'x': 0.85, 'y': 0.1, 'w': 0.16, 'h': 0.1},
              },
            ],
          ),
        ],
      ),
    );
    expect(code.split('\n').first, _comment);
    expect(code, contains('Color(0xFF6C5CE7)'), reason: 'the master chrome prints');
    expect(code, contains('Color(0xFF101018)'), reason: 'the master background prints');
    expect(code, contains("'Adopted'"), reason: 'the fill prints');
    expect(code, contains('Color(0xFFFFD166)'), reason: 'the freeform extra prints');
    expect(code, isNot(contains('Placeholder')), reason: 'no placeholder survives');
  });

  test('a fill transform overrides; a fill without one takes the placeholder transform', () {
    final overriding = printVideoSpecJson(_doc(masters: _masters, scenes: [_adopting()]));
    expect(overriding, contains('y: 0.14'));
    final falling = printVideoSpecJson(
      _doc(
        masters: _masters,
        scenes: [
          _adopting(
            fills: const {
              'title': {'type': 'Text', 'id': 't', 'text': 'Sits in the slot'},
            },
          ),
        ],
      ),
    );
    expect(falling, contains('y: 0.3'));
  });

  test('the placeholder style merges under the fill style, fill winning per field', () {
    final code = printVideoSpecJson(
      _doc(
        masters: _masters,
        scenes: [
          _adopting(
            fills: const {
              'title': {
                'type': 'Text',
                'id': 't',
                'text': 'Styled',
                'style': {'fontSize': 48.0},
              },
            },
          ),
        ],
      ),
    );
    expect(code, contains('fontSize: 48'));
    expect(code, contains('FontWeight.w700'));
    expect(code, contains('Color(0xFFF5F6FA)'));
  });

  test('an unfilled slot prints nothing; the scene background wins', () {
    final code = printVideoSpecJson(
      _doc(
        masters: _masters,
        scenes: [
          {
            'duration': '90f',
            'background': {'kind': 'color', 'color': '#FF2D3436'},
            'master': 'content',
            'fills': const {
              'title': {'type': 'Text', 'id': 't', 'text': 'Only title'},
            },
          },
        ],
      ),
    );
    expect(code, contains('Color(0xFF2D3436)'));
    expect(code, isNot(contains('Color(0xFF101018)')));
    expect('Text('.allMatches(code), hasLength(1), reason: 'only the title fill prints');
  });

  test('a theme token inside a placeholder style resolves like any other', () {
    final code = printVideoSpecJson(
      _doc(
        theme: const {
          'palette': {'ink': '#FF222831'},
        },
        masters: const {
          'content': {
            'children': [
              {
                'type': 'Placeholder',
                'slot': 'title',
                'style': {
                  'color': {'token': 'ink'},
                },
              },
            ],
          },
        },
        scenes: [
          _adopting(
            fills: const {
              'title': {'type': 'Text', 'id': 't', 'text': 'Inked'},
            },
          ),
        ],
      ),
    );
    expect(code, contains('Color(0xFF222831)'));
  });

  test('a freeform deck prints without the comment', () {
    final code = printVideoSpecJson(
      _doc(
        scenes: const [
          {
            'duration': '60f',
            'children': [
              {'type': 'Text', 'text': 'Free'},
            ],
          },
        ],
      ),
    );
    expect(code, isNot(contains('master')));
  });

  test('an unknown master, an unknown slot, and fills without a master all throw', () {
    expect(
      () => printVideoSpecJson(
        _doc(
          scenes: [
            {'duration': '60f', 'master': 'missing'},
          ],
        ),
      ),
      throwsA(isA<FormatException>().having((e) => e.message, 'message', contains('"missing"'))),
    );
    expect(
      () => printVideoSpecJson(
        _doc(
          masters: _masters,
          scenes: [
            _adopting(
              fills: const {
                'footer': {'type': 'Text', 'id': 'f', 'text': 'x'},
              },
            ),
          ],
        ),
      ),
      throwsA(isA<FormatException>().having((e) => e.message, 'message', contains('"footer"'))),
    );
    expect(
      () => printVideoSpecJson(
        _doc(
          scenes: const [
            {
              'duration': '60f',
              'fills': {
                'title': {'type': 'Text', 'id': 't', 'text': 'x'},
              },
            },
          ],
        ),
      ),
      throwsA(isA<FormatException>().having((e) => e.message, 'message', contains('master'))),
    );
  });
}
