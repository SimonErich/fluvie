import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/core/animation_phase.dart';
import 'package:fluvie/src/diagnostics/inspector_model.dart';
import 'package:fluvie/src/timing/resolver/composition_resolver.dart';
import 'package:fluvie/src/timing/timeline/resolved_timeline.dart';
import 'package:fluvie/src/timing/timeline/timeline_anchor.dart';
import 'package:fluvie/src/timing/timeline/timeline_row.dart';

import '../timing/helpers/worked_example.dart';

const _timeline = ResolvedTimeline(
  fps: 30,
  totalFrames: 300,
  rows: [
    TimelineRow(
      ownerId: 'title',
      label: 'pop',
      phase: AnimationPhase.enter,
      startFrame: 0,
      endFrame: 36,
    ),
    TimelineRow(
      ownerId: 'outro',
      phase: AnimationPhase.during,
      startFrame: 210,
      endFrame: 300,
    ),
  ],
  anchors: [TimelineAnchor(name: 'logo', frame: 0)],
  warnings: ['something overhangs'],
);

void main() {
  group('InspectorMotion', () {
    test('jumpFrame is the start frame: the scrub target', () {
      const motion = InspectorMotion(
        ownerId: 'title',
        label: 'pop',
        phase: AnimationPhase.enter,
        startFrame: 42,
        endFrame: 80,
      );

      expect(motion.jumpFrame, 42);
      expect(motion.durationFrames, 38);
    });

    test('is value-equal with equal hashCodes', () {
      const a = InspectorMotion(
        ownerId: 'x',
        phase: AnimationPhase.during,
        startFrame: 1,
        endFrame: 9,
      );
      const b = InspectorMotion(
        ownerId: 'x',
        phase: AnimationPhase.during,
        startFrame: 1,
        endFrame: 9,
      );

      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('any differing field breaks equality', () {
      const base = InspectorMotion(
        ownerId: 'x',
        label: 'l',
        phase: AnimationPhase.during,
        startFrame: 1,
        endFrame: 9,
      );

      expect(
        base,
        isNot(
          const InspectorMotion(
            ownerId: 'y',
            label: 'l',
            phase: AnimationPhase.during,
            startFrame: 1,
            endFrame: 9,
          ),
        ),
      );
      expect(
        base,
        isNot(
          const InspectorMotion(
            ownerId: 'x',
            phase: AnimationPhase.during,
            startFrame: 1,
            endFrame: 9,
          ),
        ),
      );
      expect(
        base,
        isNot(
          const InspectorMotion(
            ownerId: 'x',
            label: 'l',
            phase: AnimationPhase.enter,
            startFrame: 1,
            endFrame: 9,
          ),
        ),
      );
    });

    test('toString names every field', () {
      const motion = InspectorMotion(
        ownerId: 'title',
        label: 'pop',
        phase: AnimationPhase.enter,
        startFrame: 0,
        endFrame: 36,
      );
      expect(motion.toString(), 'InspectorMotion(title, pop, enter, 0..36)');
    });
  });

  group('InspectorModel.fromTimeline', () {
    test('copies fps and totalFrames straight from the timeline', () {
      final model = InspectorModel.fromTimeline(_timeline);

      expect(model.fps, 30);
      expect(model.totalFrames, 300);
    });

    test('maps each row to a motion, carrying the jump frame', () {
      final model = InspectorModel.fromTimeline(_timeline);

      expect(model.motions, const [
        InspectorMotion(
          ownerId: 'title',
          label: 'pop',
          phase: AnimationPhase.enter,
          startFrame: 0,
          endFrame: 36,
        ),
        InspectorMotion(
          ownerId: 'outro',
          phase: AnimationPhase.during,
          startFrame: 210,
          endFrame: 300,
        ),
      ]);
      expect(model.motions.first.jumpFrame, 0);
      expect(model.motions.last.jumpFrame, 210);
    });

    test('surfaces the structured anchors verbatim', () {
      final model = InspectorModel.fromTimeline(_timeline);

      expect(model.anchors, const [TimelineAnchor(name: 'logo', frame: 0)]);
    });

    test('surfaces the timeline warnings verbatim (never re-parsed)', () {
      final model = InspectorModel.fromTimeline(_timeline);

      expect(model.warnings, const ['something overhangs']);
    });

    test('an empty timeline yields an empty model', () {
      const empty = ResolvedTimeline(fps: 24, totalFrames: 0, rows: []);

      final model = InspectorModel.fromTimeline(empty);

      expect(model.fps, 24);
      expect(model.totalFrames, 0);
      expect(model.motions, isEmpty);
      expect(model.anchors, isEmpty);
      expect(model.warnings, isEmpty);
    });

    test('is deterministic: the same timeline builds an equal model twice', () {
      final first = InspectorModel.fromTimeline(_timeline);
      final second = InspectorModel.fromTimeline(_timeline);

      expect(first, second);
      expect(first.hashCode, second.hashCode);
    });

    test('different timelines build unequal models', () {
      final model = InspectorModel.fromTimeline(_timeline);
      const other = ResolvedTimeline(fps: 30, totalFrames: 120, rows: []);

      expect(model, isNot(InspectorModel.fromTimeline(other)));
    });

    test('a model differing only in one motion element is unequal (same lengths)', () {
      final model = InspectorModel.fromTimeline(_timeline);
      final differingRow = InspectorModel.fromTimeline(
        const ResolvedTimeline(
          fps: 30,
          totalFrames: 300,
          rows: [
            TimelineRow(
              ownerId: 'title',
              label: 'pop',
              phase: AnimationPhase.enter,
              startFrame: 0,
              endFrame: 36,
            ),
            // Same length as _timeline's rows, but this second row differs.
            TimelineRow(
              ownerId: 'outro',
              phase: AnimationPhase.during,
              startFrame: 210,
              endFrame: 299,
            ),
          ],
          anchors: [TimelineAnchor(name: 'logo', frame: 0)],
          warnings: ['something overhangs'],
        ),
      );

      expect(model, isNot(differingRow));
    });

    test('a model differing only in one anchor or warning is unequal', () {
      const rows = [
        TimelineRow(
          ownerId: 'title',
          label: 'pop',
          phase: AnimationPhase.enter,
          startFrame: 0,
          endFrame: 36,
        ),
        TimelineRow(
          ownerId: 'outro',
          phase: AnimationPhase.during,
          startFrame: 210,
          endFrame: 300,
        ),
      ];
      final model = InspectorModel.fromTimeline(_timeline);
      final differingAnchor = InspectorModel.fromTimeline(
        const ResolvedTimeline(
          fps: 30,
          totalFrames: 300,
          rows: rows,
          anchors: [TimelineAnchor(name: 'intro', frame: 0)],
          warnings: ['something overhangs'],
        ),
      );
      final differingWarning = InspectorModel.fromTimeline(
        const ResolvedTimeline(
          fps: 30,
          totalFrames: 300,
          rows: rows,
          anchors: [TimelineAnchor(name: 'logo', frame: 0)],
          warnings: ['a different warning'],
        ),
      );

      expect(model, isNot(differingAnchor));
      expect(model, isNot(differingWarning));
    });

    test('toString summarises the model', () {
      final model = InspectorModel.fromTimeline(_timeline);

      expect(
        model.toString(),
        'InspectorModel(fps: 30, totalFrames: 300, motions: 2, anchors: 1, warnings: 1)',
      );
    });

    test('builds the §26 worked example from a real resolution', () {
      final model = InspectorModel.fromTimeline(resolveComposition(workedExample()));

      expect(model.fps, 30);
      expect(model.totalFrames, 300);
      expect(model.motions, hasLength(9));
      expect(model.motions.first.ownerId, 'title');
      expect(model.motions.first.label, 'pop');
      expect(model.anchors, const [TimelineAnchor(name: 'logo', frame: 0)]);
      expect(model.warnings, isEmpty);
    });
  });
}
