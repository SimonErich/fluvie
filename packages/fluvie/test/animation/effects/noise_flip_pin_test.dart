// WI-15: the noise-flip determinism pin (the D2 proof). The Phase 9
// grain/glitch/particles/float goldens render byte-identical after the seam
// flip (proven by `flutter test --tags golden` passing with NO --update-goldens
// on goldens_pixel/particles/ambient). This file pins the math directly so a
// regression in the flip fails here too, and pins `Animation.float(seed:)`
// reproducible across two runs (same seed -> identical sequence, §14.4).
import 'dart:typed_data' show ByteData;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart' hide Animation, Clip, Image, Tween;
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/animation/animation.dart';
import 'package:fluvie/src/animation/effects/float_effect.dart';
import 'package:fluvie/src/animation/effects/grain_effect.dart';
import 'package:fluvie/src/animation/effects/particles_effect.dart';
import 'package:fluvie/src/animation/runtime/noise_scope.dart';
import 'package:fluvie/src/core/noise/value_noise.dart';
import 'package:fluvie/src/core/particles/particles.dart';
import 'package:fluvie/src/rendering/runtime/frame_provider.dart';
import 'package:fluvie/src/timing/time_scope_data.dart';
import 'package:fluvie/src/timing/time_scope_provider.dart';

const _probeKey = Key('probe');
const _size = Size(80, 80);
const _gray = Color(0xFF808080);
const _child = SizedBox(width: 80, height: 80, child: ColoredBox(color: _gray));

Widget _host(Widget built, {required int frame, NoiseScope? scope}) {
  Widget subject = Center(
    child: RepaintBoundary(
      key: _probeKey,
      child: SizedBox(width: _size.width, height: _size.height, child: built),
    ),
  );
  if (scope != null) {
    subject = NoiseScope(source: scope.source, child: subject);
  }
  return Directionality(
    textDirection: TextDirection.ltr,
    child: FrameProvider(
      frame: frame,
      child: TimeScopeProvider(
        scope: const TimeScopeData(fps: 30, startFrame: 0, durationFrames: 1000),
        child: subject,
      ),
    ),
  );
}

Future<ByteData> _bytes(WidgetTester tester) async {
  final boundary = tester.renderObject(find.byKey(_probeKey)) as RenderRepaintBoundary;
  late final ByteData data;
  await tester.runAsync(() async {
    final image = await boundary.toImage();
    data = (await image.toByteData())!;
    image.dispose();
  });
  return data;
}

void main() {
  group('the noise-flip pin: default == explicit ValueNoise (WI-15, D2)', () {
    testWidgets('grain pixels are byte-identical before and after the flip', (tester) async {
      // No scope is the pre-flip world; a ValueNoise scope is the post-flip
      // resolved source. The flip must change nothing, so they are identical.
      await tester.pumpWidget(_host(const GrainEffect(0.5).build(_child, 0.5), frame: 30));
      final preFlip = await _bytes(tester);
      await tester.pumpWidget(
        _host(
          const GrainEffect(0.5).build(_child, 0.5),
          frame: 30,
          scope: const NoiseScope(source: ValueNoise(), child: SizedBox()),
        ),
      );
      expect(preFlip.buffer.asUint8List(), (await _bytes(tester)).buffer.asUint8List());
    });

    testWidgets('particle pixels are byte-identical before and after the flip', (tester) async {
      const spec = Particles.confetti(seed: 'win');
      await tester.pumpWidget(_host(const ParticlesEffect(spec).build(_child, 0.5), frame: 30));
      final preFlip = await _bytes(tester);
      await tester.pumpWidget(
        _host(
          const ParticlesEffect(spec).build(_child, 0.5),
          frame: 30,
          scope: const NoiseScope(source: ValueNoise(), child: SizedBox()),
        ),
      );
      expect(preFlip.buffer.asUint8List(), (await _bytes(tester)).buffer.asUint8List());
    });
  });

  group('Animation.float(seed:) reproducible across runs (WI-15, §14.4)', () {
    test('the same seed produces the identical offset sequence on two runs', () {
      const cycle = 75;
      const amp = 0.04;
      List<double> sequence() => [
        for (var frame = 0; frame < cycle; frame++)
          FloatEffect.offsetAt(
            frame: frame,
            cycleFrames: cycle,
            amplitude: amp,
            seed: 'leaf-7',
            noise: const ValueNoise(),
          ),
      ];
      expect(sequence(), sequence());
    });

    testWidgets('two pumps of Animation.float(seed:) mount the identical offset', (tester) async {
      // The seeded float routes to a FloatEffect; mounting it twice at the same
      // frame must translate the child identically (the §22 contract).
      final effect = Animation.float(seed: 'leaf-7').effect;
      await tester.pumpWidget(_host(effect.build(_child, 0), frame: 31));
      final first = tester
          .widget<FractionalTranslation>(find.byType(FractionalTranslation))
          .translation;
      await tester.pumpWidget(_host(effect.build(_child, 0), frame: 31));
      final second = tester
          .widget<FractionalTranslation>(find.byType(FractionalTranslation))
          .translation;
      expect(first, second);
    });

    test('a different seed produces a different sequence', () {
      const cycle = 75;
      const amp = 0.04;
      List<double> sequenceFor(String seed) => [
        for (var frame = 0; frame < cycle; frame++)
          FloatEffect.offsetAt(
            frame: frame,
            cycleFrames: cycle,
            amplitude: amp,
            seed: seed,
            noise: const ValueNoise(),
          ),
      ];
      expect(sequenceFor('leaf-7'), isNot(sequenceFor('rock-2')));
    });
  });
}
