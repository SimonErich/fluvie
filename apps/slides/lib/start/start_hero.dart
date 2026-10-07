import 'package:flutter/widgets.dart';
import 'package:obers_ui/obers_ui.dart';

/// The brand band at the top of the start screen.
///
/// Everything it draws is painted from theme and deck colours, so it ships
/// no assets and never schedules a frame.
final class StartHero extends StatelessWidget {
  /// Creates a band [height] logical pixels tall.
  const StartHero({required this.height, super.key});

  /// How tall the band stands; the wide layout gives it more room.
  final double height;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final wide = context.isExpandedOrWider;
    return SizedBox(
      height: height,
      child: Stack(
        fit: StackFit.expand,
        children: [
          CustomPaint(painter: _StudioHeroPainter(line: colors.borderSubtle)),
          Padding(
            padding: EdgeInsets.fromLTRB(wide ? 40 : 20, 0, wide ? 40 : 20, wide ? 28 : 20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                OiLabel.overline('PRESENTATION STUDIO', color: colors.textMuted),
                const SizedBox(height: 6),
                const OiLabel.h1('fluvie slides'),
                const SizedBox(height: 8),
                OiLabel.body(
                  'Build a deck, present it, render it to video.',
                  color: colors.textSubtle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The hero's paint: a deep gradient, two soft glows, a stack of slide
/// frames on the right, and a hairline that seats the band on the page.
///
/// The colours come from the bundled decks' own palette, so the hero and the
/// samples read as one product.
final class _StudioHeroPainter extends CustomPainter {
  const _StudioHeroPainter({required this.line});

  /// The hairline that separates the band from the page below it.
  final Color line;

  static const _base = Color(0xFF14141C);
  static const _tint = Color(0xFF1B2838);
  static const _accent = Color(0xFF6C5CE7);
  static const _glow = Color(0xFF55EFC4);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_base, _tint],
        ).createShader(rect),
    );
    _glowAt(canvas, rect, Offset(w * 0.18, h * 1.05), h * 1.1, _accent, 0.35);
    _glowAt(canvas, rect, Offset(w * 0.86, -h * 0.15), h * 0.95, _glow, 0.14);
    if (w >= 560) _frames(canvas, w, h);
    canvas.drawRect(Rect.fromLTWH(0, h - 1, w, 1), Paint()..color = line);
  }

  void _glowAt(Canvas canvas, Rect rect, Offset centre, double radius, Color color, double alpha) {
    canvas.drawRect(
      rect,
      Paint()
        ..shader = RadialGradient(
          colors: [
            color.withValues(alpha: alpha),
            color.withValues(alpha: 0),
          ],
        ).createShader(Rect.fromCircle(center: centre, radius: radius)),
    );
  }

  void _frames(Canvas canvas, double w, double h) {
    final frameH = (h * 0.42).clamp(48.0, 76.0);
    final frameW = frameH * 16 / 9;
    const gap = 16.0;
    const inset = 48.0;
    final top = (h - frameH) / 2;
    const fills = [0.04, 0.06, 0.10];
    const strokes = [0.10, 0.15, 0.24];
    const white = Color(0xFFFFFFFF);
    var left = w - inset - frameW - 2 * (frameW + gap);
    for (var i = 0; i < 3; i++) {
      final frame = RRect.fromRectAndRadius(
        Rect.fromLTWH(left, top, frameW, frameH),
        const Radius.circular(6),
      );
      canvas
        ..drawRRect(frame, Paint()..color = white.withValues(alpha: fills[i]))
        ..drawRRect(
          frame,
          Paint()
            ..color = white.withValues(alpha: strokes[i])
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1,
        );
      if (i == 2) {
        canvas
          ..drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromLTWH(left + frameW * 0.12, top + frameH * 0.34, frameW * 0.5, 4),
              const Radius.circular(2),
            ),
            Paint()..color = white.withValues(alpha: 0.42),
          )
          ..drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromLTWH(left + frameW * 0.12, top + frameH * 0.52, frameW * 0.28, 3),
              const Radius.circular(2),
            ),
            Paint()..color = _accent,
          )
          ..drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromLTWH(left + frameW * 0.12, top + frameH * 0.70, frameW * 0.46, 2),
              const Radius.circular(1),
            ),
            Paint()..color = white.withValues(alpha: 0.16),
          );
      }
      left += frameW + gap;
    }
  }

  @override
  bool shouldRepaint(_StudioHeroPainter old) => old.line != line;
}
