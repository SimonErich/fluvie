import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/fluvie.dart';

/// The ADR example shape: three children, two steps, scene notes plus a
/// per-step override (documentation/contributing/steps-notes-digest.md).
Map<String, Object?> _document({Object? steps, Object? notes}) => {
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

const List<Object?> _adrSteps = [
  {
    'elements': ['el-b1'],
  },
  {
    'elements': ['el-b2'],
    'notes': {'text': 'Land the punchline.'},
  },
];

const Map<String, Object?> _adrNotes = {
  'text': 'Open with the outage story.',
  'highlights': ['3am page', 'one line fix'],
};

void main() {
  group('parsing', () {
    test('reads steps in list order, with elements and per-step notes', () {
      final spec = VideoSpec.fromJson(_document(steps: _adrSteps, notes: _adrNotes));
      final scene = spec.scenes.single;
      expect(scene.steps, hasLength(2));
      expect(scene.steps[0].elements, ['el-b1']);
      expect(scene.steps[0].notes, isNull);
      expect(scene.steps[1].elements, ['el-b2']);
      expect(scene.steps[1].notes!.text, 'Land the punchline.');
      expect(scene.steps[1].notes!.highlights, isEmpty);
      expect(scene.notes!.text, 'Open with the outage story.');
      expect(scene.notes!.highlights, ['3am page', 'one line fix']);
    });

    test('a scene without steps or notes parses to an empty list and null', () {
      final scene = VideoSpec.fromJson(_document()).scenes.single;
      expect(scene.steps, isEmpty);
      expect(scene.notes, isNull);
    });

    test('knownKeys names steps and notes', () {
      expect(SceneSpec.knownKeys, containsAll(<String>['steps', 'notes']));
    });

    test('a non-list steps value throws, naming the path', () {
      expect(
        () => VideoSpec.fromJson(_document(steps: 'later')),
        throwsA(
          isA<FluvieSpecError>().having((e) => e.path, 'path', ['scenes', '0', 'steps']),
        ),
      );
    });

    test('a non-object step entry throws, naming the path', () {
      expect(
        () => VideoSpec.fromJson(_document(steps: const ['el-b1'])),
        throwsA(
          isA<FluvieSpecError>().having((e) => e.path, 'path', ['scenes', '0', 'steps', '0']),
        ),
      );
    });

    test('a step without a non-empty elements list throws', () {
      for (final step in const [
        <String, Object?>{},
        <String, Object?>{'elements': <Object?>[]},
      ]) {
        expect(
          () => VideoSpec.fromJson(_document(steps: [step])),
          throwsA(
            isA<FluvieSpecError>().having(
              (e) => e.path,
              'path',
              ['scenes', '0', 'steps', '0', 'elements'],
            ),
          ),
        );
      }
    });

    test('a non-string element id throws, naming the entry', () {
      expect(
        () => VideoSpec.fromJson(
          _document(
            steps: const [
              {
                'elements': [1],
              },
            ],
          ),
        ),
        throwsA(
          isA<FluvieSpecError>().having(
            (e) => e.path,
            'path',
            ['scenes', '0', 'steps', '0', 'elements', '0'],
          ),
        ),
      );
    });

    test('a non-string notes text throws', () {
      expect(
        () => VideoSpec.fromJson(_document(notes: const {'text': 3})),
        throwsA(
          isA<FluvieSpecError>().having((e) => e.path, 'path', ['scenes', '0', 'notes', 'text']),
        ),
      );
    });

    test('non-string highlights throw, for the list and for an entry', () {
      expect(
        () => VideoSpec.fromJson(_document(notes: const {'highlights': 'fix'})),
        throwsA(
          isA<FluvieSpecError>().having(
            (e) => e.path,
            'path',
            ['scenes', '0', 'notes', 'highlights'],
          ),
        ),
      );
      expect(
        () => VideoSpec.fromJson(
          _document(
            notes: const {
              'highlights': [1],
            },
          ),
        ),
        throwsA(
          isA<FluvieSpecError>().having(
            (e) => e.path,
            'path',
            ['scenes', '0', 'notes', 'highlights', '0'],
          ),
        ),
      );
    });

    test('a malformed per-step notes object throws at its own path', () {
      expect(
        () => VideoSpec.fromJson(
          _document(
            steps: const [
              {
                'elements': ['el-b1'],
                'notes': {'text': 3},
              },
            ],
          ),
        ),
        throwsA(
          isA<FluvieSpecError>().having(
            (e) => e.path,
            'path',
            ['scenes', '0', 'steps', '0', 'notes', 'text'],
          ),
        ),
      );
    });
  });

  group('round-trip', () {
    test('steps and notes come back verbatim from toJson', () {
      final json = _document(steps: _adrSteps, notes: _adrNotes);
      final scene =
          (VideoSpec.fromJson(json).toJson()['scenes']! as List).first as Map<String, Object?>;
      expect(scene['steps'], _adrSteps);
      expect(scene['notes'], _adrNotes);
    });

    test('re-serializing is idempotent', () {
      final once = VideoSpec.fromJson(_document(steps: _adrSteps, notes: _adrNotes)).toJson();
      expect(VideoSpec.fromJson(once).toJson(), once);
    });

    test('the digest counts steps and notes', () {
      final bare = VideoSpec.fromJson(_document()).digest();
      final stepped = VideoSpec.fromJson(_document(steps: _adrSteps)).digest();
      final noted = VideoSpec.fromJson(_document(notes: _adrNotes)).digest();
      expect(stepped, isNot(bare));
      expect(noted, isNot(bare));
      expect(stepped, isNot(noted));
    });
  });

  group('build ignores steps and notes', () {
    test('the built scenes are identical with and without them', () {
      final annotated = VideoSpec.fromJson(_document(steps: _adrSteps, notes: _adrNotes)).build();
      final bare = VideoSpec.fromJson(_document()).build();
      final annotatedScene = annotated.scenes.single;
      final bareScene = bare.scenes.single;
      expect(annotatedScene.children, hasLength(bareScene.children.length));
      for (var i = 0; i < bareScene.children.length; i++) {
        expect(annotatedScene.children[i].runtimeType, bareScene.children[i].runtimeType);
      }
    });
  });
}
