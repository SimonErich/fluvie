import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:fluvie/src/animation/runtime/color_lookup_scope.dart';
import 'package:fluvie/src/animation/runtime/warm_shader_scope.dart';
import 'package:fluvie/src/core/errors/fluvie_render_exception.dart';
import 'package:fluvie/src/rendering/runtime/frame_provider.dart';
import 'package:fluvie/src/rendering/runtime/preparation_scope.dart';
import 'package:fluvie/src/rendering/runtime/render_mode.dart';
import 'package:fluvie/src/rendering/runtime/render_mode_context.dart';

/// Rasterizes its child and repaints it through a fragment shader that
/// samples it — the pixel path curves and LUTs ride, where a paint-over
/// composite cannot work because the effect must read the frame it changes.
///
/// The child raster comes from a [SnapshotWidget], which captures
/// synchronously during paint (no async-in-frame); the program comes warm
/// from the enclosing [WarmShaderScope] and the lookup image from the
/// [ColorLookupScope], both resolved before frame 0. Painting before either
/// is warm throws a [FluvieRenderException] naming what is missing rather
/// than silently drawing nothing.
final class SampledShaderView extends StatefulWidget {
  /// Repaints [child] through [shaderAsset], binding the image under
  /// [lookupKey] as the second sampler and [floats] after the resolution.
  const SampledShaderView({
    required this.shaderAsset,
    required this.lookupKey,
    required this.floats,
    required this.child,
    super.key,
  });

  /// The bundled shader's asset key (resolved through the warm scope).
  final String shaderAsset;

  /// The baked lookup image's content key in the [ColorLookupScope].
  final String lookupKey;

  /// The float slots bound after `resolution.x`, `resolution.y`, in order,
  /// built from the resolved lookup (whose dimensions may carry meaning,
  /// like a cube size).
  final List<double> Function(ui.Image lookup) floats;

  /// The element being repainted.
  final Widget child;

  @override
  State<SampledShaderView> createState() => _SampledShaderViewState();
}

final class _SampledShaderViewState extends State<SampledShaderView> {
  final SnapshotController _controller = SnapshotController(allowSnapshotting: true);
  ui.FragmentShader? _shader;
  ui.FragmentProgram? _program;
  _SampledPainter? _painter;
  int? _rasteredFrame;

  @override
  void dispose() {
    _painter?.dispose();
    _shader?.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    PreparationScope.requirePrepared(context, widget.shaderAsset, 'shader');
    final program = WarmShaderScope.maybeOf(context)?.programFor(widget.shaderAsset);
    final lookup = ColorLookupScope.maybeOf(context)?.lookupFor(widget.lookupKey);
    if (program == null || lookup == null) {
      // In capture the pre-pass guaranteed both, so a hole is a bug and it
      // throws by name. A live surface warms asynchronously: the child
      // shows ungraded for the frames before the scopes land, the same
      // grace a cold media placeholder gets.
      if (RenderModeContext.modeOf(context) != RenderMode.capture) return widget.child;
      throw FluvieRenderException(
        program == null
            ? 'Shader "${widget.shaderAsset}" was not warmed before paint. '
                  'Colour effects need the render pre-pass (or a PreviewMediaScope).'
            : 'Colour lookup "${widget.lookupKey}" was not baked before paint. '
                  'Colour effects need the render pre-pass (or a PreviewMediaScope).',
      );
    }
    if (!identical(program, _program)) {
      _shader?.dispose();
      _program = program;
      _shader = program.fragmentShader();
    }
    // The snapshot caches the child raster; anything animating inside it —
    // a clip's frames, a nested keyframed effect — changes with the frame,
    // so the raster is only valid for the frame it was captured at.
    final frame = FrameProvider.maybeOf(context)?.frame;
    if (frame != _rasteredFrame) {
      _rasteredFrame = frame;
      _controller.clear();
    }
    _painter?.dispose();
    _painter = _SampledPainter(shader: _shader!, lookup: lookup, floats: widget.floats(lookup));
    return SnapshotWidget(
      controller: _controller,
      mode: SnapshotMode.forced,
      painter: _painter!,
      child: widget.child,
    );
  }
}

/// Draws the captured child through the shader: child as sampler 0, the
/// lookup as sampler 1, resolution then the caller floats in the slots.
final class _SampledPainter extends SnapshotPainter {
  _SampledPainter({required this.shader, required this.lookup, required this.floats});

  final ui.FragmentShader shader;
  final ui.Image lookup;
  final List<double> floats;

  @override
  void paint(
    PaintingContext context,
    ui.Offset offset,
    ui.Size size,
    PaintingContextCallback painter,
  ) {
    // Snapshotting disabled (never in capture: the mode is forced); paint
    // the child untouched rather than half-graded.
    painter(context, offset);
  }

  @override
  void paintSnapshot(
    PaintingContext context,
    ui.Offset offset,
    ui.Size size,
    ui.Image image,
    ui.Size sourceSize,
    double pixelRatio,
  ) {
    shader
      ..setFloat(0, sourceSize.width)
      ..setFloat(1, sourceSize.height);
    for (var i = 0; i < floats.length; i++) {
      shader.setFloat(2 + i, floats[i]);
    }
    shader
      ..setImageSampler(0, image)
      ..setImageSampler(1, lookup);
    context.canvas
      ..save()
      ..translate(offset.dx, offset.dy)
      ..scale(size.width / sourceSize.width, size.height / sourceSize.height)
      ..drawRect(
        ui.Rect.fromLTWH(0, 0, sourceSize.width, sourceSize.height),
        ui.Paint()..shader = shader,
      )
      ..restore();
  }

  @override
  bool shouldRepaint(_SampledPainter oldPainter) =>
      !identical(oldPainter.shader, shader) ||
      !identical(oldPainter.lookup, lookup) ||
      !_sameFloats(oldPainter.floats, floats);

  static bool _sameFloats(List<double> a, List<double> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
