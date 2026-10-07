import 'package:fluvie_cli/src/codegen/dart_spec_printer.dart';
import 'package:test/test.dart';

Map<String, Object?> _spec({Object? steps, Object? notes}) => {
  'fluvieSpec': 1,
  'scenes': [
    {
      'duration': '8s',
      'children': [
        {'id': 'el-title', 'type': 'Text', 'text': 'Incident review'},
        {'id': 'el-b1', 'type': 'Text', 'text': '3am page'},
      ],
      'steps': ?steps,
      'notes': ?notes,
    },
  ],
};

void main() {
  test('a spec without steps or notes prints no heads-up comment', () {
    expect(printVideoSpecJson(_spec()), isNot(contains('steps/notes')));
  });

  test('steps put a leading one-line comment counting them ahead of the code', () {
    final code = printVideoSpecJson(
      _spec(
        steps: const [
          {
            'elements': ['el-b1'],
          },
          {
            'elements': ['el-title'],
          },
        ],
      ),
    );
    final first = code.split('\n').first;
    expect(first, startsWith('// steps/notes: this deck declares 2 build steps;'));
    expect(first, contains('deckFromSpec'));
  });

  test('notes alone are announced too, and a single step counts singular', () {
    final code = printVideoSpecJson(
      _spec(
        steps: const [
          {
            'elements': ['el-b1'],
            'notes': {'text': 'Land it.'},
          },
        ],
        notes: const {'text': 'Open with the story.'},
      ),
    );
    expect(
      code.split('\n').first,
      startsWith('// steps/notes: this deck declares 1 build step and speaker notes;'),
    );
    expect(
      printVideoSpecJson(_spec(notes: const {'text': 'Only notes.'})).split('\n').first,
      startsWith('// steps/notes: this deck declares speaker notes;'),
    );
  });

  test('the printed code itself is unchanged: plain fluvie, no steps in the tree', () {
    final code = printVideoSpecJson(
      _spec(
        steps: const [
          {
            'elements': ['el-b1'],
          },
        ],
      ),
    );
    expect(code, isNot(contains('Stop(')));
    expect(code, contains('Video('));
  });
}
