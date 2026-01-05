import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../presentation/time_consumer.dart';
import '../../presentation/video_composition.dart';
import '../../declarative/animations/core/animated_prop.dart';
import '../../declarative/animations/core/prop_animation.dart';
import '../_base/template_base.dart';
import '../_base/template_config.dart';
import '../_base/template_data.dart';

/// Top albums mirrored in a rotating hexagon pattern.
///
/// Creates a mesmerizing kaleidoscope effect where album art or images
/// are reflected and rotated in a hexagonal pattern, creating an
/// abstract, psychedelic visual.
///
/// Best used for:
/// - Album showcases
/// - Psychedelic themes
/// - Visual abstracts
///
/// Example:
/// ```dart
/// Kaleidoscope(
///   data: ThematicData(
///     title: 'Your Top Sound',
///     images: ['album1.jpg', 'album2.jpg', 'album3.jpg'],
///   ),
///   segmentCount: 6,
/// )
/// ```
class Kaleidoscope extends WrappedTemplate with TemplateAnimationMixin {
  /// Number of mirror segments.
  final int segmentCount;

  /// Rotation speed.
  final double rotationSpeed;

  /// Zoom pulse intensity.
  final double pulseIntensity;

  /// Images to display in kaleidoscope.
  final List<String>? images;

  const Kaleidoscope({
    super.key,
    required ThematicData super.data,
    super.theme,
    super.timing,
    this.segmentCount = 6,
    this.rotationSpeed = 0.3,
    this.pulseIntensity = 0.1,
    this.images,
  });

  @override
  int get recommendedLength => 200;

  @override
  TemplateCategory get category => TemplateCategory.thematic;

  @override
  String get description => 'Albums mirrored in rotating kaleidoscope';

  @override
  TemplateTheme get defaultTheme => TemplateTheme.neon;

  ThematicData get thematicData => data as ThematicData;

  @override
  Widget build(BuildContext context) {
    final colors = effectiveTheme;

    return Container(
      color: colors.backgroundColor,
      child: Stack(
        children: [
          // Kaleidoscope pattern
          Positioned.fill(child: _buildKaleidoscope(colors)),

          // Center text overlay
          Positioned.fill(child: Center(child: _buildCenterContent(colors))),
        ],
      ),
    );
  }

  Widget _buildKaleidoscope(TemplateTheme colors) {
    return TimeConsumer(
      builder: (context, frame, _) {
        final composition = VideoComposition.of(context);
        final fps = composition?.fps ?? 30;
        final time = frame / fps;

        // Entry animation
        final entryProgress = ((frame - 10) / 60).clamp(0.0, 1.0);
        final entryScale = Curves.easeOutCubic.transform(entryProgress);

        // Rotation
        final rotation = time * rotationSpeed * math.pi * 2;

        // Pulse
        final pulse = 1.0 + math.sin(time * 2) * pulseIntensity;

        return Transform.scale(
          scale: entryScale * pulse,
          child: Transform.rotate(
            angle: rotation,
            child: CustomPaint(
              painter: _KaleidoscopePainter(
                segmentCount: segmentCount,
                colors: [
                  colors.primaryColor,
                  colors.secondaryColor,
                  colors.accentColor,
                  colors.primaryColor.withValues(alpha: 0.7),
                  colors.secondaryColor.withValues(alpha: 0.7),
                ],
                time: time,
              ),
              size: Size.infinite,
            ),
          ),
        );
      },
    );
  }

  Widget _buildCenterContent(TemplateTheme colors) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Title
        AnimatedProp(
          startFrame: 60,
          duration: 40,
          animation: PropAnimation.combine([
            const PropAnimation.scale(start: 0.8, end: 1.0),
            PropAnimation.fadeIn(),
          ]),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
            decoration: BoxDecoration(
              color: colors.backgroundColor.withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: colors.primaryColor.withValues(alpha: 0.4),
                  blurRadius: 30,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: Column(
              children: [
                Text(
                  thematicData.title ?? 'Your Vibe',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 42,
                    fontWeight: FontWeight.w900,
                    color: colors.textColor,
                  ),
                ),
                if (thematicData.subtitle != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    thematicData.subtitle!,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 24,
                      color: colors.primaryColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),

        if (thematicData.description != null) ...[
          const SizedBox(height: 30),
          AnimatedProp(
            startFrame: 100,
            duration: 30,
            animation: PropAnimation.slideUpFade(distance: 20),
            child: Text(
              thematicData.description!,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                color: colors.textColor.withValues(alpha: 0.8),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _KaleidoscopePainter extends CustomPainter {
  final int segmentCount;
  final List<Color> colors;
  final double time;

  _KaleidoscopePainter({
    required this.segmentCount,
    required this.colors,
    required this.time,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = math.max(size.width, size.height);
    final segmentAngle = 2 * math.pi / segmentCount;

    for (var segment = 0; segment < segmentCount; segment++) {
      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(segment * segmentAngle);

      // Mirror every other segment
      if (segment.isOdd) {
        canvas.scale(1, -1);
      }

      // Draw segment content
      _drawSegment(canvas, maxRadius, segment);

      canvas.restore();
    }
  }

  void _drawSegment(Canvas canvas, double maxRadius, int segment) {
    final path = Path();
    final segmentAngle = 2 * math.pi / segmentCount;

    // Triangle segment
    path.moveTo(0, 0);
    path.lineTo(maxRadius * math.cos(0), maxRadius * math.sin(0));
    path.lineTo(
      maxRadius * math.cos(segmentAngle / 2),
      maxRadius * math.sin(segmentAngle / 2),
    );
    path.close();

    canvas.clipPath(path);

    // Draw layered shapes within segment
    const layers = 8;
    for (var layer = layers; layer > 0; layer--) {
      final layerRadius = (layer / layers) * maxRadius * 0.8;
      final layerProgress = layer / layers;

      // Animated offset
      final animOffset = math.sin(time * 2 + layer * 0.5) * 20;

      // Choose color
      final colorIndex = (segment + layer) % colors.length;
      final color = colors[colorIndex];

      final shapePaint = Paint()
        ..color = color.withValues(alpha: 0.6 + layerProgress * 0.3)
        ..style = PaintingStyle.fill;

      // Draw hexagon/shape
      _drawShape(
        canvas,
        Offset(layerRadius * 0.5 + animOffset, 0),
        layerRadius * 0.3,
        shapePaint,
        layer,
      );
    }

    // Add geometric patterns
    _drawGeometricPattern(canvas, maxRadius, segment);
  }

  void _drawShape(
    Canvas canvas,
    Offset center,
    double radius,
    Paint paint,
    int layer,
  ) {
    final path = Path();
    const sides = 6;

    for (var i = 0; i < sides; i++) {
      final angle = (i / sides) * 2 * math.pi - math.pi / 2 + time * 0.5;
      final x = center.dx + radius * math.cos(angle);
      final y = center.dy + radius * math.sin(angle);

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();

    canvas.drawPath(path, paint);
  }

  void _drawGeometricPattern(Canvas canvas, double maxRadius, int segment) {
    final linePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.2)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    // Radial lines
    for (var i = 0; i < 5; i++) {
      final angle = (i / 5) * math.pi / segmentCount;
      canvas.drawLine(
        Offset.zero,
        Offset(maxRadius * math.cos(angle), maxRadius * math.sin(angle)),
        linePaint,
      );
    }

    // Concentric arcs
    for (var i = 1; i <= 5; i++) {
      final radius = (i / 5) * maxRadius * 0.8;
      canvas.drawArc(
        Rect.fromCircle(center: Offset.zero, radius: radius),
        0,
        math.pi / segmentCount,
        false,
        linePaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _KaleidoscopePainter oldDelegate) {
    return oldDelegate.time != time;
  }
}
