import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../presentation/time_consumer.dart';
import '../../declarative/animations/core/animated_prop.dart';
import '../../declarative/animations/core/prop_animation.dart';
import '../_base/template_base.dart';
import '../_base/template_config.dart';
import '../_base/template_data.dart';

/// Old travel postcard with stamped location info.
///
/// Creates a vintage postcard aesthetic with worn paper texture,
/// postal stamps, and handwritten-style text. Perfect for location
/// or travel-related stats.
///
/// Best used for:
/// - Location-based stats
/// - Top cities
/// - Travel memories
///
/// Example:
/// ```dart
/// RetroPostcard(
///   data: ThematicData(
///     title: 'GREETINGS FROM',
///     subtitle: 'New York',
///     description: 'Your most played city',
///     metadata: {'stamp': '2024'},
///   ),
/// )
/// ```
class RetroPostcard extends WrappedTemplate with TemplateAnimationMixin {
  /// Whether to show stamp effect.
  final bool showStamp;

  /// Whether to show worn paper texture.
  final bool showTexture;

  /// Postcard border color.
  final Color? borderColor;

  /// Random seed.
  final int seed;

  const RetroPostcard({
    super.key,
    required ThematicData super.data,
    super.theme,
    super.timing,
    this.showStamp = true,
    this.showTexture = true,
    this.borderColor,
    this.seed = 42,
  });

  @override
  int get recommendedLength => 180;

  @override
  TemplateCategory get category => TemplateCategory.thematic;

  @override
  String get description => 'Old travel postcard with stamped location';

  @override
  TemplateTheme get defaultTheme => TemplateTheme.pastel;

  ThematicData get thematicData => data as ThematicData;

  @override
  Widget build(BuildContext context) {
    final colors = effectiveTheme;

    return Container(
      color: colors.backgroundColor,
      child: Center(child: _buildPostcard(colors)),
    );
  }

  Widget _buildPostcard(TemplateTheme colors) {
    return TimeConsumer(
      builder: (context, frame, _) {
        // Entry animation
        final entryProgress = ((frame - 20) / 40).clamp(0.0, 1.0);
        final entryScale = Curves.easeOutBack.transform(entryProgress);
        final entryRotation = (1 - entryProgress) * 0.1;

        return Transform.rotate(
          angle: entryRotation,
          child: Transform.scale(
            scale: entryScale,
            child: Opacity(
              opacity: entryProgress,
              child: Container(
                width: 700,
                height: 500,
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F0E1), // Vintage paper color
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: borderColor ?? const Color(0xFFD4C4A8),
                    width: 3,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Stack(
                  children: [
                    // Paper texture
                    if (showTexture)
                      Positioned.fill(
                        child: CustomPaint(
                          painter: _PaperTexturePainter(seed: seed),
                          size: Size.infinite,
                        ),
                      ),

                    // Postcard content
                    Positioned.fill(
                      child: Padding(
                        padding: const EdgeInsets.all(40),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Header
                            _buildHeader(colors, frame),
                            const Spacer(),

                            // Main location text
                            _buildLocationText(colors, frame),
                            const Spacer(),

                            // Description
                            _buildDescription(colors, frame),
                          ],
                        ),
                      ),
                    ),

                    // Stamp
                    if (showStamp)
                      Positioned(
                        top: 30,
                        right: 30,
                        child: _buildStamp(colors, frame),
                      ),

                    // Postmark
                    Positioned(
                      top: 60,
                      right: 80,
                      child: _buildPostmark(frame),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader(TemplateTheme colors, int frame) {
    return AnimatedProp(
      startFrame: 50,
      duration: 30,
      animation: PropAnimation.fadeIn(),
      child: Text(
        thematicData.title ?? 'GREETINGS FROM',
        style: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w500,
          color: const Color(0xFF8B7355),
          letterSpacing: 8,
        ),
      ),
    );
  }

  Widget _buildLocationText(TemplateTheme colors, int frame) {
    return AnimatedProp(
      startFrame: 70,
      duration: 40,
      animation: PropAnimation.combine([
        PropAnimation.scale(start: 0.9, end: 1.0),
        PropAnimation.fadeIn(),
      ]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            thematicData.subtitle ?? 'Your City',
            style: TextStyle(
              fontSize: 72,
              fontWeight: FontWeight.w900,
              color: const Color(0xFF4A3728),
              height: 1.0,
              fontFamily: 'serif',
            ),
          ),
          if (thematicData.value != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: colors.accentColor.withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '${thematicData.value}',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDescription(TemplateTheme colors, int frame) {
    if (thematicData.description == null) return const SizedBox.shrink();

    return AnimatedProp(
      startFrame: 110,
      duration: 30,
      animation: PropAnimation.slideUpFade(distance: 15),
      child: Text(
        thematicData.description!,
        style: TextStyle(
          fontSize: 18,
          fontStyle: FontStyle.italic,
          color: const Color(0xFF6B5344),
        ),
      ),
    );
  }

  Widget _buildStamp(TemplateTheme colors, int frame) {
    return AnimatedProp(
      startFrame: 90,
      duration: 25,
      animation: PropAnimation.combine([
        PropAnimation.scale(start: 0.5, end: 1.0),
        PropAnimation.fadeIn(),
      ]),
      child: Transform.rotate(
        angle: 0.15,
        child: Container(
          width: 100,
          height: 120,
          decoration: BoxDecoration(
            color: colors.primaryColor,
            border: Border.all(color: Colors.white, width: 3),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.music_note, size: 40, color: Colors.white),
              const SizedBox(height: 8),
              Text(
                thematicData.metadata?['stamp'] ?? '2024',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPostmark(int frame) {
    return AnimatedProp(
      startFrame: 100,
      duration: 20,
      animation: PropAnimation.fadeIn(),
      child: Transform.rotate(
        angle: -0.2,
        child: CustomPaint(
          painter: _PostmarkPainter(),
          size: const Size(80, 80),
        ),
      ),
    );
  }
}

class _PaperTexturePainter extends CustomPainter {
  final int seed;

  _PaperTexturePainter({required this.seed});

  @override
  void paint(Canvas canvas, Size size) {
    final random = math.Random(seed);
    final paint = Paint();

    // Subtle noise texture
    for (var i = 0; i < 500; i++) {
      final x = random.nextDouble() * size.width;
      final y = random.nextDouble() * size.height;
      final opacity = random.nextDouble() * 0.05;

      paint.color = Colors.brown.withValues(alpha: opacity);
      canvas.drawCircle(Offset(x, y), 1, paint);
    }

    // Age spots
    for (var i = 0; i < 10; i++) {
      final x = random.nextDouble() * size.width;
      final y = random.nextDouble() * size.height;
      final radius = 20 + random.nextDouble() * 40;

      canvas.drawCircle(
        Offset(x, y),
        radius,
        Paint()
          ..color = const Color(0xFFD4C4A8).withValues(alpha: 0.2)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 20),
      );
    }

    // Worn edges
    final edgePaint = Paint()
      ..shader = LinearGradient(
        colors: [
          const Color(0xFFD4C4A8).withValues(alpha: 0.3),
          Colors.transparent,
        ],
      ).createShader(Rect.fromLTWH(0, 0, 30, size.height));
    canvas.drawRect(Rect.fromLTWH(0, 0, 30, size.height), edgePaint);
  }

  @override
  bool shouldRepaint(covariant _PaperTexturePainter oldDelegate) => false;
}

class _PostmarkPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF8B0000).withValues(alpha: 0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    // Outer circle
    canvas.drawCircle(
      Offset(size.width / 2, size.height / 2),
      size.width / 2 - 5,
      paint,
    );

    // Inner circle
    canvas.drawCircle(
      Offset(size.width / 2, size.height / 2),
      size.width / 3,
      paint,
    );

    // Wavy lines
    for (var i = -2; i <= 2; i++) {
      final y = size.height / 2 + i * 8;
      canvas.drawLine(Offset(5, y), Offset(size.width - 5, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
