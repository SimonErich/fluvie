// Every effect a stack can carry, at two strengths, over one subject. The
// pairs are what prove a parameter is a parameter: a stack that ignored the
// number would paint two identical cells. Subjects stay font-free (D20).
@Tags(['golden'])
library;

import 'package:alchemist/alchemist.dart';
import 'package:flutter/widgets.dart' hide Animation, Clip, Image, Tween;
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/fluvie.dart';

/// The subject every cell grades: a plain filled square, so what changes
/// between two cells is the effect and nothing else.
Widget _subject() => const Center(
  child: DecoratedBox(
    decoration: BoxDecoration(color: Color(0xFF2ECC8F)),
    child: SizedBox(width: 90, height: 90),
  ),
);

/// One cell: the subject under [effects], mid-scene so a progress-driven
/// effect has somewhere to be.
GoldenTestScenario _cell(String name, List<EffectLayer> effects) => GoldenTestScenario(
  name: name,
  child: SizedBox(
    width: 130,
    height: 130,
    child: RenderModeContext(
      mode: RenderMode.capture,
      child: RenderControllerScope(
        controller: RenderController(initialFrame: 15),
        child: Video(
          width: 130,
          height: 130,
          scenes: [
            Scene(
              duration: const Time.frames(30),
              children: [_subject().effects(effects)],
            ),
          ],
        ),
      ),
    ),
  ),
);

Future<void> main() async {
  await goldenTest(
    'every effect at two strengths, so a parameter is visibly a parameter',
    fileName: 'effect_stack',
    builder: () => GoldenTestGroup(
      columns: 4,
      children: [
        _cell('grain 0.2', [Effect.grain()]),
        _cell('grain 0.9', [Effect.grain(amount: 0.9)]),
        _cell('vignette 0.4', [Effect.vignette()]),
        _cell('vignette 0.9', [Effect.vignette(amount: 0.9)]),
        _cell('scanlines 3', [Effect.scanlines()]),
        _cell('scanlines 8', [Effect.scanlines(spacing: 8, opacity: 0.7)]),
        _cell('chromatic 2', [Effect.chromatic()]),
        _cell('chromatic 10', [Effect.chromatic(px: 10)]),
        _cell('bloom 0.4', [Effect.bloom()]),
        _cell('bloom 0.9', [Effect.bloom(amount: 0.9)]),
        _cell('glitch left', [Effect.glitch()]),
        _cell('glitch right rev', [Effect.glitch(from: 'right', reverse: true)]),
        _cell('parallax 0.2', [Effect.parallax()]),
        _cell('parallax -0.4', [Effect.parallax(depth: -0.4)]),
        _cell('stacked', [Effect.grain(amount: 0.5), Effect.vignette(amount: 0.7)]),
        _cell('none', const []),
      ],
    ),
  );
}
