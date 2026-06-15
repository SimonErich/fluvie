import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/composition/runtime/timeline_probe.dart';
import 'package:fluvie/src/timing/timeline/resolved_timeline.dart';

const _timeline = ResolvedTimeline(fps: 30, totalFrames: 60, rows: []);

void main() {
  group('TimelineProbe (WI-15, D21)', () {
    test('starts empty and notifies exactly once per push', () {
      final probe = TimelineProbe();
      expect(probe.value, isNull);
      var notifications = 0;
      probe
        ..addListener(() => notifications++)
        ..value = _timeline;
      expect(notifications, 1);
      expect(probe.value, same(_timeline));
      // Pushing the identical timeline again is a no-op (ValueNotifier).
      probe.value = _timeline;
      expect(notifications, 1);
      probe.dispose();
    });

    test('reportError sets timingError and notifies listeners', () {
      final probe = TimelineProbe();
      var notifications = 0;
      probe.addListener(() => notifications++);

      expect(probe.timingError, isNull);
      probe.reportError('no beat grid for track music');
      expect(probe.timingError, 'no beat grid for track music');
      expect(notifications, 1);
      probe.dispose();
    });

    test('assigning value clears a prior timingError', () {
      final probe = TimelineProbe()..reportError('some error');
      expect(probe.timingError, isNotNull);

      probe.value = _timeline;
      expect(probe.timingError, isNull);
      expect(probe.value, same(_timeline));
      probe.dispose();
    });
  });

  group('TimelineProbeScope (WI-15, D21)', () {
    testWidgets('maybeOf returns the mounted probe', (tester) async {
      final probe = TimelineProbe();
      TimelineProbe? seen;
      await tester.pumpWidget(
        TimelineProbeScope(
          probe: probe,
          child: Builder(
            builder: (context) {
              seen = TimelineProbeScope.maybeOf(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      expect(seen, same(probe));
      probe.dispose();
    });

    testWidgets('maybeOf returns null when no scope is mounted', (tester) async {
      Object? seen = 'unset';
      await tester.pumpWidget(
        Builder(
          builder: (context) {
            seen = TimelineProbeScope.maybeOf(context);
            return const SizedBox.shrink();
          },
        ),
      );
      expect(seen, isNull);
    });
  });
}
