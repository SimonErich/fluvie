import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/core/defaults.dart';
import 'package:fluvie/src/core/ease.dart';
import 'package:fluvie/src/core/stagger.dart';
import 'package:fluvie/src/core/time.dart';

import 'fakes/fixed_time_scope.dart';

void main() {
  group('Defaults.package', () {
    test('carries the spec values: relative(0.2, max: 0.8s), Ease.smooth, no stagger', () {
      expect(
        Defaults.package.duration,
        const Time.relative(0.2, max: Time.seconds(0.8)),
      );
      expect(Defaults.package.ease, same(Ease.smooth));
      expect(Defaults.package.stagger, isNull);
    });

    test('duration resolves to 20% of a short window at 30 fps (cap inactive)', () {
      // 2-second window at 30 fps: 0.2 × 60 = 12 frames < cap (0.8 s = 24 frames).
      const scope = FixedTimeScope(fps: 30, durationFrames: 60);
      expect(Defaults.package.duration!.resolveFrames(scope), 12);
    });

    test('duration caps at 0.8s on a long window at 30 fps', () {
      // 20-second window at 30 fps: 0.2 × 600 = 120 frames, capped to 24.
      const scope = FixedTimeScope(fps: 30, durationFrames: 600);
      expect(Defaults.package.duration!.resolveFrames(scope), 24);
    });

    test('the cap follows fps: 0.8s is 48 frames at 60 fps', () {
      // 10-second window at 60 fps: 0.2 × 600 = 120 frames, capped to 48.
      const scope = FixedTimeScope(fps: 60, durationFrames: 600);
      expect(Defaults.package.duration!.resolveFrames(scope), 48);
    });
  });

  group('Defaults.mergeOver', () {
    test('non-null local fields win over the base', () {
      const base = Defaults(
        duration: Time.seconds(1),
        ease: Ease.gentle,
        stagger: Stagger.each(Time.ms(80)),
      );
      const local = Defaults(
        duration: Time.seconds(2),
        ease: Ease.snappy,
        stagger: Stagger.evenly(over: Time.seconds(1)),
      );
      final merged = local.mergeOver(base);
      expect(merged.duration, const Time.seconds(2));
      expect(merged.ease, same(Ease.snappy));
      expect(merged.stagger, const Stagger.evenly(over: Time.seconds(1)));
    });

    test('null local fields fall through to the base, per field', () {
      const base = Defaults(
        duration: Time.seconds(1),
        ease: Ease.gentle,
        stagger: Stagger.each(Time.ms(80)),
      );
      const local = Defaults(ease: Ease.snappy);
      final merged = local.mergeOver(base);
      expect(merged.duration, const Time.seconds(1));
      expect(merged.ease, same(Ease.snappy));
      expect(merged.stagger, const Stagger.each(Time.ms(80)));
    });

    test('the cascade composes: animation-local > scene > video > package', () {
      const video = Defaults(duration: Time.seconds(1), ease: Ease.linear);
      const scene = Defaults(duration: Time.seconds(0.5));
      const local = Defaults(stagger: Stagger.each(Time.ms(50)));
      final resolved = local.mergeOver(scene.mergeOver(video.mergeOver(Defaults.package)));
      expect(resolved.duration, const Time.seconds(0.5)); // scene wins over video
      expect(resolved.ease, same(Ease.linear)); // video wins over package
      expect(resolved.stagger, const Stagger.each(Time.ms(50))); // local
    });

    test('an empty Defaults merged over package keeps every package value', () {
      final merged = const Defaults().mergeOver(Defaults.package);
      expect(merged, Defaults.package);
    });
  });

  group('Defaults value semantics', () {
    test('value equality and hashCode', () {
      const a = Defaults(duration: Time.seconds(1), ease: Ease.smooth);
      const b = Defaults(duration: Time.seconds(1), ease: Ease.smooth);
      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(equals(const Defaults(duration: Time.seconds(2), ease: Ease.smooth))));
      expect(a, isNot(equals(const Defaults(duration: Time.seconds(1), ease: Ease.snappy))));
      expect(
        a,
        isNot(
          equals(
            const Defaults(
              duration: Time.seconds(1),
              ease: Ease.smooth,
              stagger: Stagger.each(Time.ms(80)),
            ),
          ),
        ),
      );
    });

    test('toString lists the fields', () {
      const defaults = Defaults(duration: Time.seconds(1));
      expect(defaults.toString(), contains('Defaults'));
      expect(defaults.toString(), contains('Time.seconds(1.0)'));
    });
  });
}
