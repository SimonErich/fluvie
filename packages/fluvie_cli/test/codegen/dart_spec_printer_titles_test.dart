import 'package:fluvie_cli/src/codegen/dart_spec_printer.dart';
import 'package:test/test.dart';

void main() {
  test('decorated italic caption prints the same authoring values', () {
    final code = printVideoSpecJson({
      'fluvieSpec': 1,
      'scenes': [
        {
          'duration': '60f',
          'children': [
            {
              'type': 'Text',
              'text': 'Together',
              'maxWidth': 300,
              'padding': {'horizontal': 16, 'vertical': 8},
              'decoration': {'color': '#E6FFFEFC', 'cornerRadius': 999},
              'style': {'fontFamily': 'Newsreader', 'fontStyle': 'italic'},
            },
          ],
        },
      ],
    });
    expect(code, contains('FontStyle.italic'));
    expect(code, contains('maxWidth: 300'));
    expect(code, contains('horizontal: 16'));
    expect(code, contains('vertical: 8'));
  });
  test('ambient easing prints a real curve override', () {
    final code = printVideoSpecJson({
      'fluvieSpec': 1,
      'scenes': [
        {
          'duration': '60f',
          'children': [
            {
              'type': 'Text',
              'text': 'x',
              'animate': [
                {
                  'preset': 'spin',
                  'ease': {
                    'cubic': [0.2, 0.9, 0.6, 1],
                  },
                },
              ],
            },
          ],
        },
      ],
    });
    expect(code, contains('.withEase(Cubic(0.2, 0.9, 0.6, 1))'));
  });
  test('SplitText, stagger and cubic easing print as native Dart', () {
    final code = printVideoSpecJson({
      'fluvieSpec': 1,
      'scenes': [
        {
          'duration': '120f',
          'children': [
            {
              'type': 'SplitText',
              'text': 'Hello world',
              'by': 'word',
              'style': {'fontSize': 32},
              'animate': [
                {
                  'preset': 'fadeIn',
                  'duration': '30f',
                  'stagger': {'each': '4f'},
                  'ease': {
                    'cubic': [0.2, 0.9, 0.6, 1],
                  },
                },
              ],
              'effects': [
                {
                  'kind': 'grade',
                  'exposure': {
                    'values': [0, 1],
                    'positions': ['0r', '1r'],
                    'easings': [
                      {
                        'cubic': [0.2, 0.9, 0.6, 1],
                      },
                    ],
                  },
                },
              ],
            },
          ],
        },
      ],
    });
    expect(code, contains('SplitText('));
    expect(code, contains('by: TextSplit.word'));
    expect(code, contains('Stagger.each(4.frames)'));
    expect(RegExp(r'Cubic\(0.2, 0.9, 0.6, 1\)').allMatches(code), hasLength(2));
  });
}
