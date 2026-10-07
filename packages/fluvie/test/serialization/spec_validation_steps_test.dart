import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/fluvie.dart';

/// A scene of three identified children, with [steps] and [notes] spliced in.
Map<String, Object?> _spec({Object? steps, Object? notes}) => {
  'fluvieSpec': 1,
  'scenes': [
    {
      'duration': '8s',
      'children': [
        {'id': 'el-title', 'type': 'Text', 'text': 'Incident review'},
        {'id': 'el-b1', 'type': 'Text', 'text': '3am page'},
        {'id': 'el-b2', 'type': 'Text', 'text': 'one line fix'},
      ],
      'steps': ?steps,
      'notes': ?notes,
    },
  ],
};

void main() {
  test('a clean steps-and-notes scene yields no warnings', () {
    final warnings = unknownSpecProps(
      _spec(
        steps: const [
          {
            'elements': ['el-b1'],
          },
          {
            'elements': ['el-b2'],
            'notes': {'text': 'Land the punchline.'},
          },
        ],
        notes: const {
          'text': 'Open with the outage story.',
          'highlights': ['3am page', 'one line fix'],
        },
      ),
    );
    expect(warnings, isEmpty);
  });

  test('a non-list steps value is a located warning', () {
    final warnings = unknownSpecProps(_spec(steps: 'later'));
    expect(warnings, hasLength(1));
    expect(warnings.single.path, ['scenes', '0', 'steps']);
    expect(warnings.single.message, contains('list'));
  });

  test('a non-object step entry is a located warning', () {
    final warnings = unknownSpecProps(_spec(steps: const ['el-b1']));
    expect(warnings, hasLength(1));
    expect(warnings.single.path, ['scenes', '0', 'steps', '0']);
  });

  test('an unknown step key is flagged and the allowed keys are named', () {
    final warnings = unknownSpecProps(
      _spec(
        steps: const [
          {
            'elements': ['el-b1'],
            'order': 2,
          },
        ],
      ),
    );
    expect(warnings, hasLength(1));
    expect(warnings.single.path, ['scenes', '0', 'steps', '0']);
    expect(warnings.single.message, contains('"order"'));
    expect(warnings.single.message, contains('elements, notes'));
  });

  test('a step without a non-empty elements list is a warning', () {
    for (final step in const [
      <String, Object?>{},
      <String, Object?>{'elements': <Object?>[]},
    ]) {
      final warnings = unknownSpecProps(_spec(steps: [step]));
      expect(warnings, hasLength(1));
      expect(warnings.single.path, ['scenes', '0', 'steps', '0']);
      expect(warnings.single.message, contains('elements'));
    }
  });

  test('a non-string element id is a warning at its entry', () {
    final warnings = unknownSpecProps(
      _spec(
        steps: const [
          {
            'elements': [1],
          },
        ],
      ),
    );
    expect(warnings, hasLength(1));
    expect(warnings.single.path, ['scenes', '0', 'steps', '0', 'elements', '0']);
  });

  test('an id naming no child of the scene is a warning', () {
    final warnings = unknownSpecProps(
      _spec(
        steps: const [
          {
            'elements': ['el-ghost'],
          },
        ],
      ),
    );
    expect(warnings, hasLength(1));
    expect(warnings.single.path, ['scenes', '0', 'steps', '0', 'elements', '0']);
    expect(warnings.single.message, contains('"el-ghost"'));
    expect(warnings.single.message, contains('no child'));
  });

  test('an id repeated across steps is a warning at the repeat', () {
    final warnings = unknownSpecProps(
      _spec(
        steps: const [
          {
            'elements': ['el-b1'],
          },
          {
            'elements': ['el-b1'],
          },
        ],
      ),
    );
    expect(warnings, hasLength(1));
    expect(warnings.single.path, ['scenes', '0', 'steps', '1', 'elements', '0']);
    expect(warnings.single.message, contains('at most one step'));
  });

  test('a non-object notes value is a located warning', () {
    final warnings = unknownSpecProps(_spec(notes: 'remember'));
    expect(warnings, hasLength(1));
    expect(warnings.single.path, ['scenes', '0', 'notes']);
  });

  test('an unknown notes key is flagged with the allowed keys', () {
    final warnings = unknownSpecProps(_spec(notes: const {'bullets': <Object?>[]}));
    expect(warnings, hasLength(1));
    expect(warnings.single.path, ['scenes', '0', 'notes']);
    expect(warnings.single.message, contains('highlights, text'));
  });

  test('a non-string notes text is a warning', () {
    final warnings = unknownSpecProps(_spec(notes: const {'text': 3}));
    expect(warnings, hasLength(1));
    expect(warnings.single.path, ['scenes', '0', 'notes', 'text']);
  });

  test('non-string highlights warn for the list and for an entry', () {
    expect(unknownSpecProps(_spec(notes: const {'highlights': 'fix'})).single.path, [
      'scenes',
      '0',
      'notes',
      'highlights',
    ]);
    expect(
      unknownSpecProps(
        _spec(
          notes: const {
            'highlights': [1],
          },
        ),
      ).single.path,
      ['scenes', '0', 'notes', 'highlights', '0'],
    );
  });

  test('per-step notes get the same checks as scene notes', () {
    final warnings = unknownSpecProps(
      _spec(
        steps: const [
          {
            'elements': ['el-b1'],
            'notes': {'bullets': <Object?>[]},
          },
        ],
      ),
    );
    expect(warnings, hasLength(1));
    expect(warnings.single.path, ['scenes', '0', 'steps', '0', 'notes']);
  });
}
