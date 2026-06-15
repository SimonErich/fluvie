import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show mapEquals;
import 'package:flutter/widgets.dart';
import 'package:fluvie/src/animation/effect_kind.dart';
import 'package:fluvie/src/core/errors/fluvie_render_exception.dart';
import 'package:meta/meta.dart';

/// The effect behind `Animation.shader` — an
/// **experimental** fragment-shader post-effect.
///
/// A pixel post-effect: it wraps the child in a `CustomPaint(foregroundPainter:)`
/// that paints the loaded `FragmentShader` over the rendered child, so the
/// shader composites on top with no backdrop read and no `saveLayer` (the same
/// capture-safe discipline as `GrainEffect`).
///
/// The float slots are bound in a fixed order so the GLSL contract is stable:
/// `resolution.x`, `resolution.y`, `progress`, then each author [uniforms]
/// value in iteration order. The bundled `shaders/ripple.frag` reads exactly
/// those first three slots; an author shader appends its own uniforms after.
///
/// Shaders are **loaded before frame 0** (like media pre-resolution): the warm
/// shader is handed in so `build` paints synchronously during capture (no
/// async-in-frame). Painting before the program is warm — a missing shader —
/// throws a [FluvieRenderException] naming the asset rather than silently
/// drawing nothing. GPU caveat: software rasterizers vary; goldens are pinned
/// to the Linux baseline.
@experimental
final class ShaderEffect implements PixelAnimationEffect {
  /// Creates a shader effect for [shaderName], optionally with the already
  /// warmed [shader] and author [uniforms] bound after the built-in slots.
  ShaderEffect({
    required this.shaderName,
    ui.FragmentShader? shader,
    this.uniforms = const {},
  }) : _shader = shader; // ignore: prefer_initializing_formals — public arg `shader`, private field

  /// The asset path the shader was loaded from (named in errors).
  final String shaderName;

  /// Author-supplied scalar uniforms, bound after `resolution` and `progress`
  /// in iteration order. Values must be `num` (coerced to `double`).
  final Map<String, Object> uniforms;

  final ui.FragmentShader? _shader;

  @override
  Widget build(Widget child, double progress) => CustomPaint(
    foregroundPainter: _ShaderPainter(
      shaderName: shaderName,
      shader: _shader,
      progress: progress,
      uniforms: uniforms,
    ),
    child: child,
  );

  @override
  String toString() => 'ShaderEffect(shader: $shaderName)';
}

/// Resolves the ordered float bindings for a shader paint.
///
/// Returns `[size.width, size.height, progress, ...uniforms]` — the stable slot
/// order the painter feeds into `FragmentShader.setFloat`. Each [uniforms]
/// value must be a [num]; a non-numeric value throws a [FluvieRenderException]
/// naming the offending key (fragment-shader uniforms are float slots, so only
/// scalars are bindable here).
List<double> shaderFloatBindings({
  required Size size,
  required double progress,
  required Map<String, Object> uniforms,
}) {
  final floats = <double>[size.width, size.height, progress];
  for (final entry in uniforms.entries) {
    final value = entry.value;
    if (value is! num) {
      throw FluvieRenderException(
        'Shader uniform "${entry.key}" must be a num (a float slot); got '
        '${value.runtimeType}.',
      );
    }
    floats.add(value.toDouble());
  }
  return floats;
}

/// Paints the warm [shader] over the child, binding the ordered float slots.
final class _ShaderPainter extends CustomPainter {
  const _ShaderPainter({
    required this.shaderName,
    required this.shader,
    required this.progress,
    required this.uniforms,
  });

  final String shaderName;
  final ui.FragmentShader? shader;
  final double progress;
  final Map<String, Object> uniforms;

  @override
  void paint(Canvas canvas, Size size) {
    final warm = shader;
    if (warm == null) {
      throw FluvieRenderException(
        'Fragment shader "$shaderName" was not warmed before paint. Pre-load '
        'shaders before frame 0 (like media) so capture paints synchronously.',
      );
    }
    final floats = shaderFloatBindings(size: size, progress: progress, uniforms: uniforms);
    for (var slot = 0; slot < floats.length; slot++) {
      warm.setFloat(slot, floats[slot]);
    }
    canvas.drawRect(Offset.zero & size, Paint()..shader = warm);
  }

  @override
  bool shouldRepaint(_ShaderPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.shader != shader ||
      !mapEquals(oldDelegate.uniforms, uniforms);
}
