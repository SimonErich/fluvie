import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/core/defaults.dart';
import 'package:fluvie/src/timing/resolver/trigger_resolver.dart';
import 'package:fluvie/src/timing/schedule/element_schedule.dart';
import 'package:fluvie/src/timing/schedule/resolved_schedule_scope.dart';

const _outer = ElementSchedule(
  window: ResolvedSpan(0, 90),
  spans: [ResolvedSpan(0, 12)],
  defaults: Defaults(),
);

const _inner = ElementSchedule(
  window: ResolvedSpan(30, 60),
  spans: [ResolvedSpan(30, 42)],
  defaults: Defaults(),
);

/// A leaf reporting `ResolvedScheduleScope.maybeOf` to [onSchedule].
Widget _probe(void Function(ElementSchedule? schedule) onSchedule) => Builder(
  builder: (context) {
    onSchedule(ResolvedScheduleScope.maybeOf(context));
    return const SizedBox.shrink();
  },
);

void main() {
  group('ResolvedScheduleScope', () {
    testWidgets('maybeOf returns the nearest schedule', (tester) async {
      ElementSchedule? seen;
      await tester.pumpWidget(
        ResolvedScheduleScope(schedule: _outer, child: _probe((schedule) => seen = schedule)),
      );
      expect(seen, _outer);
    });

    testWidgets('absent scope yields null — the local-fallback signal, never a throw', (
      tester,
    ) async {
      ElementSchedule? seen = _outer;
      await tester.pumpWidget(_probe((schedule) => seen = schedule));
      expect(seen, isNull);
      expect(tester.takeException(), isNull);
    });

    testWidgets('nested scopes: the nearest wins', (tester) async {
      ElementSchedule? seen;
      await tester.pumpWidget(
        ResolvedScheduleScope(
          schedule: _outer,
          child: ResolvedScheduleScope(
            schedule: _inner,
            child: _probe((schedule) => seen = schedule),
          ),
        ),
      );
      expect(seen, _inner);
    });

    testWidgets('updateShouldNotify fires only when the schedule changes', (tester) async {
      final log = <ElementSchedule?>[];
      // One probe instance across pumps: identical child widgets never
      // rebuild on their own, so a rebuild can only come from notification.
      final probe = _probe(log.add);

      await tester.pumpWidget(ResolvedScheduleScope(schedule: _outer, child: probe));
      await tester.pumpWidget(ResolvedScheduleScope(schedule: _outer, child: probe));
      await tester.pumpWidget(ResolvedScheduleScope(schedule: _inner, child: probe));
      expect(log, [_outer, _inner]);
    });
  });
}
