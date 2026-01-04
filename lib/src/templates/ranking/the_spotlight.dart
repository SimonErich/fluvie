import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../presentation/time_consumer.dart';
import '../../declarative/animations/core/animated_prop.dart';
import '../../declarative/animations/core/prop_animation.dart';
import '../_base/template_base.dart';
import '../_base/template_config.dart';
import '../_base/template_data.dart';

/// Darkness with a circular spotlight that moves across 5 icons, stopping on each.
///
/// Creates a dramatic reveal effect where a spotlight illuminates items
/// one by one against a dark background, building anticipation as it
/// moves toward the winner.
///
/// Best used for:
/// - Sequential reveals
/// - Award presentations
/// - Suspenseful rankings
///
/// Example:
/// ```dart
/// TheSpotlight(
///   data: RankingData(
///     title: 'Your Top 5',
///     items: [...],
///   ),
///   framesPerItem: 25,
/// )
/// ```
class TheSpotlight extends WrappedTemplate with TemplateAnimationMixin {
  /// Frames to pause on each item.
  final int framesPerItem;

  /// Spotlight radius when focused.
  final double spotlightRadius;

  /// Whether to show item labels.
  final bool showLabels;

  const TheSpotlight({
    super.key,
    required RankingData super.data,
    super.theme,
    super.timing,
    this.framesPerItem = 25,
    this.spotlightRadius = 150,
    this.showLabels = true,
  });

  @override
  int get recommendedLength => 30 + (rankingData.count * framesPerItem) + 50;

  @override
  TemplateCategory get category => TemplateCategory.ranking;

  @override
  String get description =>
      'Spotlight moves across items, revealing each dramatically';

  RankingData get rankingData => data as RankingData;

  @override
  Widget build(BuildContext context) {
    final colors = effectiveTheme;
    final items = rankingData.sortedItems.reversed.toList(); // 5 to 1
    final itemCount = math.min(items.length, 5);

    return Container(
      color: Colors.black,
      child: Stack(
        children: [
          // Title (always visible)
          Positioned(
            top: 50,
            left: 0,
            right: 0,
            child: AnimatedProp(
              startFrame: 5,
              duration: 20,
              animation: PropAnimation.fadeIn(),
              child: Text(
                rankingData.title ?? 'Your Top $itemCount',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.w700,
                  color: colors.textColor.withValues(alpha: 0.8),
                ),
              ),
            ),
          ),

          // Items in darkness
          Positioned.fill(
            child: _buildItemsWithSpotlight(
              colors,
              items.take(itemCount).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemsWithSpotlight(
    TemplateTheme colors,
    List<RankingItem> items,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Calculate item positions (horizontal row)
        final itemWidth = constraints.maxWidth / (items.length + 1);
        final centerY = constraints.maxHeight * 0.55;

        final itemPositions = List.generate(items.length, (index) {
          return Offset(itemWidth * (index + 1), centerY);
        });

        return TimeConsumer(
          builder: (context, frame, _) {
            final startFrame = 30;

            // Calculate which item the spotlight is on
            final elapsed = frame - startFrame;
            final currentItemIndex = (elapsed / framesPerItem).floor().clamp(
                  0,
                  items.length - 1,
                );
            final progressInItem =
                ((elapsed % framesPerItem) / framesPerItem).clamp(0.0, 1.0);

            // Spotlight position interpolation
            Offset spotlightCenter;
            if (elapsed < 0) {
              // Before start - spotlight off screen
              spotlightCenter = Offset(-spotlightRadius * 2, centerY);
            } else if (currentItemIndex >= items.length - 1 &&
                progressInItem >= 0.9) {
              // On winner - stay centered
              spotlightCenter = itemPositions.last;
            } else {
              // Moving between items
              final fromPos = currentItemIndex > 0
                  ? itemPositions[currentItemIndex - 1]
                  : Offset(-spotlightRadius, centerY);
              final toPos = itemPositions[currentItemIndex];

              // Ease into position
              final moveProgress = Curves.easeInOutCubic.transform(
                progressInItem.clamp(0.0, 0.3) / 0.3,
              );
              spotlightCenter = Offset.lerp(fromPos, toPos, moveProgress)!;
            }

            // Winner celebration
            final isOnWinner =
                currentItemIndex >= items.length - 1 && progressInItem > 0.5;
            final celebrationScale = isOnWinner ? 1.3 : 1.0;

            return Stack(
              children: [
                // Spotlight mask layer
                CustomPaint(
                  painter: _SpotlightPainter(
                    center: spotlightCenter,
                    radius: spotlightRadius * celebrationScale,
                    color: colors.primaryColor,
                    isHighlight: isOnWinner,
                  ),
                  size: Size.infinite,
                ),

                // Items
                ...List.generate(items.length, (index) {
                  final item = items[index];
                  final pos = itemPositions[index];
                  final isLit = index <= currentItemIndex &&
                      (index < currentItemIndex || progressInItem > 0.2);
                  final isWinner = index == items.length - 1;
                  final isCurrentlyLit = index == currentItemIndex;

                  // Scale animation when spotlight lands
                  double scale = 1.0;
                  if (isCurrentlyLit &&
                      progressInItem > 0.2 &&
                      progressInItem < 0.5) {
                    final bounceProgress = (progressInItem - 0.2) / 0.3;
                    scale = 1.0 +
                        0.1 * Curves.easeOutBack.transform(bounceProgress);
                  }
                  if (isWinner && isOnWinner) {
                    scale = 1.2;
                  }

                  return Positioned(
                    left: pos.dx - 80,
                    top: pos.dy - 100,
                    child: Transform.scale(
                      scale: scale,
                      child: Opacity(
                        opacity: isLit ? 1.0 : 0.15,
                        child: _buildItem(item, colors, isWinner && isOnWinner),
                      ),
                    ),
                  );
                }),

                // Labels appear after spotlight passes
                if (showLabels)
                  ...List.generate(items.length, (index) {
                    final item = items[index];
                    final pos = itemPositions[index];
                    final showLabel = index < currentItemIndex ||
                        (index == currentItemIndex && progressInItem > 0.6);

                    if (!showLabel) return const SizedBox.shrink();

                    return Positioned(
                      left: pos.dx - 80,
                      top: pos.dy + 70,
                      width: 160,
                      child: Text(
                        item.label,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: colors.textColor,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildItem(RankingItem item, TemplateTheme colors, bool isWinner) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Image/icon
        Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: colors.secondaryColor,
            border: Border.all(
              color: isWinner ? colors.accentColor : colors.primaryColor,
              width: isWinner ? 4 : 2,
            ),
            boxShadow: isWinner
                ? [
                    BoxShadow(
                      color: colors.accentColor.withValues(alpha: 0.5),
                      blurRadius: 30,
                      spreadRadius: 10,
                    ),
                  ]
                : null,
          ),
          child: ClipOval(
            child: item.imagePath != null
                ? Image.asset(
                    item.imagePath!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) =>
                        _buildPlaceholder(colors, item.rank),
                  )
                : _buildPlaceholder(colors, item.rank),
          ),
        ),

        const SizedBox(height: 8),

        // Rank badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: isWinner ? colors.accentColor : colors.primaryColor,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            '#${item.rank}',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: isWinner ? colors.backgroundColor : colors.textColor,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPlaceholder(TemplateTheme colors, int rank) {
    return Container(
      color: colors.primaryColor.withValues(alpha: 0.3),
      child: Center(
        child: Text(
          '$rank',
          style: TextStyle(
            fontSize: 36,
            fontWeight: FontWeight.w900,
            color: colors.textColor.withValues(alpha: 0.5),
          ),
        ),
      ),
    );
  }
}

/// Painter for the spotlight effect.
class _SpotlightPainter extends CustomPainter {
  final Offset center;
  final double radius;
  final Color color;
  final bool isHighlight;

  _SpotlightPainter({
    required this.center,
    required this.radius,
    required this.color,
    required this.isHighlight,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Draw darkness with spotlight hole
    final darkPaint = Paint()..color = Colors.black.withValues(alpha: 0.85);

    // Create path with hole
    final path = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addOval(Rect.fromCircle(center: center, radius: radius))
      ..fillType = PathFillType.evenOdd;

    canvas.drawPath(path, darkPaint);

    // Draw spotlight glow
    final glowPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          color.withValues(alpha: isHighlight ? 0.3 : 0.1),
          color.withValues(alpha: 0),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: radius * 1.5));

    canvas.drawCircle(center, radius * 1.5, glowPaint);
  }

  @override
  bool shouldRepaint(covariant _SpotlightPainter oldDelegate) {
    return oldDelegate.center != center ||
        oldDelegate.radius != radius ||
        oldDelegate.isHighlight != isHighlight;
  }
}
