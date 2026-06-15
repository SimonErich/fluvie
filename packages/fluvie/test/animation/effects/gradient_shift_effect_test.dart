import 'package:flutter/widgets.dart' hide Animation;
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/animation/animation.dart';
import 'package:fluvie/src/animation/effect_kind.dart';
import 'package:fluvie/src/animation/effects/gradient_shift_effect.dart';
import 'package:fluvie/src/animation/runtime/animation_pipeline.dart';
import 'package:fluvie/src/animation/runtime/gradient_shift_scope.dart';
import 'package:fluvie/src/core/defaults.dart';
import 'package:fluvie/src/core/ease.dart';
import 'package:fluvie/src/core/time.dart';
import 'package:fluvie/src/timing/resolver/trigger_resolver.dart';
import 'package:fluvie/src/timing/schedule/element_schedule.dart';
import 'package:fluvie/src/timing/time_scope_data.dart';

const _blue = Color(0xFF0000FF);
const _green = Color(0xFF00FF00);

void main() {
  group('GradientShiftEffect (WI-20, D10)', () {
    test('classifies as a transform-class effect', () {
      expect(effectKindOf(const GradientShiftEffect([_blue])), EffectKind.transform);
    });

    test('build mounts the scope carrying progress, colors, and child verbatim', () {
      const effect = GradientShiftEffect([_blue, _green]);
      const child = SizedBox.shrink();
      final built = effect.build(child, 0.25);
      expect(built, isA<GradientShiftScope>());
      final scope = built as GradientShiftScope;
      expect(scope.progress, 0.25);
      expect(scope.colors, same(effect.to));
      expect(scope.child, same(child));
    });

    testWidgets('the pipeline holds: 0 before the span, the shift after it (D6)', (tester) async {
      Future<double?> progressAt(int frame) async {
        double? seen;
        await tester.pumpWidget(
          buildAnimatedFrame(
            child: Builder(
              builder: (context) {
                seen = GradientShiftScope.maybeOf(context)?.progress;
                return const SizedBox(width: 10, height: 10);
              },
            ),
            animations: [
              const Animation.custom(
                GradientShiftEffect([_blue]),
                duration: Time.frames(20),
                ease: Ease.linear,
                delay: Time.frames(10),
              ),
            ],
            schedule: const ElementSchedule(
              window: ResolvedSpan(0, 60),
              spans: [ResolvedSpan(10, 30)],
              defaults: Defaults(duration: Time.frames(20), ease: Ease.linear),
            ),
            elementScope: const TimeScopeData(fps: 30, startFrame: 0, durationFrames: 60),
            frame: frame,
          ),
        );
        return seen;
      }

      // Base before the span, lerping inside it, shifted (held at 1) after.
      expect(await progressAt(0), 0.0);
      expect(await progressAt(9), 0.0);
      expect(await progressAt(20), closeTo(0.5, 1e-9));
      expect(await progressAt(30), 1.0);
      expect(await progressAt(45), 1.0);
    });
  });
}
