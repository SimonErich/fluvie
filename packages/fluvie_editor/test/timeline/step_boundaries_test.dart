import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie_editor/fluvie_editor.dart';

/// The pure step-boundary math: marker frames mirror the presenter's settle
/// rule (max enter end per step, group children included, 0 without any),
/// and marker gestures partition step membership by each element's reveal
/// end against the marker frame.
void main() {
  // A slide with children a, b, c, d (child order); c is a group holding c1.
  // Enter ends (scene-relative): a=20, b=45, c none, c1=60, d=80.
  const topLevel = ['a', 'b', 'c', 'd'];
  List<String> childIdsOf(String id) => id == 'c' ? const ['c1'] : const [];
  int? enterEndOf(String id) => switch (id) {
    'a' => 20,
    'b' => 45,
    'c1' => 60,
    'd' => 80,
    _ => null,
  };

  SlideStepLayout layout(List<List<String>> stepIds) => computeStepLayout(
    topLevelIds: topLevel,
    stepIds: stepIds,
    childIdsOf: childIdsOf,
    enterEndOf: enterEndOf,
  );

  group('computeStepLayout', () {
    test('a slide without steps is one base step and no markers', () {
      final result = layout(const []);
      expect(result.memberIds, [topLevel]);
      expect(result.markerFrames, isEmpty);
    });

    test('markers sit at each step settle frame, matching the compiler rule', () {
      final result = layout(const [
        ['b'],
        ['c', 'd'],
      ]);
      expect(result.memberIds, [
        ['a'],
        ['b'],
        ['c', 'd'],
      ]);
      // Base settles at a's enter end; step 1 at b's; the last step has no
      // marker after it.
      expect(result.markerFrames, [20, 45]);
    });

    test('a group member settles by its deepest child entrance', () {
      final result = layout(const [
        ['c'],
      ]);
      // Base = a, b, d settles at 80; the marker after base is the only one.
      expect(result.markerFrames, [80]);
      expect(result.revealEnds['c'], 60);
    });

    test('an element with no entrance anywhere reveals at 0', () {
      final bare = computeStepLayout(
        topLevelIds: const ['x'],
        stepIds: const [],
        childIdsOf: (_) => const [],
        enterEndOf: (_) => null,
      );
      expect(bare.revealEnds['x'], 0);
      expect(bare.memberIds, [
        ['x'],
      ]);
    });

    test('step members keep scene child order whatever the authored order', () {
      final result = layout(const [
        ['d', 'b'],
      ]);
      expect(result.memberIds[1], ['b', 'd']);
    });
  });

  group('stepsAfterMarkerInsert', () {
    test('splitting the base step creates the first steps entry', () {
      final next = stepsAfterMarkerInsert(stepsJson: const [], layout: layout(const []), frame: 50);
      // a (20) and b (45) settle at or before 50; c (0) stays too; c1 puts
      // c at 60 so c moves with d into the new click step.
      expect(next, [
        {
          'elements': ['c', 'd'],
        },
      ]);
    });

    test('splitting a listed step keeps its notes on the earlier part', () {
      const steps = [
        {
          'elements': ['b', 'c', 'd'],
          'notes': {'text': 'reveal'},
        },
      ];
      final next = stepsAfterMarkerInsert(
        stepsJson: steps,
        layout: layout(const [
          ['b', 'c', 'd'],
        ]),
        frame: 62,
      );
      expect(next, [
        {
          'elements': ['b', 'c'],
          'notes': {'text': 'reveal'},
        },
        {
          'elements': ['d'],
        },
      ]);
    });

    test('a marker separating nothing is refused', () {
      final result = layout(const []);
      expect(stepsAfterMarkerInsert(stepsJson: const [], layout: result, frame: 100), isNull);
      // Frame 10 leaves only c (reveal 60 via c1)... a=20, b=45, d=80 later:
      // the earlier side would hold nothing revealed... actually c reveals at
      // 60 too, so everything is later than 5 except nothing: refused.
      expect(stepsAfterMarkerInsert(stepsJson: const [], layout: result, frame: 5), isNull);
    });

    test('the frame lands in the region between the surrounding markers', () {
      const steps = [
        {
          'elements': ['c', 'd'],
        },
      ];
      final result = layout(const [
        ['c', 'd'],
      ]);
      // Base settles at 45; a frame beyond that splits the listed step.
      final next = stepsAfterMarkerInsert(stepsJson: steps, layout: result, frame: 70);
      expect(next, [
        {
          'elements': ['c'],
        },
        {
          'elements': ['d'],
        },
      ]);
    });
  });

  group('stepsAfterMarkerMove', () {
    const steps = [
      {
        'elements': ['b'],
        'notes': {'text': 'first'},
      },
      {
        'elements': ['c', 'd'],
      },
    ];
    final result = layout(const [
      ['b'],
      ['c', 'd'],
    ]);

    test('dragging boundary 0 left moves an element out of the base step', () {
      final next = stepsAfterMarkerMove(stepsJson: steps, layout: result, boundary: 0, frame: 10);
      expect(next, [
        {
          'elements': ['a', 'b'],
          'notes': {'text': 'first'},
        },
        {
          'elements': ['c', 'd'],
        },
      ]);
    });

    test('dragging boundary 1 right pulls the next step apart', () {
      final next = stepsAfterMarkerMove(stepsJson: steps, layout: result, boundary: 1, frame: 62);
      expect(next, [
        {
          'elements': ['b', 'c'],
          'notes': {'text': 'first'},
        },
        {
          'elements': ['d'],
        },
      ]);
    });

    test('a move that would empty a listed step is refused', () {
      expect(
        stepsAfterMarkerMove(stepsJson: steps, layout: result, boundary: 1, frame: 100),
        isNull,
      );
      expect(
        stepsAfterMarkerMove(stepsJson: steps, layout: result, boundary: 0, frame: 50),
        isNull,
      );
    });

    test('emptying the base step is allowed', () {
      const single = [
        {
          'elements': ['c', 'd'],
        },
      ];
      final next = stepsAfterMarkerMove(
        stepsJson: single,
        layout: layout(const [
          ['c', 'd'],
        ]),
        boundary: 0,
        frame: 0,
      );
      expect(next, [
        {
          'elements': ['a', 'b', 'c', 'd'],
        },
      ]);
    });
  });

  group('stepsAfterMarkerRemove', () {
    const steps = [
      {
        'elements': ['b'],
        'notes': {'text': 'first'},
      },
      {
        'elements': ['c'],
        'notes': {'text': 'second'},
      },
      {
        'elements': ['d'],
      },
    ];

    test('removing boundary 0 folds the first step into the base', () {
      expect(stepsAfterMarkerRemove(stepsJson: steps, boundary: 0), [
        {
          'elements': ['c'],
          'notes': {'text': 'second'},
        },
        {
          'elements': ['d'],
        },
      ]);
    });

    test('removing a later boundary merges the pair, earlier notes winning', () {
      expect(stepsAfterMarkerRemove(stepsJson: steps, boundary: 1), [
        {
          'elements': ['b', 'c'],
          'notes': {'text': 'first'},
        },
        {
          'elements': ['d'],
        },
      ]);
    });

    test('a note-less earlier step adopts the merged notes', () {
      expect(stepsAfterMarkerRemove(stepsJson: steps, boundary: 2), [
        {
          'elements': ['b'],
          'notes': {'text': 'first'},
        },
        {
          'elements': ['c', 'd'],
          'notes': {'text': 'second'},
        },
      ]);
    });

    test('removing the only boundary empties the steps list', () {
      const single = [
        {
          'elements': ['b'],
        },
      ];
      expect(stepsAfterMarkerRemove(stepsJson: single, boundary: 0), isEmpty);
    });
  });
}
