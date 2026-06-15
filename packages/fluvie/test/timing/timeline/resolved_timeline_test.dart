import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/core/animation_phase.dart';
import 'package:fluvie/src/timing/timeline/resolved_timeline.dart';
import 'package:fluvie/src/timing/timeline/timeline_anchor.dart';
import 'package:fluvie/src/timing/timeline/timeline_row.dart';

void main() {
  group('TimelineAnchor', () {
    test('is value-equal: same fields compare equal with equal hashCodes', () {
      const anchor = TimelineAnchor(name: 'logo', frame: 0);
      const same = TimelineAnchor(name: 'logo', frame: 0);

      expect(anchor, same);
      expect(anchor.hashCode, same.hashCode);
    });

    test('any differing field breaks equality', () {
      const base = TimelineAnchor(name: 'logo', frame: 0);

      expect(base, isNot(const TimelineAnchor(name: 'beat', frame: 0)));
      expect(base, isNot(const TimelineAnchor(name: 'logo', frame: 12)));
    });

    test('toString names both fields', () {
      expect(const TimelineAnchor(name: 'logo', frame: 90).toString(), 'TimelineAnchor(logo @ 90)');
    });
  });

  const row = TimelineRow(
    ownerId: 'logo',
    label: 'pop',
    phase: AnimationPhase.enter,
    startFrame: 0,
    endFrame: 36,
  );

  group('TimelineRow', () {
    test('is value-equal: same fields compare equal with equal hashCodes', () {
      const same = TimelineRow(
        ownerId: 'logo',
        label: 'pop',
        phase: AnimationPhase.enter,
        startFrame: 0,
        endFrame: 36,
      );

      expect(row, same);
      expect(row.hashCode, same.hashCode);
    });

    test('any differing field breaks equality', () {
      const base = TimelineRow(
        ownerId: 'a',
        phase: AnimationPhase.during,
        startFrame: 5,
        endFrame: 9,
      );

      expect(
        base,
        isNot(
          const TimelineRow(ownerId: 'b', phase: AnimationPhase.during, startFrame: 5, endFrame: 9),
        ),
      );
      expect(
        base,
        isNot(
          const TimelineRow(
            ownerId: 'a',
            label: 'x',
            phase: AnimationPhase.during,
            startFrame: 5,
            endFrame: 9,
          ),
        ),
      );
      expect(
        base,
        isNot(
          const TimelineRow(ownerId: 'a', phase: AnimationPhase.exit, startFrame: 5, endFrame: 9),
        ),
      );
      expect(
        base,
        isNot(
          const TimelineRow(ownerId: 'a', phase: AnimationPhase.during, startFrame: 6, endFrame: 9),
        ),
      );
      expect(
        base,
        isNot(
          const TimelineRow(ownerId: 'a', phase: AnimationPhase.during, startFrame: 5, endFrame: 8),
        ),
      );
    });

    test('durationFrames is endFrame - startFrame', () {
      expect(row.durationFrames, 36);
    });

    test('toString is stable and names every field', () {
      expect(row.toString(), 'TimelineRow(logo, pop, enter, 0..36)');
      expect(
        const TimelineRow(
          ownerId: 'a',
          phase: AnimationPhase.exit,
          startFrame: 5,
          endFrame: 9,
        ).toString(),
        'TimelineRow(a, exit, 5..9)',
      );
    });
  });

  group('ResolvedTimeline', () {
    const other = TimelineRow(
      ownerId: 'subtitle',
      phase: AnimationPhase.exit,
      startFrame: 50,
      endFrame: 70,
    );
    const second = TimelineRow(
      ownerId: 'logo',
      label: 'fade',
      phase: AnimationPhase.exit,
      startFrame: 80,
      endFrame: 90,
    );
    const timeline = ResolvedTimeline(
      fps: 30,
      totalFrames: 300,
      rows: [row, other, second],
    );

    test('rowsFor filters by ownerId, preserving row order', () {
      expect(timeline.rowsFor('logo'), const [row, second]);
      expect(timeline.rowsFor('subtitle'), const [other]);
      expect(timeline.rowsFor('absent'), isEmpty);
    });

    test('warnings default to empty', () {
      expect(timeline.warnings, isEmpty);
    });

    test('anchors default to empty', () {
      expect(timeline.anchors, isEmpty);
    });

    test('carries the structured anchor egress when given', () {
      const anchored = ResolvedTimeline(
        fps: 30,
        totalFrames: 300,
        rows: [row],
        anchors: [TimelineAnchor(name: 'logo', frame: 0)],
      );

      expect(anchored.anchors, const [TimelineAnchor(name: 'logo', frame: 0)]);
    });

    test('toString is stable and summarises the timeline', () {
      expect(
        timeline.toString(),
        'ResolvedTimeline(fps: 30, totalFrames: 300, rows: 3, warnings: 0)',
      );
    });
  });
}
