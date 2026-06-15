import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/core/animation_phase.dart';
import 'package:fluvie/src/timing/resolver/composition_resolver.dart';
import 'package:fluvie/src/timing/timeline/debug_timeline.dart';
import 'package:fluvie/src/timing/timeline/resolved_timeline.dart';
import 'package:fluvie/src/timing/timeline/timeline_row.dart';

import '../helpers/worked_example.dart';

void main() {
  group('debugTimeline', () {
    test('renders the §26 worked example exactly (golden string)', () {
      final table = debugTimeline(resolveComposition(workedExample()));

      expect(
        table,
        'owner    | label     | phase  | start | end | frames\n'
        '---------+-----------+--------+-------+-----+-------\n'
        'title    | pop       | enter  |     0 |  36 |     36\n'
        'title    | slideFade | enter  |    39 |  57 |     18\n'
        'counter  | count     | enter  |    90 | 150 |     60\n'
        'stats-fx | grain     | during |    90 | 210 |    120\n'
        'stats-fx | vignette  | during |    90 | 210 |    120\n'
        'caption  | fadeIn    | enter  |   135 | 159 |     24\n'
        'outro    | blurIn    | enter  |   210 | 228 |     18\n'
        'outro    | float     | during |   210 | 300 |     90\n'
        'outro    | fadeOut   | exit   |   282 | 300 |     18\n'
        'total: 300 frames @ 30 fps\n',
      );
    });

    test('column widths derive from content: a long ownerId widens every line', () {
      const timeline = ResolvedTimeline(
        fps: 30,
        totalFrames: 100,
        rows: [
          TimelineRow(
            ownerId: 'a-very-long-owner-id',
            phase: AnimationPhase.enter,
            startFrame: 0,
            endFrame: 10,
          ),
          TimelineRow(ownerId: 'b', phase: AnimationPhase.exit, startFrame: 90, endFrame: 100),
        ],
      );

      final lines = debugTimeline(timeline).split('\n');
      // Header, separator, and the two rows all share one width.
      final tableLines = lines.sublist(0, 4);
      expect(tableLines.map((l) => l.length).toSet(), hasLength(1));
      expect(tableLines[0], startsWith('owner                | '));
      expect(tableLines[2], startsWith('a-very-long-owner-id | '));
      expect(tableLines[3], startsWith('b                    | '));
    });

    test('an unlabelled animation renders a dash in the label column', () {
      const timeline = ResolvedTimeline(
        fps: 30,
        totalFrames: 60,
        rows: [
          TimelineRow(ownerId: 'logo', phase: AnimationPhase.enter, startFrame: 0, endFrame: 12),
        ],
      );

      expect(
        debugTimeline(timeline),
        'owner | label | phase | start | end | frames\n'
        '------+-------+-------+-------+-----+-------\n'
        'logo  | -     | enter |     0 |  12 |     12\n'
        'total: 60 frames @ 30 fps\n',
      );
    });

    test('an empty timeline renders header and footer only', () {
      const timeline = ResolvedTimeline(fps: 30, totalFrames: 0, rows: []);

      expect(
        debugTimeline(timeline),
        'owner | label | phase | start | end | frames\n'
        '------+-------+-------+-------+-----+-------\n'
        'total: 0 frames @ 30 fps\n',
      );
    });

    test('warnings render as a block after the footer, in order', () {
      const timeline = ResolvedTimeline(
        fps: 30,
        totalFrames: 60,
        rows: [
          TimelineRow(ownerId: 'logo', phase: AnimationPhase.enter, startFrame: 0, endFrame: 90),
        ],
        warnings: ['first warning', 'second warning'],
      );

      expect(
        debugTimeline(timeline),
        endsWith(
          'total: 60 frames @ 30 fps\n'
          'warnings:\n'
          '  - first warning\n'
          '  - second warning\n',
        ),
      );
    });

    test('is byte-identical across two independent resolutions', () {
      final first = debugTimeline(resolveComposition(workedExample()));
      final second = debugTimeline(resolveComposition(workedExample()));

      expect(first, second);
      expect(first.codeUnits, second.codeUnits);
    });
  });
}
