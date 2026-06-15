import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/core/defaults.dart';
import 'package:fluvie/src/core/ease.dart';
import 'package:fluvie/src/core/time.dart';
import 'package:fluvie/src/timing/resolver/trigger_resolver.dart';
import 'package:fluvie/src/timing/schedule/element_schedule.dart';

void main() {
  group('ElementSchedule', () {
    const defaults = Defaults(duration: Time.frames(12), ease: Ease.linear);

    test('value equality includes the spans list contents', () {
      const a = ElementSchedule(
        window: ResolvedSpan(0, 90),
        spans: [ResolvedSpan(0, 12), ResolvedSpan(78, 90)],
        defaults: defaults,
      );
      const b = ElementSchedule(
        window: ResolvedSpan(0, 90),
        spans: [ResolvedSpan(0, 12), ResolvedSpan(78, 90)],
        defaults: defaults,
      );
      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
    });

    test('schedules with different span contents are unequal', () {
      const a = ElementSchedule(
        window: ResolvedSpan(0, 90),
        spans: [ResolvedSpan(0, 12)],
        defaults: defaults,
      );
      const b = ElementSchedule(
        window: ResolvedSpan(0, 90),
        spans: [ResolvedSpan(0, 13)],
        defaults: defaults,
      );
      expect(a, isNot(equals(b)));
    });

    test('schedules with different span counts are unequal', () {
      const a = ElementSchedule(
        window: ResolvedSpan(0, 90),
        spans: [ResolvedSpan(0, 12)],
        defaults: defaults,
      );
      const b = ElementSchedule(
        window: ResolvedSpan(0, 90),
        spans: [ResolvedSpan(0, 12), ResolvedSpan(0, 12)],
        defaults: defaults,
      );
      expect(a, isNot(equals(b)));
    });

    test('schedules with different windows or defaults are unequal', () {
      const a = ElementSchedule(window: ResolvedSpan(0, 90), spans: [], defaults: defaults);
      const differentWindow = ElementSchedule(
        window: ResolvedSpan(0, 60),
        spans: [],
        defaults: defaults,
      );
      const differentDefaults = ElementSchedule(
        window: ResolvedSpan(0, 90),
        spans: [],
        defaults: Defaults(duration: Time.frames(30)),
      );
      expect(a, isNot(equals(differentWindow)));
      expect(a, isNot(equals(differentDefaults)));
    });

    test('toString is stable and names every part', () {
      const schedule = ElementSchedule(
        window: ResolvedSpan(0, 90),
        spans: [ResolvedSpan(0, 12)],
        defaults: defaults,
      );
      expect(
        schedule.toString(),
        'ElementSchedule(window: ResolvedSpan(0..90), spans: [ResolvedSpan(0..12)], '
        'defaults: ${schedule.defaults})',
      );
    });
  });
}
