import 'package:flutter/widgets.dart' hide Animation;
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/animation/animation.dart';
import 'package:fluvie/src/animation/effects/keyframe_effect.dart';
import 'package:fluvie/src/animation/runtime/animation_pipeline.dart';
import 'package:fluvie/src/animation/runtime/keyframe_scope.dart';
import 'package:fluvie/src/core/animation_phase.dart';
import 'package:fluvie/src/core/defaults.dart';
import 'package:fluvie/src/core/ease.dart';
import 'package:fluvie/src/core/keyframe.dart';
import 'package:fluvie/src/core/repeat.dart';
import 'package:fluvie/src/core/stagger.dart';
import 'package:fluvie/src/core/time.dart';
import 'package:fluvie/src/core/timing.dart';
import 'package:fluvie/src/core/trigger.dart';
import 'package:fluvie/src/timing/resolver/trigger_resolver.dart';
import 'package:fluvie/src/timing/schedule/element_schedule.dart';
import 'package:fluvie/src/timing/time_scope_data.dart';

const _blue = Color(0xFF0000FF);

void main() {
  group('Animation.color (D9)', () {
    test('expands to Animation.to(Keyframe(color: to)) — pure preset data', () {
      final color = Animation.color(to: _blue);
      final effect = color.effect as KeyframeEffect;
      expect(effect.from, Keyframe.natural);
      expect(effect.to, const Keyframe(color: _blue));
      expect(effect.to.opacity, isNull, reason: 'color is the only override');
    });

    test('plays as an exit, inferred from the to-expansion', () {
      expect(Animation.color(to: _blue).phase, AnimationPhase.exit);
    });

    test('forwards the full common tail verbatim', () {
      final color = Animation.color(
        to: _blue,
        duration: const Time.frames(20),
        ease: Ease.snappy,
        delay: const Time.frames(4),
        at: Trigger.sceneEnd,
        stagger: const Stagger.each(Time.frames(2)),
        repeat: const Repeat.times(2),
        label: 'tint',
      );
      expect(color.duration, const Time.frames(20));
      expect(color.ease, Ease.snappy);
      expect(color.delay, const Time.frames(4));
      expect(color.at, Trigger.sceneEnd);
      expect(color.stagger, const Stagger.each(Time.frames(2)));
      expect(color.repeat, const Repeat.times(2));
      expect(color.label, 'tint');
      expect(Animation.color(to: _blue, spring: Spring.gentle).spring, Spring.gentle);
    });

    testWidgets('KeyframeScope publishes the half-way lerped color at mid-frame', (tester) async {
      Keyframe? published;
      final probe = Builder(
        builder: (context) {
          published = KeyframeScope.maybeOf(context);
          return const SizedBox(width: 10, height: 10);
        },
      );
      await tester.pumpWidget(
        buildAnimatedFrame(
          child: probe,
          animations: [Animation.color(to: _blue)],
          schedule: const ElementSchedule(
            window: ResolvedSpan(0, 60),
            spans: [ResolvedSpan(0, 20)],
            defaults: Defaults(duration: Time.frames(20), ease: Ease.linear),
          ),
          elementScope: const TimeScopeData(fps: 30, startFrame: 0, durationFrames: 60),
          frame: 10,
        ),
      );
      expect(published, isNotNull);
      // Natural has no color, so the lerp fades in through transparency —
      // exactly what a color-capable element consumes in Phase 6.
      expect(published!.color, Color.lerp(null, _blue, 0.5));
    });
  });
}
