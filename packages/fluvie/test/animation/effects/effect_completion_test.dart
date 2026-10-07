import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/fluvie.dart';
import 'package:fluvie/rendering.dart';
import 'package:fluvie/src/animation/effects/blur_effect.dart';
import 'package:fluvie/src/animation/effects/color_grade_effect.dart';
import 'package:fluvie/src/animation/effects/glitch_effect.dart';

const cube = 'LUT_3D_SIZE 2\n0 0 0\n1 0 0\n0 1 0\n1 1 0\n0 0 1\n1 0 1\n0 1 1\n1 1 1\n';

void main() {
  test('blur and glitch intensity are bounded and zero returns the exact child', () {
    const child = SizedBox();
    expect(identical(const BlurEffect(0).build(child, 0), child), isTrue);
    expect(identical(const GlitchEffect(intensity: 0).build(child, 0), child), isTrue);
    final blur =
        buildEffect(EffectSpec.fromJson(const {'kind': 'blur', 'sigma': 12})) as BlurEffect;
    expect(blur.sigma, 12);
    final glitch =
        buildEffect(EffectSpec.fromJson(const {'kind': 'glitch', 'intensity': 0.4}))
            as GlitchEffect;
    expect(glitch.intensity, 0.4);
    for (final effect in [
      {'kind': 'blur', 'sigma': 65},
      {'kind': 'glitch', 'intensity': -0.1},
    ]) {
      expect(() => EffectSpec.fromJson(effect), throwsA(isA<FluvieSpecError>()));
    }
  });
  test('grade intensity zero is exact and partial intensity mixes output matrix', () {
    const child = SizedBox();
    expect(
      identical(const ColorGradeEffect(exposure: 2, intensity: 0).build(child, 0), child),
      isTrue,
    );
    final full = ColorGradeEffect.matrixFor(exposure: 1);
    expect(ColorGradeEffect.mixMatrix(full, 0.6)[0], closeTo(1.6, 1e-12));
    expect(ColorGradeEffect.mixMatrix(full, 0)[0], 1);
  });
  testWidgets('embedded LUT warms without any asset loader and round-trips verbatim', (
    tester,
  ) async {
    final spec = EffectSpec.fromJson(const {'kind': 'lut', 'cube': cube, 'intensity': 0.6});
    expect(EffectSpec.fromJson(spec.toJson()).text('cube'), cube);
    final video = Video(
      width: 16,
      height: 16,
      scenes: [
        Scene(
          duration: const Time.frames(5),
          children: [
            const SizedBox(width: 16, height: 16).effects([Effect.spec(spec)]),
          ],
        ),
      ],
    );
    await tester.runAsync(() async {
      final shaders = await preLoadCompositionShaders(composition: video);
      expect(shaders, contains('shaders/color_lut.frag'));
      final lookups = await preBakeCompositionColorLookups(
        composition: video,
        loadCubeText: (_) async => throw StateError('Embedded LUT must not do IO'),
      );
      expect(lookups, hasLength(1));
      expect(lookups.values.single.width, 4);
      for (final image in lookups.values) {
        image.dispose();
      }
    });
  });
  test('malformed structured effect objects are rejected before rendering', () {
    for (final effect in <Map<String, Object?>>[
      {
        'kind': 'curves',
        'curves': {
          'unknown': [
            [0, 0],
            [1, 1],
          ],
        },
      },
      {
        'kind': 'curves',
        'curves': {
          'red': [
            [0, 0],
            [0, 1],
          ],
        },
      },
      {
        'kind': 'curves',
        'curves': {
          'master': [
            [0, 0],
            [1, 2],
          ],
        },
      },
      {'kind': 'lut', 'cube': 'LUT_3D_SIZE 2\n0 0 0'},
      {
        'kind': 'shader',
        'uniforms': {
          'strength': [1, 2],
        },
      },
    ]) {
      expect(() => EffectSpec.fromJson(effect), throwsA(isA<FluvieSpecError>()));
    }
  });
}
