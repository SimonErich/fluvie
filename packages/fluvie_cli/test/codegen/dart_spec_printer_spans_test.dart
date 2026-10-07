import 'package:fluvie_cli/src/codegen/dart_spec_printer.dart';
import 'package:test/test.dart';

Map<String, Object?> _doc(Map<String, Object?> element) => {
  'fluvieSpec': 1,
  'size': 'hd',
  'fps': 30,
  'scenes': [
    {
      'duration': '60f',
      'children': [element],
    },
  ],
};

void main() {
  group('rich Text spans print Text.rich', () {
    test('spans become TextSpan children under one root', () {
      expect(
        printVideoSpecJson(
          _doc({
            'type': 'Text',
            'spans': [
              {'text': 'Hello '},
              {
                'text': 'world',
                'style': {'fontWeight': 'bold'},
              },
            ],
            'style': {'fontSize': 32},
            'textAlign': 'center',
            'maxLines': 2,
          }),
        ),
        allOf([
          contains('Text.rich('),
          contains('TextSpan('),
          contains('children: ['),
          contains("TextSpan(text: 'Hello ')"),
          contains("text: 'world'"),
          contains('fontWeight: FontWeight.bold'),
          contains('style: TextStyle(fontSize: 32)'),
          contains('textAlign: TextAlign.center'),
          contains('maxLines: 2'),
        ]),
      );
    });

    test('a link span prints the underline and the semantics label the '
        'builder constructs', () {
      expect(
        printVideoSpecJson(
          _doc({
            'type': 'Text',
            'spans': [
              {
                'text': 'Fluvie',
                'link': 'https://fluvie.dev',
                'style': {'color': '#6C5CE7'},
              },
            ],
          }),
        ),
        allOf(
          contains("text: 'Fluvie'"),
          contains('color: Color(0xFF6C5CE7)'),
          contains('decoration: TextDecoration.underline'),
          contains("semanticsLabel: 'Fluvie, link to https://fluvie.dev'"),
        ),
      );
    });

    test('a bare link span still underlines', () {
      expect(
        printVideoSpecJson(
          _doc({
            'type': 'Text',
            'spans': [
              {'text': 'docs', 'link': 'https://fluvie.dev/docs'},
            ],
          }),
        ),
        contains('style: TextStyle(decoration: TextDecoration.underline)'),
      );
    });

    test('text and spans reject together or missing, like the builder', () {
      expect(
        () => printVideoSpecJson(
          _doc({
            'type': 'Text',
            'text': 'plain',
            'spans': [
              {'text': 'rich'},
            ],
          }),
        ),
        throwsFormatException,
      );
      expect(() => printVideoSpecJson(_doc({'type': 'Text'})), throwsFormatException);
    });

    test('a plain text still prints the positional form', () {
      expect(
        printVideoSpecJson(_doc({'type': 'Text', 'text': 'plain'})),
        contains("Text('plain')"),
      );
    });
  });
}
