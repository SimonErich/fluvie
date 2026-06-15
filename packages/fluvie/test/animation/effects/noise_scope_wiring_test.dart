// WI-14: every seeded effect reads a mounted NoiseScope, and with the default
// source (no scope) paints output identical to the pre-flip const ValueNoise().
import 'dart:typed_data' show ByteData;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/animation/effects/float_effect.dart';
import 'package:fluvie/src/animation/effects/glitch_effect.dart';
import 'package:fluvie/src/animation/effects/grain_effect.dart';
import 'package:fluvie/src/animation/effects/particles_effect.dart';
import 'package:fluvie/src/animation/runtime/noise_scope.dart';
import 'package:fluvie/src/core/noise/noise_source.dart';
import 'package:fluvie/src/core/noise/value_noise.dart';
import 'package:fluvie/src/core/particles/particles.dart';
import 'package:fluvie/src/rendering/runtime/frame_provider.dart';
import 'package:fluvie/src/timing/time_scope_data.dart';
import 'package:fluvie/src/timing/time_scope_provider.dart';

const _probeKey = Key('probe');
const _size = Size(80, 80);
const _gray = Color(0xFF808080);
const _child = SizedBox(width: 80, height: 80, child: ColoredBox(color: _gray));

/// A loud noise source: every lookup returns a fixed extreme, so an effect that
/// reads it paints visibly differently from the default ValueNoise.
class _LoudNoise implements NoiseSource {
  const _LoudNoise();

  @override
  double valueForSeed(String seed) => 0.95;

  @override
  double noise1(double x) => 0.95;

  @override
  double noise2(double x, double y) => 0.95;
}

/// Mounts [built] in an 80x80 repaint boundary under a frame clock, optionally
/// under a [NoiseScope] carrying [source].
Widget _host(Widget built, {NoiseSource? source}) {
  Widget tree = Center(
    child: RepaintBoundary(
      key: _probeKey,
      child: SizedBox(width: _size.width, height: _size.height, child: built),
    ),
  );
  if (source != null) {
    tree = NoiseScope(source: source, child: tree);
  }
  return Directionality(
    textDirection: TextDirection.ltr,
    child: FrameProvider(
      frame: 19,
      child: TimeScopeProvider(
        scope: const TimeScopeData(fps: 30, startFrame: 0, durationFrames: 1000),
        child: tree,
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

Future<ByteData> _pumpBytes(WidgetTester tester, Widget built, {NoiseSource? source}) async {
  await tester.pumpWidget(_host(built, source: source));
  return _bytes(tester);
}

void main() {
  group('GrainEffect — NoiseScope wiring', () {
    testWidgets('no scope renders identical to a ValueNoise scope', (tester) async {
      // The effect carries the const ValueNoise() default; with no scope above
      // it must paint exactly what a ValueNoise scope paints (byte-identical).
      final viaDefault = await _pumpBytes(tester, const GrainEffect(0.6).build(_child, 0.5));
      final viaScope = await _pumpBytes(
        tester,
        const GrainEffect(0.6).build(_child, 0.5),
        source: const ValueNoise(),
      );
      expect(viaDefault.buffer.asUint8List(), viaScope.buffer.asUint8List());
    });

    testWidgets('reads the mounted scope source (output differs from default)', (tester) async {
      final viaDefault = await _pumpBytes(tester, const GrainEffect(0.6).build(_child, 0.5));
      final viaScope = await _pumpBytes(
        tester,
        const GrainEffect(0.6).build(_child, 0.5),
        source: const _LoudNoise(),
      );
      expect(viaScope.buffer.asUint8List(), isNot(viaDefault.buffer.asUint8List()));
    });
  });

  group('ParticlesEffect — NoiseScope wiring', () {
    testWidgets('no scope renders identical to a ValueNoise scope', (tester) async {
      const spec = Particles.confetti(seed: 'win');
      final viaDefault = await _pumpBytes(tester, const ParticlesEffect(spec).build(_child, 0.5));
      final viaScope = await _pumpBytes(
        tester,
        const ParticlesEffect(spec).build(_child, 0.5),
        source: const ValueNoise(),
      );
      expect(viaDefault.buffer.asUint8List(), viaScope.buffer.asUint8List());
    });

    testWidgets('reads the mounted scope source (output differs from default)', (tester) async {
      const spec = Particles.confetti(seed: 'win');
      final viaDefault = await _pumpBytes(tester, const ParticlesEffect(spec).build(_child, 0.5));
      final viaScope = await _pumpBytes(
        tester,
        const ParticlesEffect(spec).build(_child, 0.5),
        source: const _LoudNoise(),
      );
      expect(viaScope.buffer.asUint8List(), isNot(viaDefault.buffer.asUint8List()));
    });
  });

  group('GlitchEffect — NoiseScope wiring', () {
    testWidgets('no scope renders identical to a ValueNoise scope', (tester) async {
      final viaDefault = await _pumpBytes(tester, const GlitchEffect().build(_child, 0.3));
      final viaScope = await _pumpBytes(
        tester,
        const GlitchEffect().build(_child, 0.3),
        source: const ValueNoise(),
      );
      expect(viaDefault.buffer.asUint8List(), viaScope.buffer.asUint8List());
    });

    testWidgets('reads the mounted scope source (output differs from default)', (tester) async {
      final viaDefault = await _pumpBytes(tester, const GlitchEffect().build(_child, 0.3));
      final viaScope = await _pumpBytes(
        tester,
        const GlitchEffect().build(_child, 0.3),
        source: const _LoudNoise(),
      );
      expect(viaScope.buffer.asUint8List(), isNot(viaDefault.buffer.asUint8List()));
    });
  });

  group('FloatEffect — NoiseScope wiring', () {
    testWidgets('no scope translates identical to a ValueNoise scope', (tester) async {
      await tester.pumpWidget(_host(const FloatEffect(seed: 'leaf-7').build(_child, 0)));
      final viaDefault = tester
          .widget<FractionalTranslation>(find.byType(FractionalTranslation))
          .translation;
      await tester.pumpWidget(
        _host(const FloatEffect(seed: 'leaf-7').build(_child, 0), source: const ValueNoise()),
      );
      final viaScope = tester
          .widget<FractionalTranslation>(find.byType(FractionalTranslation))
          .translation;
      expect(viaDefault, viaScope);
    });

    testWidgets('reads the mounted scope source (offset differs from default)', (tester) async {
      await tester.pumpWidget(_host(const FloatEffect(seed: 'leaf-7').build(_child, 0)));
      final viaDefault = tester
          .widget<FractionalTranslation>(find.byType(FractionalTranslation))
          .translation;
      await tester.pumpWidget(
        _host(const FloatEffect(seed: 'leaf-7').build(_child, 0), source: const _LoudNoise()),
      );
      final viaScope = tester
          .widget<FractionalTranslation>(find.byType(FractionalTranslation))
          .translation;
      expect(viaScope, isNot(viaDefault));
    });
  });
}
