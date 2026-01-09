import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../presentation/time_consumer.dart';
import '../../declarative/animations/core/animated_prop.dart';
import '../../declarative/animations/core/prop_animation.dart';
import '../../declarative/effects/particle_effect.dart';
import '../_base/template_base.dart';
import '../_base/template_config.dart';
import '../_base/template_data.dart';

/// Direction for stack climb slide-off animation.
enum StackSlideDirection {
  /// Slide to the left.
  left,

  /// Slide to the right.
  right,

  /// Slide upward.
  up,

  /// Slide downward.
  down,
}

/// Five elements stacked, with top 4 sliding off to reveal the #1 spot.
///
/// Creates a dramatic ranking reveal where items appear stacked on top
/// of each other, then slide away one by one until only the winner remains,
/// which then celebrates with a scale-up effect.
///
/// Best used for:
/// - Top 5 lists
/// - Winner reveals
/// - Countdown rankings
///
/// Example:
/// ```dart
/// StackClimb(
///   data: RankingData(
///     title: 'Your Top Artists',
///     items: [
///       RankingItem(rank: 1, label: 'Taylor Swift', imagePath: 'taylor.jpg'),
///       RankingItem(rank: 2, label: 'Drake', imagePath: 'drake.jpg'),
///       // ...
///     ],
///   ),
///   theme: TemplateTheme.spotify,
/// )
/// ```
class StackClimb extends WrappedTemplate with TemplateAnimationMixin {
  /// Direction items slide off.
  final StackSlideDirection slideDirection;

  /// Whether to show confetti when #1 is revealed.
  final bool showConfetti;

  /// Delay between each item sliding off (in frames).
  final int slideDelay;

  const StackClimb({
    super.key,
    required RankingData super.data,
    super.theme,
    super.timing,
    this.slideDirection = StackSlideDirection.left,
    this.showConfetti = true,
    this.slideDelay = 25,
  });

  @override
  int get recommendedLength => 200;

  @override
  TemplateCategory get category => TemplateCategory.ranking;

  @override
  String get description => 'Stacked items slide away to reveal the top spot';

  @override
  TemplateTheme get defaultTheme => TemplateTheme.spotify;

  RankingData get rankingData => data as RankingData;

  @override
  Widget build(BuildContext context) {
    final colors = effectiveTheme;
    final items = rankingData.sortedItems.reversed.toList(); // 5,4,3,2,1 order
    final itemCount = math.min(items.length, 5);

    return Container(
      color: colors.backgroundColor,
      child: Stack(
        children: [
          // Title
          Positioned(top: 60, left: 0, right: 0, child: _buildTitle(colors)),

          // Stacked cards
          Positioned.fill(
            child: Center(
              child: _buildStackedCards(
                  context, colors, items.take(itemCount).toList()),
            ),
          ),

          // Confetti for winner
          if (showConfetti)
            Positioned.fill(child: _buildWinnerConfetti(colors, itemCount)),
        ],
      ),
    );
  }

  Widget _buildTitle(TemplateTheme colors) {
    return AnimatedProp(
      startFrame: 5,
      duration: 30,
      animation: PropAnimation.slideUpFade(distance: 30),
      child: Text(
        rankingData.title ?? 'Your Top ${rankingData.count}',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 48,
          fontWeight: FontWeight.w800,
          color: colors.textColor,
        ),
      ),
    );
  }

  Widget _buildStackedCards(
      BuildContext context, TemplateTheme colors, List<RankingItem> items) {
    return TimeConsumer(
      builder: (context, frame, _) {
        const entryStart = 30;

        return Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: List.generate(items.length, (index) {
            final item = items[index];
            final isWinner = item.rank == 1;

            // Entry animation
            final itemEntryStart = entryStart + (index * 8);
            final entryProgress = calculateEntryProgress(
              frame,
              itemEntryStart,
              35,
            );
            final entryScale = Curves.easeOutBack.transform(entryProgress);

            // Slide off animation (all except winner)
            double slideOffset = 0;
            double slideOpacity = 1.0;

            if (!isWinner) {
              // Cards slide off in reverse order (5 first, then 4, etc.)
              final reverseIndex = items.length - 1 - index;
              final slideStart = entryStart +
                  (items.length * 8) +
                  30 +
                  (reverseIndex * slideDelay);
              final slideProgress = calculateEntryProgress(
                frame,
                slideStart,
                25,
              );
              final easedSlide = Curves.easeInCubic.transform(slideProgress);

              slideOffset = easedSlide * _getSlideDistance(slideDirection);
              slideOpacity = 1.0 - easedSlide;
            }

            // Winner celebration
            double winnerScale = 1.0;
            if (isWinner) {
              final celebrationStart = entryStart +
                  (items.length * 8) +
                  30 +
                  ((items.length - 1) * slideDelay) +
                  20;
              final celebrationProgress = calculateEntryProgress(
                frame,
                celebrationStart,
                30,
              );
              if (celebrationProgress > 0) {
                winnerScale = 1.0 +
                    (0.2 * Curves.easeOutBack.transform(celebrationProgress));
              }
            }

            // Stack offset (cards slightly offset from each other)
            final stackOffset = (items.length - 1 - index) * 5.0;

            return Transform.translate(
              offset: Offset(
                slideDirection == StackSlideDirection.left ||
                        slideDirection == StackSlideDirection.right
                    ? slideOffset
                    : 0,
                slideDirection == StackSlideDirection.up ||
                        slideDirection == StackSlideDirection.down
                    ? slideOffset
                    : -stackOffset,
              ),
              child: Transform.scale(
                scale: entryScale * winnerScale,
                child: Opacity(
                  opacity: (entryProgress * slideOpacity).clamp(0.0, 1.0),
                  child: _buildCard(context, item, colors, isWinner, frame),
                ),
              ),
            );
          }),
        );
      },
    );
  }

  double _getSlideDistance(StackSlideDirection direction) {
    switch (direction) {
      case StackSlideDirection.left:
        return -800;
      case StackSlideDirection.right:
        return 800;
      case StackSlideDirection.up:
        return -600;
      case StackSlideDirection.down:
        return 600;
    }
  }

  Widget _buildCard(
    BuildContext context,
    RankingItem item,
    TemplateTheme colors,
    bool isWinner,
    int frame,
  ) {
    final cardWidth = isWinner ? 400.0 : 350.0;
    final cardHeight = isWinner ? 450.0 : 400.0;

    return Container(
      width: cardWidth,
      height: cardHeight,
      decoration: BoxDecoration(
        color: colors.secondaryColor,
        borderRadius: BorderRadius.circular(20),
        border:
            isWinner ? Border.all(color: colors.accentColor, width: 4) : null,
        boxShadow: [
          BoxShadow(
            color: isWinner
                ? colors.accentColor.withValues(alpha: 0.4)
                : Colors.black.withValues(alpha: 0.3),
            blurRadius: isWinner ? 40 : 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          // Image
          Expanded(
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(20),
              ),
              child: _buildItemImage(context, item, colors),
            ),
          ),

          // Info
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                // Rank badge
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isWinner ? colors.accentColor : colors.primaryColor,
                  ),
                  child: Center(
                    child: Text(
                      '#${item.rank}',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: isWinner
                            ? colors.backgroundColor
                            : colors.textColor,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                // Label
                Text(
                  item.label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: isWinner ? 24 : 20,
                    fontWeight: FontWeight.w700,
                    color: colors.textColor,
                  ),
                ),
                if (item.value != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    '${item.value}',
                    style: TextStyle(
                      fontSize: 14,
                      color: colors.mutedColor ??
                          colors.textColor.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemImage(
      BuildContext context, RankingItem item, TemplateTheme colors) {
    final imageWidget = item.buildImage(context);
    if (imageWidget != null) {
      return SizedBox.expand(
        child: FittedBox(
          fit: BoxFit.cover,
          clipBehavior: Clip.hardEdge,
          child: imageWidget,
        ),
      );
    }
    return _buildPlaceholderImage(colors);
  }

  Widget _buildPlaceholderImage(TemplateTheme colors) {
    return Container(
      color: colors.primaryColor.withValues(alpha: 0.3),
      child: Center(
        child: Icon(
          Icons.music_note,
          size: 80,
          color: colors.textColor.withValues(alpha: 0.5),
        ),
      ),
    );
  }

  Widget _buildWinnerConfetti(TemplateTheme colors, int itemCount) {
    return TimeConsumer(
      builder: (context, frame, _) {
        // Calculate when winner is revealed
        final revealFrame =
            30 + (itemCount * 8) + 30 + ((itemCount - 1) * slideDelay) + 15;
        final showConfetti = frame >= revealFrame;

        if (!showConfetti) {
          return const SizedBox.shrink();
        }

        return ParticleEffect.confetti(
          count: 60,
          colors: [
            colors.accentColor,
            colors.primaryColor,
            colors.secondaryColor,
            Colors.white,
          ],
        );
      },
    );
  }
}
