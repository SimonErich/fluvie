// Building an element's effect stack. The order is a property of each
// effect's class, not of where the author typed it, so a spec-built tree and
// a hand-written one are the same tree.

import 'package:flutter/widgets.dart' hide Animation, Clip, Image, Tween;
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/fluvie.dart';
import 'package:fluvie/src/animation/effects/grain_effect.dart';
import 'package:fluvie/src/animation/effects/parallax_effect.dart';
import 'package:fluvie/src/animation/effects/vignette_effect.dart';
import 'package:fluvie/src/animation/motion_target.dart';
import 'package:fluvie/src/animation/runtime/effect_stack.dart';
import 'package:fluvie/src/serialization/effect_builder.dart';

EffectSpec _effect(String kind, {bool enabled = true, Map<String, Object?> params = const {}}) =>
    EffectSpec(EffectSpecKind.fromJson(kind), enabled: enabled, params: params);

Future<void> _pump(WidgetTester tester, VideoSpec spec) async {
  await tester.pumpWidget(
    Directionality(
      textDirection: TextDirection.ltr,
      child: RenderControllerScope(
        controller: RenderController(),
        child: spec.build(),
      ),
    ),
  );
  await tester.pump();
}

/// The stack's effects as they resolve at the element's first frame.
List<AnimationEffect> _stackOf(List<EffectSpec> specs) =>
    _resolved(buildEffectStack(specs, const SizedBox.shrink()));

/// Every effect [built] mounts, resolved at the start of its element.
List<AnimationEffect> _resolved(Widget built) =>
    built is EffectStack ? [for (final layer in built.effects) layer.resolve(_first)] : const [];

/// The frame a still effect reads the same at as every other.
const EffectFrame _first = (progress: 0, fps: 30, windowFrames: 30);

void main() {
  group('the composed stack', () {
    test('mounts nothing at all for an element with no effects', () {
      const child = SizedBox.shrink();

      expect(identical(buildEffectStack(const [], child), child), isTrue);
    });

    test('puts transform-class effects innermost and pixel-class outermost', () {
      // Typed pixel-first; composed transform-first, because the class decides
      // and not the typing.
      final stack = _stackOf([_effect('grain'), _effect('parallax')]);

      expect(stack.first, isA<ParallaxEffect>());
      expect(stack.last, isA<GrainEffect>());
    });

    test('keeps list order within a class', () {
      final stack = _stackOf([_effect('grain'), _effect('vignette')]);

      expect(stack.first, isA<GrainEffect>());
      expect(stack.last, isA<VignetteEffect>());
    });

    test('leaves a disabled effect out of the mounted tree', () {
      final stack = _stackOf([_effect('grain', enabled: false), _effect('vignette')]);

      expect(stack, hasLength(1));
      expect(stack.single, isA<VignetteEffect>());
    });

    test('passes the child straight through when every effect is off', () {
      // A disabled layer is not a hidden element: it must not collapse the
      // subtree the way `visible: false` does.
      const child = SizedBox.shrink();
      final built = buildEffectStack([_effect('grain', enabled: false)], child);

      expect(identical(built, child), isTrue);
    });
  });

  group('each effect on its own parameters', () {
    test('takes the value the document names', () {
      final effect = buildEffect(_effect('grain', params: {'amount': 0.75})) as GrainEffect;

      expect(effect.amount, 0.75);
    });

    test('takes the kind default where the document is silent', () {
      // The defaults are the effect's own current values, so a stack that
      // names nothing renders exactly what it rendered before.
      final effect = buildEffect(_effect('grain')) as GrainEffect;

      expect(effect.amount, EffectSpecKind.grain.params.single.defaultValue);
    });

    test('builds every kind Fluvie knows without throwing', () {
      for (final kind in EffectSpecKind.values) {
        expect(
          () => buildEffect(
            EffectSpec(
              kind,
              params: kind == EffectSpecKind.shader ? const {'asset': 'shaders/x.frag'} : const {},
            ),
          ),
          returnsNormally,
          reason: kind.name,
        );
      }
    });
  });

  group('the built element', () {
    testWidgets('wraps the element inside its animate wrapper', (tester) async {
      // The stack sits between the element and its MotionTarget, so the
      // element's window and animations still drive the whole thing.
      final spec = VideoSpec.fromJson({
        'fluvieSpec': 1,
        'fps': 30,
        'scenes': [
          {
            'duration': '30f',
            'children': [
              {
                'id': 'el-a',
                'type': 'Text',
                'text': 'one',
                'effects': [
                  {'kind': 'grain', 'amount': 0.5},
                ],
                'animate': [
                  {'preset': 'fadeIn', 'duration': '10f'},
                ],
              },
            ],
          },
        ],
      });

      await _pump(tester, spec);

      expect(find.byType(EffectStack), findsOneWidget);
      expect(
        find.ancestor(of: find.byType(EffectStack), matching: find.byType(MotionTarget)),
        findsOneWidget,
        reason: 'the stack is inside the animate wrapper',
      );
    });

    testWidgets('mounts no stack for an element that declares none', (tester) async {
      final spec = VideoSpec.fromJson({
        'fluvieSpec': 1,
        'fps': 30,
        'scenes': [
          {
            'duration': '30f',
            'children': [
              {'id': 'el-a', 'type': 'Text', 'text': 'one'},
            ],
          },
        ],
      });

      await _pump(tester, spec);

      expect(find.byType(EffectStack), findsNothing);
    });
  });
}
