import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../presentation/time_consumer.dart';
import '../../presentation/video_composition.dart';
import '../../declarative/animations/core/animated_prop.dart';
import '../../declarative/animations/core/prop_animation.dart';
import '../../declarative/effects/particle_effect.dart';
import '../_base/template_base.dart';
import '../_base/template_config.dart';
import '../_base/template_data.dart';

/// Photos drift around, with #1 scaling up dramatically at the end.
///
/// Creates a nostalgic polaroid photo effect where images float and drift
/// around the screen with gentle rotations. At the climax, all photos
/// fade away except the winner, which scales up to fill the screen.
///
/// Best used for:
/// - Photo memories
/// - Artist/album rankings
/// - Personal highlights
///
/// Example:
/// ```dart
/// FloatingPolaroids(
///   data: RankingData(
///     title: 'Your Year in Photos',
///     items: [
///       RankingItem(rank: 1, label: 'Summer Trip', imagePath: 'summer.jpg'),
///       RankingItem(rank: 2, label: 'Concert Night', imagePath: 'concert.jpg'),
///       // ...
///     ],
///   ),
///   theme: TemplateTheme.pastel,
/// )
/// ```
class FloatingPolaroids extends WrappedTemplate with TemplateAnimationMixin {
  /// Amount of floating movement.
  final double floatAmplitude;

  /// Speed of rotation drift.
  final double rotationSpeed;

  /// Whether to show light flare effects.
  final bool showFlares;

  /// Random seed for deterministic positioning.
  final int seed;

  const FloatingPolaroids({
    super.key,
    required RankingData super.data,
    super.theme,
    super.timing,
    this.floatAmplitude = 30,
    this.rotationSpeed = 0.3,
    this.showFlares = true,
    this.seed = 42,
  });

  @override
  int get recommendedLength => 210;

  @override
  TemplateCategory get category => TemplateCategory.ranking;

  @override
  String get description => 'Floating photos with #1 scaling up at the end';

  @override
  TemplateTheme get defaultTheme => TemplateTheme.pastel;

  RankingData get rankingData => data as RankingData;

  @override
  Widget build(BuildContext context) {
    final colors = effectiveTheme;
    final items = rankingData.sortedItems;
    final itemCount = math.min(items.length, 8);
    final random = math.Random(seed);

    return Container(
      color: colors.backgroundColor,
      child: Stack(
        children: [
          // Ambient light particles
          if (showFlares)
            Positioned.fill(
              child: ParticleEffect.sparkles(
                count: 15,
                color: colors.primaryColor.withValues(alpha: 0.3),
              ),
            ),

          // Title
          Positioned(top: 50, left: 0, right: 0, child: _buildTitle(colors)),

          // Floating polaroids
          Positioned.fill(
            child: _buildFloatingPolaroids(
              colors,
              items.take(itemCount).toList(),
              random,
            ),
          ),

          // Winner spotlight overlay
          Positioned.fill(child: _buildWinnerSpotlight(colors, items.first)),
        ],
      ),
    );
  }

  Widget _buildTitle(TemplateTheme colors) {
    return AnimatedProp(
      startFrame: 0,
      duration: 35,
      animation: PropAnimation.slideUpFade(distance: 20),
      child: Text(
        rankingData.title ?? 'Your Favorites',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 42,
          fontWeight: FontWeight.w700,
          color: colors.textColor,
          letterSpacing: 2,
        ),
      ),
    );
  }

  Widget _buildFloatingPolaroids(
    TemplateTheme colors,
    List<RankingItem> items,
    math.Random random,
  ) {
    return TimeConsumer(
      builder: (context, frame, _) {
        final composition = VideoComposition.of(context);
        final fps = composition?.fps ?? 30;
        final time = frame / fps;

        // Phase 1: Entry (frames 20-80)
        // Phase 2: Float (frames 80-150)
        // Phase 3: Winner reveal (frames 150+)
        final isRevealPhase = frame >= 150;
        final revealProgress = ((frame - 150) / 40).clamp(0.0, 1.0);

        return LayoutBuilder(
          builder: (context, constraints) {
            return Stack(
              clipBehavior: Clip.none,
              children: List.generate(items.length, (index) {
                final item = items[index];
                final isWinner = item.rank == 1;

                // Generate random starting position for each polaroid
                final baseX =
                    80 + random.nextDouble() * (constraints.maxWidth - 280);
                final baseY =
                    130 + random.nextDouble() * (constraints.maxHeight - 380);
                final baseRotation = (random.nextDouble() - 0.5) * 0.5;

                // Entry animation
                final entryStart = 20 + (index * 10);
                final entryProgress = calculateEntryProgress(
                  frame,
                  entryStart,
                  35,
                );
                final easedEntry = Curves.easeOutBack.transform(entryProgress);

                // Floating animation
                final floatPhase = index * 1.2;
                final floatX =
                    math.sin(time * 0.8 + floatPhase) * floatAmplitude;
                final floatY =
                    math.cos(time * 0.6 + floatPhase) * floatAmplitude * 0.7;
                final floatRotation =
                    math.sin(time * rotationSpeed + floatPhase) * 0.1;

                // Winner reveal transformation
                double x = baseX + floatX;
                double y = baseY + floatY;
                double rotation = baseRotation + floatRotation;
                double scale = 1.0;
                double opacity = 1.0;

                if (isRevealPhase) {
                  if (isWinner) {
                    // Winner moves to center and scales up
                    final centerX = constraints.maxWidth / 2 - 150;
                    final centerY = constraints.maxHeight / 2 - 180;
                    x = baseX +
                        (centerX - baseX) *
                            Curves.easeInOutCubic.transform(revealProgress);
                    y = baseY +
                        (centerY - baseY) *
                            Curves.easeInOutCubic.transform(revealProgress);
                    rotation = baseRotation * (1 - revealProgress);
                    scale = 1.0 +
                        (0.6 * Curves.easeOutCubic.transform(revealProgress));
                  } else {
                    // Others fade out and drift away
                    opacity =
                        1.0 - Curves.easeInCubic.transform(revealProgress);
                    final driftDirection = (index % 2 == 0) ? 1 : -1;
                    x += driftDirection * 100 * revealProgress;
                    y -= 50 * revealProgress;
                  }
                }

                return Positioned(
                  left: x,
                  top: y,
                  child: Transform.rotate(
                    angle: rotation,
                    child: Transform.scale(
                      scale: easedEntry * scale,
                      child: Opacity(
                        opacity: (easedEntry * opacity).clamp(0.0, 1.0),
                        child: _buildPolaroid(
                          item,
                          colors,
                          isWinner && isRevealPhase,
                          revealProgress,
                        ),
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

  Widget _buildPolaroid(
    RankingItem item,
    TemplateTheme colors,
    bool isHighlighted,
    double highlightProgress,
  ) {
    final polaroidWidth = 200.0;
    final polaroidHeight = 260.0;

    return Container(
      width: polaroidWidth,
      height: polaroidHeight,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4),
        boxShadow: [
          BoxShadow(
            color: isHighlighted
                ? colors.accentColor.withValues(alpha: 0.4)
                : Colors.black.withValues(alpha: 0.25),
            blurRadius: isHighlighted ? 40 : 20,
            offset: const Offset(0, 10),
            spreadRadius: isHighlighted ? 5 : 0,
          ),
        ],
      ),
      child: Column(
        children: [
          // Image area
          Expanded(
            child: Container(
              margin: const EdgeInsets.fromLTRB(12, 12, 12, 8),
              decoration: BoxDecoration(
                color: colors.secondaryColor,
                borderRadius: BorderRadius.circular(2),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: item.imagePath != null
                    ? Image.asset(
                        item.imagePath!,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        height: double.infinity,
                        errorBuilder: (_, __, ___) =>
                            _buildPlaceholderImage(colors, item.rank),
                      )
                    : _buildPlaceholderImage(colors, item.rank),
              ),
            ),
          ),

          // Label area (like polaroid caption)
          Container(
            height: 50,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                // Rank badge
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: item.rank == 1
                        ? colors.accentColor
                        : colors.primaryColor,
                  ),
                  child: Center(
                    child: Text(
                      '${item.rank}',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                // Caption
                Expanded(
                  child: Text(
                    item.label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[800],
                      fontFamily: 'serif',
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceholderImage(TemplateTheme colors, int rank) {
    return Container(
      color: colors.primaryColor.withValues(alpha: 0.2),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              rank == 1 ? Icons.star : Icons.photo,
              size: 50,
              color: colors.primaryColor.withValues(alpha: 0.6),
            ),
            if (rank == 1)
              Text(
                '#1',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: colors.primaryColor,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildWinnerSpotlight(TemplateTheme colors, RankingItem winner) {
    return TimeConsumer(
      builder: (context, frame, _) {
        // Only show after reveal starts
        if (frame < 180) {
          return const SizedBox.shrink();
        }

        final spotlightProgress = ((frame - 180) / 30).clamp(0.0, 1.0);

        return Opacity(
          opacity: spotlightProgress,
          child: Container(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.center,
                radius: 1.5,
                colors: [
                  Colors.transparent,
                  colors.backgroundColor.withValues(alpha: 0.0),
                  colors.backgroundColor.withValues(alpha: 0.5),
                ],
                stops: const [0.0, 0.4, 1.0],
              ),
            ),
          ),
        );
      },
    );
  }
}
