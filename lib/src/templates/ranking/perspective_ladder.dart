import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../presentation/time_consumer.dart';
import '../../presentation/video_composition.dart';
import '../../declarative/animations/core/animated_prop.dart';
import '../../declarative/animations/core/prop_animation.dart';
import '../_base/template_base.dart';
import '../_base/template_config.dart';
import '../_base/template_data.dart';

/// A 3D perspective list extending into the distance.
///
/// Creates a dramatic ranking display where items appear as if receding
/// into the horizon, with the #1 item closest and most prominent. Items
/// animate in from the vanishing point and settle into their positions.
///
/// Best used for:
/// - Top 5-10 lists
/// - Artist/song rankings
/// - Achievement progressions
///
/// Example:
/// ```dart
/// PerspectiveLadder(
///   data: RankingData(
///     title: 'Top Genres',
///     items: [
///       RankingItem(rank: 1, label: 'Pop', value: '45%'),
///       RankingItem(rank: 2, label: 'Hip-Hop', value: '28%'),
///       // ...
///     ],
///   ),
///   theme: TemplateTheme.midnight,
/// )
/// ```
class PerspectiveLadder extends WrappedTemplate with TemplateAnimationMixin {
  /// Depth of the perspective effect (higher = more dramatic).
  final double perspectiveDepth;

  /// Spacing between ladder rungs.
  final double rungSpacing;

  /// Whether to show glow trails.
  final bool showGlowTrails;

  /// Animation delay between each item (in frames).
  final int staggerDelay;

  const PerspectiveLadder({
    super.key,
    required RankingData super.data,
    super.theme,
    super.timing,
    this.perspectiveDepth = 0.004,
    this.rungSpacing = 100,
    this.showGlowTrails = true,
    this.staggerDelay = 12,
  });

  @override
  int get recommendedLength => 180;

  @override
  TemplateCategory get category => TemplateCategory.ranking;

  @override
  String get description => '3D perspective list extending into the distance';

  @override
  TemplateTheme get defaultTheme => TemplateTheme.midnight;

  RankingData get rankingData => data as RankingData;

  @override
  Widget build(BuildContext context) {
    final colors = effectiveTheme;
    final items = rankingData.sortedItems;
    final itemCount = math.min(items.length, 10);

    return Container(
      color: colors.backgroundColor,
      child: Stack(
        children: [
          // Perspective grid background
          Positioned.fill(child: _buildPerspectiveGrid(colors)),

          // Title
          Positioned(top: 40, left: 0, right: 0, child: _buildTitle(colors)),

          // Ladder items with perspective
          Positioned.fill(
            child: _buildPerspectiveLadder(
              colors,
              items.take(itemCount).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTitle(TemplateTheme colors) {
    return AnimatedProp(
      startFrame: 0,
      duration: 30,
      animation: PropAnimation.fadeIn(),
      child: Text(
        rankingData.title ?? 'Your Rankings',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 36,
          fontWeight: FontWeight.w800,
          color: colors.textColor,
          letterSpacing: 4,
        ),
      ),
    );
  }

  Widget _buildPerspectiveGrid(TemplateTheme colors) {
    return TimeConsumer(
      builder: (context, frame, _) {
        return CustomPaint(
          painter: _PerspectiveGridPainter(
            color: colors.primaryColor.withValues(alpha: 0.1),
            vanishingPointY: 0.3,
            lineCount: 20,
            frame: frame,
          ),
          size: Size.infinite,
        );
      },
    );
  }

  Widget _buildPerspectiveLadder(
    TemplateTheme colors,
    List<RankingItem> items,
  ) {
    return TimeConsumer(
      builder: (context, frame, _) {
        final composition = VideoComposition.of(context);
        final fps = composition?.fps ?? 30;

        return LayoutBuilder(
          builder: (context, constraints) {
            final centerX = constraints.maxWidth / 2;
            final vanishingPointY = constraints.maxHeight * 0.25;
            final baseY = constraints.maxHeight * 0.85;

            return Stack(
              clipBehavior: Clip.none,
              children: List.generate(items.length, (index) {
                final item = items[index];
                final reverseIndex = items.length - 1 - index;

                // Position calculation with perspective
                final depthFactor = 1.0 - (reverseIndex * 0.12);
                final y = baseY - (reverseIndex * rungSpacing * depthFactor);
                final scale = math.max(0.3, depthFactor);

                // Entry animation
                final entryStart = 20 + (reverseIndex * staggerDelay);
                final entryProgress = calculateEntryProgress(
                  frame,
                  entryStart,
                  40,
                );
                final easedEntry = Curves.easeOutCubic.transform(entryProgress);

                // Items fly in from vanishing point
                final entryY =
                    vanishingPointY + ((y - vanishingPointY) * easedEntry);
                final entryScale = scale * easedEntry;
                final entryOpacity = easedEntry;

                // Glow pulse for #1
                double glowIntensity = 0.0;
                if (item.rank == 1 && entryProgress >= 1.0) {
                  final pulseTime = (frame - (entryStart + 40)) / fps;
                  glowIntensity = 0.3 + 0.2 * math.sin(pulseTime * 3);
                }

                return Positioned(
                  left: centerX - (175 * entryScale),
                  top: entryY - (35 * entryScale),
                  child: Transform.scale(
                    scale: entryScale,
                    child: Opacity(
                      opacity: entryOpacity.clamp(0.0, 1.0),
                      child: _buildLadderRung(
                        item,
                        colors,
                        item.rank == 1,
                        glowIntensity,
                        depthFactor,
                      ),
                    ),
                  ),
                );
              }),
            );
          },
        );
      },
    );
  }

  Widget _buildLadderRung(
    RankingItem item,
    TemplateTheme colors,
    bool isTop,
    double glowIntensity,
    double depthFactor,
  ) {
    const rungWidth = 350.0;
    const rungHeight = 70.0;

    return Container(
      width: rungWidth,
      height: rungHeight,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isTop
              ? [colors.accentColor, colors.primaryColor]
              : [
                  colors.secondaryColor,
                  colors.secondaryColor.withValues(alpha: 0.8),
                ],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isTop
              ? colors.accentColor.withValues(alpha: 0.8)
              : colors.primaryColor.withValues(alpha: 0.3),
          width: isTop ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isTop
                ? colors.accentColor.withValues(alpha: 0.3 + glowIntensity)
                : Colors.black.withValues(alpha: 0.2),
            blurRadius: isTop ? 30 : 10,
            spreadRadius: isTop ? 5 : 0,
          ),
          if (showGlowTrails)
            BoxShadow(
              color: colors.primaryColor.withValues(alpha: 0.1 * depthFactor),
              blurRadius: 40,
              offset: const Offset(0, 20),
            ),
        ],
      ),
      child: Row(
        children: [
          // Rank number
          Container(
            width: 60,
            decoration: BoxDecoration(
              color: isTop
                  ? colors.backgroundColor.withValues(alpha: 0.3)
                  : colors.primaryColor.withValues(alpha: 0.3),
              borderRadius: const BorderRadius.horizontal(
                left: Radius.circular(12),
              ),
            ),
            child: Center(
              child: Text(
                '${item.rank}',
                style: TextStyle(
                  fontSize: isTop ? 32 : 24,
                  fontWeight: FontWeight.w900,
                  color: isTop ? colors.backgroundColor : colors.textColor,
                ),
              ),
            ),
          ),

          // Item info
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.label,
                    style: TextStyle(
                      fontSize: isTop ? 22 : 18,
                      fontWeight: FontWeight.w700,
                      color: isTop ? colors.backgroundColor : colors.textColor,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (item.subtitle != null)
                    Text(
                      item.subtitle!,
                      style: TextStyle(
                        fontSize: 12,
                        color: isTop
                            ? colors.backgroundColor.withValues(alpha: 0.8)
                            : colors.textColor.withValues(alpha: 0.7),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
          ),

          // Value
          if (item.value != null)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Text(
                '${item.value}',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: isTop
                      ? colors.backgroundColor.withValues(alpha: 0.9)
                      : colors.primaryColor,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Custom painter for the perspective grid background.
class _PerspectiveGridPainter extends CustomPainter {
  final Color color;
  final double vanishingPointY;
  final int lineCount;
  final int frame;

  _PerspectiveGridPainter({
    required this.color,
    required this.vanishingPointY,
    required this.lineCount,
    required this.frame,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;

    final vpX = size.width / 2;
    final vpY = size.height * vanishingPointY;

    // Horizontal lines receding into distance
    for (var i = 0; i < lineCount; i++) {
      final t = i / lineCount;
      final y = vpY + (size.height - vpY) * t * t; // Quadratic for perspective
      final xSpread = size.width * 0.5 * t;

      // Animate grid lines
      final animOffset = (frame * 0.5 + i * 10) % 100;
      final animatedY = y + animOffset * 0.1;

      if (animatedY < size.height) {
        paint.color = color.withValues(alpha: color.a * t);
        canvas.drawLine(
          Offset(vpX - xSpread, animatedY),
          Offset(vpX + xSpread, animatedY),
          paint,
        );
      }
    }

    // Vertical lines from vanishing point
    for (var i = -5; i <= 5; i++) {
      if (i == 0) continue;
      final endX = vpX + (size.width * 0.5 * i / 5);
      paint.color = color.withValues(alpha: color.a * 0.5);
      canvas.drawLine(Offset(vpX, vpY), Offset(endX, size.height), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _PerspectiveGridPainter oldDelegate) {
    return oldDelegate.frame != frame || oldDelegate.color != color;
  }
}
