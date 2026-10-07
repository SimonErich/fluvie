import 'package:fluvie_cli/src/codegen/dart_spec_printer.dart';
import 'package:test/test.dart';

/// The printer half of theme tokens: printed Dart is plain fluvie (no theme
/// object exists at the widget layer), so the printer resolves every token to
/// the literal the builder would use and says so in a leading comment —
/// parity holds because both read the same theme block.
Map<String, Object?> _doc({
  Map<String, Object?>? theme,
  List<Object?> children = const [],
  Object? background,
  Map<String, Object?>? motionDefaults,
}) => {
  'fluvieSpec': 1,
  'size': {'width': 480, 'height': 270},
  'fps': 30,
  'theme': ?theme,
  'motionDefaults': ?motionDefaults,
  'scenes': [
    {
      'duration': '60f',
      'layout': 'canvas',
      'background': ?background,
      'children': children,
    },
  ],
};

const Map<String, Object?> _theme = {
  'palette': {'accent': '#FF6C5CE7', 'surface': '#FF101018'},
  'typeScale': {
    'heading': {'color': '#FFF5F6FA', 'fontSize': 42.0, 'fontWeight': 'w700'},
  },
  'motion': {'duration': '12f', 'ease': 'out'},
};

const String _comment = '// theme tokens resolved to literals for the printed build';

void main() {
  test('a color token prints as the resolved literal, with the comment', () {
    final code = printVideoSpecJson(
      _doc(
        theme: _theme,
        children: const [
          {
            'type': 'Box',
            'color': {'token': 'accent'},
          },
        ],
      ),
    );
    expect(code, contains('Color(0xFF6C5CE7)'));
    expect(code.split('\n').first, _comment);
    final body = code.split('\n').skip(1).join('\n');
    expect(body, isNot(contains('token')), reason: 'no token reference survives into the Dart');
  });

  test('a background color token resolves too', () {
    final code = printVideoSpecJson(
      _doc(
        theme: _theme,
        background: const {
          'kind': 'color',
          'color': {'token': 'surface'},
        },
      ),
    );
    expect(code, contains('Background.color(Color(0xFF101018))'));
    expect(code, contains(_comment));
  });

  test('a style token merges under sibling literal overrides', () {
    final code = printVideoSpecJson(
      _doc(
        theme: _theme,
        children: const [
          {
            'type': 'Text',
            'text': 'hi',
            'style': {'token': 'heading', 'fontSize': 90.0},
          },
        ],
      ),
    );
    expect(code, contains('fontSize: 90'), reason: 'the literal override wins');
    expect(code, contains('fontWeight: FontWeight.w700'));
    expect(code, contains('Color(0xFFF5F6FA)'));
    expect(code, contains(_comment));
  });

  test('theme motion composes under explicit motionDefaults, like the builder', () {
    final composed = printVideoSpecJson(
      _doc(theme: _theme, motionDefaults: const {'duration': '30f'}),
    );
    expect(composed, contains('motionDefaults: Defaults(duration: 30.frames, ease: Ease.out)'));
    expect(composed, contains(_comment));

    final themeOnly = printVideoSpecJson(_doc(theme: _theme));
    expect(themeOnly, contains('motionDefaults: Defaults(duration: 12.frames, ease: Ease.out)'));
  });

  test('an unthemed document prints without the comment, unchanged', () {
    final code = printVideoSpecJson(
      _doc(
        children: const [
          {'type': 'Box', 'color': '#FF123456'},
        ],
        motionDefaults: const {'duration': '30f'},
      ),
    );
    expect(code, isNot(contains(_comment)));
    expect(code, contains('motionDefaults: Defaults(duration: 30.frames)'));
    expect(code, contains('Color(0xFF123456)'));
  });

  test('a themed document whose tokens go unused prints without the comment', () {
    final code = printVideoSpecJson(
      _doc(
        theme: const {
          'palette': {'accent': '#FF6C5CE7'},
        },
        children: const [
          {'type': 'Box', 'color': '#FF123456'},
        ],
      ),
    );
    expect(code, isNot(contains(_comment)));
  });

  test('an unknown token fails loudly with its name and the known names', () {
    expect(
      () => printVideoSpecJson(
        _doc(
          theme: _theme,
          children: const [
            {
              'type': 'Box',
              'color': {'token': 'primary'},
            },
          ],
        ),
      ),
      throwsA(
        isA<FormatException>()
            .having((e) => e.message, 'message', contains('"primary"'))
            .having((e) => e.message, 'message', contains('accent')),
      ),
    );
  });

  test('a token with no theme block fails loudly', () {
    expect(
      () => printVideoSpecJson(
        _doc(
          children: const [
            {
              'type': 'Box',
              'color': {'token': 'accent'},
            },
          ],
        ),
      ),
      throwsA(isA<FormatException>().having((e) => e.message, 'message', contains('theme'))),
    );
  });

  test('a malformed color token object fails loudly', () {
    expect(
      () => printVideoSpecJson(
        _doc(
          theme: _theme,
          children: const [
            {
              'type': 'Box',
              'color': {'token': 'accent', 'alpha': 0.5},
            },
          ],
        ),
      ),
      throwsA(isA<FormatException>()),
    );
  });
}
