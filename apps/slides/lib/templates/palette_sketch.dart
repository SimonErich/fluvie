import 'package:flutter/widgets.dart';
import 'package:obers_ui/obers_ui.dart';

/// An honest, asset-free thumbnail of the theme a deck ships.
///
/// [PaletteSketch.swatches] is the dense form the gallery list leads with;
/// [PaletteSketch.slide] paints a mini slide, so the template strip shows at
/// a glance which deck is dark, which is paper, and which is neon. Both read
/// the deck's own `theme.palette`, so nothing here ships an image.
final class PaletteSketch extends StatelessWidget {
  /// Three colour bars from [deck]'s palette: background, accent, text.
  const PaletteSketch.swatches({required this.deck, super.key})
    : width = 0,
      height = 0,
      _slide = false;

  /// A [width] x [height] mini slide painted in [deck]'s palette.
  const PaletteSketch.slide({
    required this.deck,
    required this.width,
    required this.height,
    super.key,
  }) : _slide = true;

  /// The complete `.fluvie` document whose palette is being sketched.
  final Map<String, Object?> deck;

  /// The mini slide's width; unused by the swatch form.
  final double width;

  /// The mini slide's height; unused by the swatch form.
  final double height;

  final bool _slide;

  @override
  Widget build(BuildContext context) {
    final palette = paletteOf(deck);
    if (!_slide) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final token in const ['background', 'accent', 'text'])
            if (parsePaletteHex(palette[token]) case final Color color)
              Padding(
                padding: const EdgeInsets.only(right: 2),
                child: Container(
                  width: 10,
                  height: 22,
                  decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2)),
                ),
              ),
        ],
      );
    }
    final colors = context.colors;
    Color token(String name, Color fallback) => parsePaletteHex(palette[name]) ?? fallback;
    return ClipRRect(
      borderRadius: context.radius.sm,
      child: SizedBox(
        width: width,
        height: height,
        child: CustomPaint(
          painter: _SlideSketchPainter(
            background: token('background', colors.surface),
            surface: token('surface', colors.surfaceSubtle),
            accent: token('accent', colors.accent.base),
            text: token('text', colors.text),
            muted: token('muted', colors.textMuted),
            border: colors.borderSubtle,
          ),
        ),
      ),
    );
  }
}

/// The `theme.palette` map inside a `.fluvie` [deck], or an empty map.
Map<String, Object?> paletteOf(Map<String, Object?> deck) {
  final theme = deck['theme'];
  final palette = theme is Map<String, Object?> ? theme['palette'] : null;
  return palette is Map<String, Object?> ? palette : const {};
}

/// Parses a `#RRGGBB` palette value, or null for anything else.
Color? parsePaletteHex(Object? raw) {
  if (raw is! String || !raw.startsWith('#') || raw.length != 7) return null;
  final value = int.tryParse(raw.substring(1), radix: 16);
  return value == null ? null : Color(0xFF000000 | value);
}

/// Paints the mini slide: a tinted body, a title bar, an accent rule, and
/// two body lines. Nothing here reads a clock, so it is golden-stable.
final class _SlideSketchPainter extends CustomPainter {
  const _SlideSketchPainter({
    required this.background,
    required this.surface,
    required this.accent,
    required this.text,
    required this.muted,
    required this.border,
  });

  final Color background;
  final Color surface;
  final Color accent;
  final Color text;
  final Color muted;
  final Color border;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    canvas
      ..drawRect(Offset.zero & size, Paint()..color = background)
      ..drawRRect(
        RRect.fromLTRBR(6, 6, w - 6, h - 6, const Radius.circular(3)),
        Paint()..color = surface.withValues(alpha: 0.6),
      );
    void bar(double left, double top, double barWidth, double barHeight, double radius, Color c) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(left, top, barWidth, barHeight),
          Radius.circular(radius),
        ),
        Paint()..color = c,
      );
    }

    final titleTop = h * 0.30;
    bar(14, titleTop, w * 0.46, 5, 2, text.withValues(alpha: 0.85));
    bar(14, titleTop + 11, w * 0.20, 3, 2, accent);
    final bodyTop = h * 0.62;
    bar(14, bodyTop, w * 0.58, 2.5, 1, muted.withValues(alpha: 0.7));
    bar(14, bodyTop + 8, w * 0.40, 2.5, 1, muted.withValues(alpha: 0.7));
    canvas.drawRect(
      Rect.fromLTWH(0.5, 0.5, w - 1, h - 1),
      Paint()
        ..color = border
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
  }

  @override
  bool shouldRepaint(_SlideSketchPainter old) =>
      old.background != background ||
      old.surface != surface ||
      old.accent != accent ||
      old.text != text ||
      old.muted != muted ||
      old.border != border;
}
