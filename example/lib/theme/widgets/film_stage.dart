import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:fluvie_example/theme/fluvie_colors.dart';
import 'package:fluvie_example/theme/fluvie_gradients.dart';
import 'package:fluvie_example/theme/fluvie_text_theme.dart';
import 'package:fluvie_example/theme/widgets/brand_pill.dart';

/// The dark "film stage" matching the landing page's film card: a radial blue
/// stage with a dotted grid, a soft static glow, and a vignette, under a slim
/// chrome header. Hosts the rendered video (or a placeholder) in [child].
final class FilmStage extends StatelessWidget {
  /// Creates a film stage titled [filename] around [child].
  const FilmStage({required this.child, this.filename = 'preview.mp4', super.key});

  /// The video, or a placeholder, shown on the stage.
  final Widget child;

  /// The filename shown in the chrome header.
  final String filename;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _StageHeader(filename: filename),
        Expanded(
          child: DecoratedBox(
            decoration: const BoxDecoration(gradient: FluvieGradients.filmStage),
            child: Stack(
              fit: StackFit.expand,
              children: [
                const _DottedGrid(),
                const _Glow(),
                Padding(padding: const EdgeInsets.all(28), child: child),
                const IgnorePointer(child: _Vignette()),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _StageHeader extends StatelessWidget {
  const _StageHeader({required this.filename});

  final String filename;

  @override
  Widget build(BuildContext context) {
    final mono = fluvieMono(fontSize: 11, color: FluvieColors.dmut);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 11),
      color: FluvieColors.dpanel,
      child: Row(
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: const BoxDecoration(color: FluvieColors.dotGreen, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(filename, overflow: TextOverflow.ellipsis, style: mono),
          ),
          const SizedBox(width: 8),
          const BrandPill(label: 'MP4'),
        ],
      ),
    );
  }
}

class _DottedGrid extends StatelessWidget {
  const _DottedGrid();

  @override
  Widget build(BuildContext context) =>
      const CustomPaint(painter: _DottedGridPainter(), size: Size.infinite);
}

class _DottedGridPainter extends CustomPainter {
  const _DottedGridPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0x12FFFFFF);
    const step = 26.0;
    for (var y = 0.0; y < size.height; y += step) {
      for (var x = 0.0; x < size.width; x += step) {
        canvas.drawCircle(Offset(x, y), 0.9, paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DottedGridPainter oldDelegate) => false;
}

class _Glow extends StatelessWidget {
  const _Glow();

  @override
  Widget build(BuildContext context) => Align(
    alignment: const Alignment(0, -0.7),
    child: ImageFiltered(
      imageFilter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
      child: Container(
        width: 360,
        height: 220,
        decoration: const BoxDecoration(gradient: FluvieGradients.glow),
      ),
    ),
  );
}

class _Vignette extends StatelessWidget {
  const _Vignette();

  @override
  Widget build(BuildContext context) => const DecoratedBox(
    decoration: BoxDecoration(
      gradient: RadialGradient(
        radius: 0.95,
        colors: [Color(0x00000000), Color(0x80000000)],
        stops: [0.6, 1],
      ),
    ),
  );
}
