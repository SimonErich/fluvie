import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../presentation/time_consumer.dart';
import '../../declarative/animations/core/animated_prop.dart';
import '../../declarative/animations/core/prop_animation.dart';
import '../_base/template_base.dart';
import '../_base/template_config.dart';
import '../_base/template_data.dart';

/// A 3x3 grid where images shuffle rapidly then settle into place.
///
/// Creates an exciting reveal where images swap positions rapidly
/// like a shuffle animation before settling into their final grid
/// arrangement. Each cell can contain album art, photos, or colors.
///
/// Best used for:
/// - Top 9 grid
/// - Photo collages
/// - Album art displays
///
/// Example:
/// ```dart
/// TheGridShuffle(
///   data: CollageData(
///     title: 'Your Top Albums',
///     images: [
///       'album1.jpg', 'album2.jpg', 'album3.jpg',
///       'album4.jpg', 'album5.jpg', 'album6.jpg',
///       'album7.jpg', 'album8.jpg', 'album9.jpg',
///     ],
///   ),
/// )
/// ```
class TheGridShuffle extends WrappedTemplate with TemplateAnimationMixin {
  /// Grid dimensions (rows x columns).
  final int gridSize;

  /// Duration of the shuffle phase in frames.
  final int shuffleDuration;

  /// Gap between grid cells.
  final double cellGap;

  /// Random seed for shuffle pattern.
  final int seed;

  const TheGridShuffle({
    super.key,
    required CollageData super.data,
    super.theme,
    super.timing,
    this.gridSize = 3,
    this.shuffleDuration = 60,
    this.cellGap = 8,
    this.seed = 42,
  });

  @override
  int get recommendedLength => 150;

  @override
  TemplateCategory get category => TemplateCategory.collage;

  @override
  String get description => '3x3 grid with shuffling images that settle';

  @override
  TemplateTheme get defaultTheme => TemplateTheme.spotify;

  CollageData get collageData => data as CollageData;

  @override
  Widget build(BuildContext context) {
    final colors = effectiveTheme;

    return Container(
      color: colors.backgroundColor,
      child: Stack(
        children: [
          // Title
          Positioned(
            top: 40,
            left: 0,
            right: 0,
            child: AnimatedProp(
              startFrame: 0,
              duration: 25,
              animation: PropAnimation.fadeIn(),
              child: Text(
                collageData.title ?? 'Your Collection',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  color: colors.textColor,
                ),
              ),
            ),
          ),

          // Shuffle grid
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(40, 100, 40, 80),
              child: _buildShuffleGrid(colors),
            ),
          ),

          // Subtitle
          if (collageData.subtitle != null)
            Positioned(
              bottom: 40,
              left: 0,
              right: 0,
              child: AnimatedProp(
                startFrame: 120,
                duration: 25,
                animation: PropAnimation.slideUpFade(distance: 15),
                child: Text(
                  collageData.subtitle!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18,
                    color: colors.textColor.withValues(alpha: 0.8),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildShuffleGrid(TemplateTheme colors) {
    return TimeConsumer(
      builder: (context, frame, _) {
        final totalCells = gridSize * gridSize;
        final imageCount = collageData.count;

        // Entry phase: 0-30
        // Shuffle phase: 30-90
        // Settle phase: 90+

        const shuffleStart = 30;
        final settleStart = shuffleStart + shuffleDuration;

        return LayoutBuilder(
          builder: (context, constraints) {
            final gridWidth = constraints.maxWidth;
            final gridHeight = constraints.maxHeight;
            final cellWidth = (gridWidth - (gridSize - 1) * cellGap) / gridSize;
            final cellHeight =
                (gridHeight - (gridSize - 1) * cellGap) / gridSize;

            // Generate shuffle positions for each cell
            final positions = <int, Offset>{};
            final targetPositions = <int, Offset>{};

            for (var i = 0; i < totalCells; i++) {
              final row = i ~/ gridSize;
              final col = i % gridSize;
              final targetX = col * (cellWidth + cellGap);
              final targetY = row * (cellHeight + cellGap);
              targetPositions[i] = Offset(targetX, targetY);
            }

            // Calculate current positions based on animation phase
            if (frame < shuffleStart) {
              // Entry: cells come from outside
              for (var i = 0; i < totalCells; i++) {
                final entryProgress = ((frame - 10 - i * 2) / 20).clamp(
                  0.0,
                  1.0,
                );
                final eased = Curves.easeOutBack.transform(entryProgress);
                final target = targetPositions[i]!;
                final startY = gridHeight + 100;
                positions[i] = Offset(
                  target.dx,
                  target.dy + (startY - target.dy) * (1 - eased),
                );
              }
            } else if (frame < settleStart) {
              // Shuffle: cells move to random positions
              final shuffleProgress = (frame - shuffleStart) / shuffleDuration;
              final shuffleIntensity = math.sin(
                shuffleProgress * math.pi,
              ); // Peak in middle

              for (var i = 0; i < totalCells; i++) {
                final target = targetPositions[i]!;

                // Generate shuffle offset
                final shuffleSeed = seed + (frame ~/ 4) + i;
                final shuffleRandom = math.Random(shuffleSeed);
                final swapWith = shuffleRandom.nextInt(totalCells);
                final swapTarget = targetPositions[swapWith]!;

                // Interpolate between positions
                final shuffleAmount = shuffleIntensity * 0.8;
                positions[i] = Offset(
                  target.dx + (swapTarget.dx - target.dx) * shuffleAmount,
                  target.dy + (swapTarget.dy - target.dy) * shuffleAmount,
                );
              }
            } else {
              // Settle: cells move to final positions
              final settleProgress = ((frame - settleStart) / 30).clamp(
                0.0,
                1.0,
              );
              final eased = Curves.easeOutCubic.transform(settleProgress);

              // Get last shuffle positions
              final lastShuffleFrame = settleStart - 1;
              final lastRandom = math.Random(seed + (lastShuffleFrame ~/ 4));

              for (var i = 0; i < totalCells; i++) {
                final target = targetPositions[i]!;
                final lastShuffle = lastRandom.nextInt(totalCells);
                final shufflePos = targetPositions[lastShuffle]!;

                positions[i] = Offset(
                  shufflePos.dx + (target.dx - shufflePos.dx) * eased,
                  shufflePos.dy + (target.dy - shufflePos.dy) * eased,
                );
              }
            }

            return Stack(
              clipBehavior: Clip.none,
              children: List.generate(totalCells, (index) {
                final position = positions[index] ?? targetPositions[index]!;
                final hasImage = index < imageCount;

                return Positioned(
                  left: position.dx,
                  top: position.dy,
                  child: _buildCell(
                    context,
                    index,
                    hasImage,
                    cellWidth,
                    cellHeight,
                    colors,
                  ),
                );
              }),
            );
          },
        );
      },
    );
  }

  Widget _buildCell(
    BuildContext context,
    int index,
    bool hasImage,
    double width,
    double height,
    TemplateTheme colors,
  ) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: _getPlaceholderColor(index, colors),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: hasImage
            ? SizedBox(
                width: width,
                height: height,
                child: collageData.buildImage(context, index),
              )
            : _buildPlaceholder(index, colors),
      ),
    );
  }

  Widget _buildPlaceholder(int index, TemplateTheme colors) {
    return Container(
      color: _getPlaceholderColor(index, colors),
      child: Center(
        child: Icon(
          Icons.music_note,
          size: 40,
          color: colors.textColor.withValues(alpha: 0.5),
        ),
      ),
    );
  }

  Color _getPlaceholderColor(int index, TemplateTheme colors) {
    final placeholderColors = [
      colors.primaryColor,
      colors.secondaryColor,
      colors.accentColor,
      colors.primaryColor.withValues(alpha: 0.7),
      colors.secondaryColor.withValues(alpha: 0.7),
      colors.accentColor.withValues(alpha: 0.7),
    ];
    return placeholderColors[index % placeholderColors.length];
  }
}
