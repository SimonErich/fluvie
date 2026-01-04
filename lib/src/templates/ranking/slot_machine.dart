import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../presentation/time_consumer.dart';
import '../../declarative/animations/core/animated_prop.dart';
import '../../declarative/animations/core/prop_animation.dart';
import '../_base/template_base.dart';
import '../_base/template_config.dart';
import '../_base/template_data.dart';

/// Numbers/titles scroll rapidly vertically, slowing down to reveal the winner.
///
/// Creates a slot machine effect where rankings spin rapidly before
/// gradually decelerating to land on the winning entry, complete with
/// a satisfying "click" visual effect.
///
/// Best used for:
/// - Single winner reveals
/// - Random selection effects
/// - Top artist/song reveals
///
/// Example:
/// ```dart
/// SlotMachine(
///   data: RankingData(
///     title: 'Your #1 Song',
///     items: [
///       RankingItem(rank: 1, label: 'Song Title', imagePath: 'cover.jpg'),
///       // Add other items for scrolling variety
///     ],
///   ),
/// )
/// ```
class SlotMachine extends WrappedTemplate with TemplateAnimationMixin {
  /// Number of full scroll cycles before settling.
  final int spinCycles;

  /// Whether to show the slot machine frame.
  final bool showFrame;

  const SlotMachine({
    super.key,
    required RankingData super.data,
    super.theme,
    super.timing,
    this.spinCycles = 5,
    this.showFrame = true,
  });

  @override
  int get recommendedLength => 180;

  @override
  TemplateCategory get category => TemplateCategory.ranking;

  @override
  String get description => 'Slot machine scroll effect revealing the winner';

  RankingData get rankingData => data as RankingData;

  @override
  Widget build(BuildContext context) {
    final colors = effectiveTheme;

    return Container(
      color: colors.backgroundColor,
      child: Stack(
        children: [
          // Title
          Positioned(
            top: 80,
            left: 0,
            right: 0,
            child: AnimatedProp(
              startFrame: 5,
              duration: 25,
              animation: PropAnimation.slideUpFade(distance: 30),
              child: Text(
                rankingData.title ?? 'And the winner is...',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.w700,
                  color: colors.textColor,
                ),
              ),
            ),
          ),

          // Slot machine
          Positioned.fill(child: Center(child: _buildSlotMachine(colors))),
        ],
      ),
    );
  }

  Widget _buildSlotMachine(TemplateTheme colors) {
    return TimeConsumer(
      builder: (context, frame, _) {
        // Animation phases
        final spinStart = 30;
        final spinDuration = 90;
        final settleStart = spinStart + spinDuration;
        final settleDuration = 40;

        // Spin progress with easeOut for deceleration
        double scrollOffset = 0;

        if (frame >= spinStart && frame < settleStart) {
          // Fast spinning phase
          final spinProgress = (frame - spinStart) / spinDuration;
          // Gradually slow down
          final speed = math.pow(1 - spinProgress * 0.7, 0.5);
          scrollOffset = spinProgress * spinCycles * 1000 * speed;
        } else if (frame >= settleStart) {
          // Settling phase
          final settleProgress = ((frame - settleStart) / settleDuration).clamp(
            0.0,
            1.0,
          );
          final easedSettle = Curves.bounceOut.transform(settleProgress);
          // Final wobble to center
          final targetOffset = spinCycles * 1000.0;
          scrollOffset = targetOffset * (1 + (1 - easedSettle) * 0.05);
        }

        // Entry animation
        final entryProgress = calculateEntryProgress(frame, 15, 30);
        final entryScale = Curves.easeOutBack.transform(entryProgress);

        return Transform.scale(
          scale: entryScale,
          child: Opacity(
            opacity: entryProgress,
            child: Container(
              width: 500,
              height: 400,
              decoration: showFrame
                  ? BoxDecoration(
                      color: colors.secondaryColor,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: colors.primaryColor, width: 4),
                      boxShadow: [
                        BoxShadow(
                          color: colors.primaryColor.withValues(alpha: 0.3),
                          blurRadius: 30,
                          spreadRadius: 5,
                        ),
                      ],
                    )
                  : null,
              child: Stack(
                children: [
                  // Scrolling content
                  ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: _buildScrollingContent(colors, scrollOffset),
                  ),

                  // Selection highlight
                  Positioned(
                    left: 20,
                    right: 20,
                    top: 0,
                    bottom: 0,
                    child: Center(
                      child: Container(
                        height: 120,
                        decoration: BoxDecoration(
                          border: Border.symmetric(
                            horizontal: BorderSide(
                              color: colors.accentColor,
                              width: 3,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Gradient overlays for depth
                  Positioned(
                    left: 0,
                    right: 0,
                    top: 0,
                    child: Container(
                      height: 100,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            colors.secondaryColor,
                            colors.secondaryColor.withValues(alpha: 0),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: Container(
                      height: 100,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [
                            colors.secondaryColor,
                            colors.secondaryColor.withValues(alpha: 0),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildScrollingContent(TemplateTheme colors, double scrollOffset) {
    final items = rankingData.items;
    final winner = rankingData.topItem;

    // Create extended list for scrolling
    final displayItems = <RankingItem>[];
    for (var i = 0; i < spinCycles + 2; i++) {
      displayItems.addAll(items);
    }
    // Ensure winner is last
    displayItems.add(winner);

    final itemHeight = 120.0;
    final totalHeight = displayItems.length * itemHeight;

    // Calculate offset to show items centered
    final normalizedOffset = scrollOffset % totalHeight;

    return Transform.translate(
      offset: Offset(0, -normalizedOffset + 140),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: displayItems.map((item) {
          return Container(
            height: itemHeight,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Row(
              children: [
                // Image
                if (item.imagePath != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.asset(
                      item.imagePath!,
                      width: 80,
                      height: 80,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: colors.primaryColor.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.music_note,
                          color: colors.textColor.withValues(alpha: 0.5),
                        ),
                      ),
                    ),
                  ),
                const SizedBox(width: 16),
                // Label
                Expanded(
                  child: Text(
                    item.label,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: colors.textColor,
                    ),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}
