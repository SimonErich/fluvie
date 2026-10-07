// The spec-built stack and the hand-written one are the same tree. That is
// what makes `fluvie print` honest: the Dart it emits renders the document it
// came from, not something close to it.

import 'package:flutter/widgets.dart' hide Animation, Clip, Image, Tween;
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/fluvie.dart';
import 'package:fluvie/src/animation/effects/grain_effect.dart';
import 'package:fluvie/src/animation/effects/parallax_effect.dart';
import 'package:fluvie/src/animation/effects/vignette_effect.dart';
import 'package:fluvie/src/animation/runtime/effect_stack.dart';
import 'package:fluvie/src/serialization/effect_builder.dart';

List<AnimationEffect> _effectsOf(Widget built) =>
    built is EffectStack ? [for (final layer in built.effects) layer.resolve(_first)] : const [];

/// The frame a still effect reads the same at as every other.
const EffectFrame _first = (progress: 0, fps: 30, windowFrames: 30);

void main() {
  group('the hand-written stack', () {
    test('orders exactly like the spec-built one', () {
      // Typed pixel-first in both spellings; both compose transform-first.
      final handWritten = _effectsOf(
        const SizedBox.shrink().effects([Effect.grain(), Effect.parallax()]),
      );
      final specBuilt = _effectsOf(
        buildEffectStack(const [
          EffectSpec(EffectSpecKind.grain),
          EffectSpec(EffectSpecKind.parallax),
        ], const SizedBox.shrink()),
      );

      expect(handWritten.map((e) => e.runtimeType), specBuilt.map((e) => e.runtimeType));
      expect(handWritten.first, isA<ParallaxEffect>());
      expect(handWritten.last, isA<GrainEffect>());
    });

    test('keeps list order within a class, like the spec-built one', () {
      final stack = _effectsOf(
        const SizedBox.shrink().effects([Effect.grain(), Effect.vignette()]),
      );

      expect(stack.first, isA<GrainEffect>());
      expect(stack.last, isA<VignetteEffect>());
    });

    test('wraps nothing at all for an empty list', () {
      const child = SizedBox.shrink();

      expect(identical(child.effects(const []), child), isTrue);
    });

    test('carries the same parameters the spec defaults name', () {
      // One set of defaults, spelled twice: the facade and the kind must not
      // drift, or printed Dart would render a different grain from its spec.
      for (final kind in EffectSpecKind.values) {
        for (final param in kind.params) {
          final fromSpec = EffectSpec(kind).number(param.name);
          expect(fromSpec, param.defaultValue, reason: '${kind.name}.${param.name}');
        }
      }
    });

    test('a facade default matches its spec default, effect by effect', () {
      expect(
        (Effect.grain().resolve(_first) as GrainEffect).amount,
        const EffectSpec(EffectSpecKind.grain).number('amount'),
      );
      expect(
        (Effect.vignette().resolve(_first) as VignetteEffect).amount,
        const EffectSpec(EffectSpecKind.vignette).number('amount'),
      );
      expect(
        (Effect.parallax().resolve(_first) as ParallaxEffect).depth,
        const EffectSpec(EffectSpecKind.parallax).number('depth'),
      );
    });
  });

  group('identical frames', () {
    // The whole point of `fluvie print`: the Dart it emits renders the
    // document it came from. Both spellings of one keyframed stack, same
    // frame, same pixels.
    Widget frame(Widget subject) => RenderModeContext(
      mode: RenderMode.capture,
      child: RenderControllerScope(
        controller: RenderController(initialFrame: 20),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: Center(
            child: RepaintBoundary(
              child: SizedBox(width: 96, height: 96, child: subject),
            ),
          ),
        ),
      ),
    );

    Widget subject(Widget Function(Widget child) wrap) => Video(
      width: 96,
      height: 96,
      scenes: [
        Scene(
          duration: const Time.frames(40),
          children: [wrap(const Box(color: Color(0xFF2ECC8F)))],
        ),
      ],
    );

    testWidgets('the spec-built and widget-authored stacks paint the same pixels', (tester) async {
      final specBuilt = VideoSpec.fromJson({
        'fluvieSpec': 1,
        'size': {'width': 96, 'height': 96},
        'fps': 30,
        'scenes': [
          {
            'duration': '40f',
            'children': [
              {
                'id': 'el-a',
                'type': 'Box',
                'color': '#2ECC8F',
                'effects': [
                  {
                    'kind': 'vignette',
                    'amount': {
                      'values': [0, 0.9],
                      'positions': ['0f', '40f'],
                    },
                  },
                  {'kind': 'grain', 'amount': 0.5, 'enabled': false},
                ],
              },
            ],
          },
        ],
      }).build();

      await tester.pumpWidget(frame(specBuilt));
      final reference = await captureImage(find.byType(RepaintBoundary).evaluate().single);

      final handWritten = subject(
        (child) => child.effects([
          Effect.spec(
            EffectSpec(
              EffectSpecKind.vignette,
              params: {
                'amount': KeyframedNumber.linear(
                  values: const [0, 0.9],
                  positions: const [Time.zero, Time.frames(40)],
                ),
              },
            ),
          ),
          Effect.spec(
            const EffectSpec(EffectSpecKind.grain, enabled: false, params: {'amount': 0.5}),
          ),
        ]),
      );
      await tester.pumpWidget(frame(handWritten));

      await expectLater(
        find.byType(RepaintBoundary),
        matchesReferenceImage(reference),
      );
    });
  });

  group('the spec spelling', () {
    // The one spelling a keyframed parameter has in printed Dart, so it must
    // render exactly what the document said.
    test('reads a keyframed parameter off the frame', () {
      final layer = Effect.spec(
        EffectSpec(
          EffectSpecKind.grain,
          params: {
            'amount': KeyframedNumber.linear(
              values: const [0, 0.9],
              positions: const [Time.zero, Time.frames(30)],
            ),
          },
        ),
      );

      expect((layer.resolve(_first) as GrainEffect).amount, 0);
      expect(
        (layer.resolve((progress: 1, fps: 30, windowFrames: 30)) as GrainEffect).amount,
        closeTo(0.9, 1e-9),
      );
      expect(layer.isPixel, isTrue);
    });

    test('a disabled effect leaves its child untouched', () {
      // Off in the document means off through every spelling: the builder
      // skips it, so the facade must mount nothing either.
      const child = SizedBox.shrink();
      final layer = Effect.spec(const EffectSpec(EffectSpecKind.grain, enabled: false));

      expect(identical(layer.resolve(_first).build(child, 0), child), isTrue);
    });
  });
}
