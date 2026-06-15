import 'package:flutter/widgets.dart' hide Animation;
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/animation/animation.dart';
import 'package:fluvie/src/animation/effects/gradient_shift_effect.dart';
import 'package:fluvie/src/animation/runtime/local_schedule_resolver.dart';
import 'package:fluvie/src/core/animation_phase.dart';
import 'package:fluvie/src/core/ease.dart';
import 'package:fluvie/src/core/repeat.dart';
import 'package:fluvie/src/core/stagger.dart';
import 'package:fluvie/src/core/time.dart';
import 'package:fluvie/src/core/time_extensions.dart';
import 'package:fluvie/src/core/timing.dart';
import 'package:fluvie/src/core/trigger.dart';
import 'package:fluvie/src/timing/resolver/trigger_resolver.dart';
import 'package:fluvie/src/timing/time_scope_data.dart';

const _blue = Color(0xFF0000FF);
const _green = Color(0xFF00FF00);

void main() {
  group('Animation.gradientShift (WI-21, D10)', () {
    test('expands to Animation.custom(GradientShiftEffect(to)) carrying to verbatim', () {
      const to = [_blue, _green];
      final shift = Animation.gradientShift(to: to);
      expect(shift.effect, isA<GradientShiftEffect>());
      expect((shift.effect as GradientShiftEffect).to, same(to));
    });

    test('plays as an enter — start-anchored so the §3 arithmetic holds', () {
      expect(Animation.gradientShift(to: const [_blue]).phase, AnimationPhase.enter);
    });

    test('forwards the full common tail verbatim', () {
      final shift = Animation.gradientShift(
        to: const [_blue],
        duration: const Time.frames(20),
        ease: Ease.snappy,
        delay: const Time.frames(4),
        at: Trigger.sceneEnd,
        stagger: const Stagger.each(Time.frames(2)),
        repeat: const Repeat.times(2),
        label: 'shift',
      );
      expect(shift.duration, const Time.frames(20));
      expect(shift.ease, Ease.snappy);
      expect(shift.delay, const Time.frames(4));
      expect(shift.at, Trigger.sceneEnd);
      expect(shift.stagger, const Stagger.each(Time.frames(2)));
      expect(shift.repeat, const Repeat.times(2));
      expect(shift.label, 'shift');
      expect(
        Animation.gradientShift(to: const [_blue], spring: Spring.gentle).spring,
        Spring.gentle,
      );
    });

    test('§3 timing shape: relative delay and duration resolve to the 1s→4s span', () {
      // A 10 s scene at 30 fps: delay 0.1.relative = 30 frames, duration
      // 0.3.relative = 90 frames — the shift begins 1 s in and ends at 4 s,
      // which is exactly when `Trigger.after(bg)` fires in the quickstart.
      final schedule = resolveLocalSchedule(
        animations: [
          Animation.gradientShift(
            to: const [_blue, _green],
            duration: 0.3.relative,
            delay: 0.1.relative,
          ),
        ],
        window: null,
        sceneScope: const TimeScopeData(fps: 30, startFrame: 0, durationFrames: 300),
      );
      expect(schedule.spans.single, const ResolvedSpan(30, 120));
    });
  });
}
