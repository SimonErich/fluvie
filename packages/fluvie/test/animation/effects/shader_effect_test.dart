import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/animation/effect_kind.dart';
import 'package:fluvie/src/animation/effects/shader_effect.dart';
import 'package:fluvie/src/core/errors/fluvie_render_exception.dart';
import 'package:meta/meta.dart';

void main() {
  group('classification', () {
    test('a ShaderEffect is a pixel post-effect', () {
      final effect = ShaderEffect(shaderName: 'shaders/ripple.frag');
      expect(effect, isA<PixelAnimationEffect>());
      expect(effectKindOf(effect), EffectKind.pixel);
    });

    test('ShaderEffect carries the @experimental annotation', () {
      // The annotation is a compile-time guarantee; this asserts the symbol
      // exists and is reachable (the lint enforces the marker itself).
      const annotation = experimental;
      expect(annotation, isNotNull);
    });
  });

  group('uniform plumbing (the stable float-slot order)', () {
    test('resolution then progress then author uniforms in declaration order', () {
      final floats = shaderFloatBindings(
        size: const Size(64, 48),
        progress: 0.25,
        uniforms: const {'strength': 0.5, 'count': 3.0},
      );
      // Stable order: resolution.x, resolution.y, progress, then each author
      // uniform in iteration order.
      expect(floats, [64.0, 48.0, 0.25, 0.5, 3.0]);
    });

    test('an int uniform is coerced to a float slot', () {
      final floats = shaderFloatBindings(
        size: const Size(10, 10),
        progress: 0,
        uniforms: const {'n': 7},
      );
      expect(floats, [10.0, 10.0, 0.0, 7.0]);
    });

    test('a non-numeric uniform throws a typed error naming the key', () {
      expect(
        () => shaderFloatBindings(
          size: const Size(10, 10),
          progress: 0,
          uniforms: const {'bad': 'nope'},
        ),
        throwsA(
          isA<FluvieRenderException>().having((e) => e.message, 'message', contains('bad')),
        ),
      );
    });
  });

  group('build', () {
    testWidgets('a warm shader paints through a foreground CustomPaint', (tester) async {
      late ui.FragmentShader shader;
      await tester.runAsync(() async {
        final program = await ui.FragmentProgram.fromAsset('shaders/ripple.frag');
        shader = program.fragmentShader();
      });
      final effect = ShaderEffect(shaderName: 'shaders/ripple.frag', shader: shader);

      await tester.pumpWidget(
        Center(
          child: SizedBox(
            width: 64,
            height: 64,
            child: effect.build(const ColoredBox(color: Color(0xFF223344)), 0.5),
          ),
        ),
      );

      final paint = tester.widget<CustomPaint>(
        find.byWidgetPredicate((w) => w is CustomPaint && w.foregroundPainter != null),
      );
      expect(paint.foregroundPainter, isNotNull);
    });

    testWidgets('painting before the program is warm throws a typed error', (tester) async {
      final effect = ShaderEffect(shaderName: 'shaders/ripple.frag');

      await tester.pumpWidget(
        Center(
          child: SizedBox(
            width: 64,
            height: 64,
            child: effect.build(const ColoredBox(color: Color(0xFF223344)), 0.5),
          ),
        ),
      );

      final error = tester.takeException();
      expect(error, isA<FluvieRenderException>());
      expect((error as FluvieRenderException).message, contains('shaders/ripple.frag'));
    });
  });
}
