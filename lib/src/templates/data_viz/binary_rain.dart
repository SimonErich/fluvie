import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../presentation/time_consumer.dart';
import '../../declarative/animations/core/animated_prop.dart';
import '../../declarative/animations/core/prop_animation.dart';
import '../_base/template_base.dart';
import '../_base/template_config.dart';
import '../_base/template_data.dart';

/// Matrix-style falling song titles/data.
///
/// Creates a dramatic "digital rain" effect where song titles, artist names,
/// or other text data falls down the screen like the Matrix code rain.
/// Items fade in and out as they fall, creating a mesmerizing effect.
///
/// Best used for:
/// - Song lists
/// - Artist names
/// - Data points
///
/// Example:
/// ```dart
/// BinaryRain(
///   data: DataVizData(
///     title: 'Your Songs',
///     items: ['Song 1', 'Song 2', 'Song 3', ...],
///   ),
/// )
/// ```
class BinaryRain extends WrappedTemplate with TemplateAnimationMixin {
  /// Number of columns.
  final int columnCount;

  /// Speed of the falling text.
  final double fallSpeed;

  /// Items to display (song titles, artist names, etc.).
  final List<String> items;

  /// Whether to include actual binary characters.
  final bool includeBinary;

  /// Random seed for reproducibility.
  final int seed;

  const BinaryRain({
    super.key,
    required DataVizData super.data,
    super.theme,
    super.timing,
    this.columnCount = 20,
    this.fallSpeed = 1.0,
    this.items = const [],
    this.includeBinary = true,
    this.seed = 42,
  });

  @override
  int get recommendedLength => 180;

  @override
  TemplateCategory get category => TemplateCategory.dataViz;

  @override
  String get description => 'Matrix-style falling song titles';

  @override
  TemplateTheme get defaultTheme => TemplateTheme.neon;

  DataVizData get dataVizData => data as DataVizData;

  List<String> get effectiveItems {
    if (items.isNotEmpty) return items;
    // Use metric labels as items
    return dataVizData.metrics.map((m) => m.label).toList();
  }

  @override
  Widget build(BuildContext context) {
    final colors = effectiveTheme;

    return Container(
      color: colors.backgroundColor,
      child: Stack(
        children: [
          // Digital rain background
          Positioned.fill(child: _buildDigitalRain(colors)),

          // Title overlay with glow
          Positioned.fill(child: Center(child: _buildCenterContent(colors))),
        ],
      ),
    );
  }

  Widget _buildDigitalRain(TemplateTheme colors) {
    return TimeConsumer(
      builder: (context, frame, _) {
        return LayoutBuilder(
          builder: (context, constraints) {
            return CustomPaint(
              painter: _DigitalRainPainter(
                columnCount: columnCount,
                items: effectiveItems,
                frame: frame,
                fallSpeed: fallSpeed,
                includeBinary: includeBinary,
                primaryColor: colors.primaryColor,
                secondaryColor: colors.secondaryColor,
                seed: seed,
              ),
              size: Size.infinite,
            );
          },
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
          startFrame: 30,
          duration: 40,
          animation: PropAnimation.combine([
            PropAnimation.zoomIn(start: 0.8),
            PropAnimation.fadeIn(),
          ]),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
            decoration: BoxDecoration(
              color: colors.backgroundColor.withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: colors.primaryColor.withValues(alpha: 0.5),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: colors.primaryColor.withValues(alpha: 0.3),
                  blurRadius: 30,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: Column(
              children: [
                Text(
                  dataVizData.title ?? 'Your Data',
                  style: TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.w900,
                    color: colors.textColor,
                    letterSpacing: 4,
                  ),
                ),
                if (dataVizData.subtitle != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    dataVizData.subtitle!,
                    style: TextStyle(
                      fontSize: 24,
                      color: colors.primaryColor,
                      letterSpacing: 2,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),

        // Total stat
        if (dataVizData.total > 0) ...[
          const SizedBox(height: 30),
          AnimatedProp(
            startFrame: 60,
            duration: 30,
            animation: PropAnimation.slideUpFade(distance: 20),
            child: Text(
              '${dataVizData.total.toInt()} items',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w500,
                color: colors.textColor.withValues(alpha: 0.8),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _DigitalRainPainter extends CustomPainter {
  final int columnCount;
  final List<String> items;
  final int frame;
  final double fallSpeed;
  final bool includeBinary;
  final Color primaryColor;
  final Color secondaryColor;
  final int seed;

  _DigitalRainPainter({
    required this.columnCount,
    required this.items,
    required this.frame,
    required this.fallSpeed,
    required this.includeBinary,
    required this.primaryColor,
    required this.secondaryColor,
    required this.seed,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final columnWidth = size.width / columnCount;
    final fontSize = 14.0;
    final charHeight = fontSize * 1.5;

    // Generate columns
    for (var col = 0; col < columnCount; col++) {
      final colRandom = math.Random(seed + col);
      final colX = col * columnWidth + columnWidth / 2;

      // Column properties
      final speed = (0.5 + colRandom.nextDouble() * 0.5) * fallSpeed;
      final startOffset = colRandom.nextDouble() * size.height * 2;
      final streamLength = 15 + colRandom.nextInt(20);

      // Calculate current position
      final baseY =
          ((frame * speed * 3) + startOffset) %
          (size.height + streamLength * charHeight);

      // Draw stream of characters
      for (var i = 0; i < streamLength; i++) {
        final charY = baseY - (i * charHeight);

        if (charY < -charHeight || charY > size.height + charHeight) continue;

        // Fade based on position in stream
        final fadeProgress = i / streamLength;
        final opacity = (1.0 - fadeProgress * 0.8).clamp(0.0, 1.0);

        // First character is brightest
        final isBrightest = i == 0;

        // Get character
        String char;
        if (includeBinary && colRandom.nextDouble() > 0.3) {
          char = colRandom.nextBool() ? '1' : '0';
        } else if (items.isNotEmpty) {
          final item = items[(col + i) % items.length];
          final charIndex = (frame ~/ 5 + i) % item.length;
          char = item[charIndex];
        } else {
          char = String.fromCharCode(
            0x30A0 + colRandom.nextInt(96),
          ); // Katakana
        }

        // Color
        Color color;
        if (isBrightest) {
          color = Colors.white;
        } else {
          color = Color.lerp(
            primaryColor,
            secondaryColor,
            fadeProgress,
          )!.withValues(alpha: opacity * 0.9);
        }

        // Draw character
        final textSpan = TextSpan(
          text: char,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: isBrightest ? FontWeight.w900 : FontWeight.w400,
            color: color,
            fontFamily: 'monospace',
            shadows: isBrightest
                ? [
                    Shadow(
                      color: primaryColor.withValues(alpha: 0.8),
                      blurRadius: 10,
                    ),
                  ]
                : null,
          ),
        );

        final textPainter = TextPainter(
          text: textSpan,
          textDirection: TextDirection.ltr,
        )..layout();

        textPainter.paint(canvas, Offset(colX - textPainter.width / 2, charY));
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DigitalRainPainter oldDelegate) {
    return oldDelegate.frame != frame;
  }
}
