import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../presentation/time_consumer.dart';
import '../../declarative/animations/core/animated_prop.dart';
import '../../declarative/animations/core/prop_animation.dart';
import '../_base/template_base.dart';
import '../_base/template_config.dart';
import '../_base/template_data.dart';

/// Small thumbnails that form a larger artist image.
///
/// Creates a dramatic reveal where many small image tiles come together
/// to form a larger composite image. Individual tiles animate in and
/// the final image becomes clear as a whole.
///
/// Best used for:
/// - Artist reveals
/// - Photo mosaics
/// - Commemorative displays
///
/// Example:
/// ```dart
/// MosaicReveal(
///   data: CollageData(
///     title: 'Your #1 Artist',
///     images: ['main_artist.jpg'],
///     thumbnails: List.generate(100, (i) => 'thumb_$i.jpg'),
///   ),
/// )
/// ```
class MosaicReveal extends WrappedTemplate with TemplateAnimationMixin {
  /// Number of tiles in each row.
  final int tilesPerRow;

  /// Number of rows.
  final int rowCount;

  /// Random seed for tile order.
  final int seed;

  const MosaicReveal({
    super.key,
    required CollageData super.data,
    super.theme,
    super.timing,
    this.tilesPerRow = 12,
    this.rowCount = 16,
    this.seed = 42,
  });

  @override
  int get recommendedLength => 200;

  @override
  TemplateCategory get category => TemplateCategory.collage;

  @override
  String get description => 'Small thumbnails forming a larger image';

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
          // Mosaic tiles
          Positioned.fill(child: _buildMosaic(colors)),

          // Title overlay (appears after mosaic forms)
          Positioned(bottom: 80, left: 0, right: 0, child: _buildTitle(colors)),
        ],
      ),
    );
  }

  Widget _buildMosaic(TemplateTheme colors) {
    return TimeConsumer(
      builder: (context, frame, _) {
        final totalTiles = tilesPerRow * rowCount;

        // Generate random order for tile appearance
        final tileOrder = List.generate(totalTiles, (i) => i);
        tileOrder.shuffle(math.Random(seed));

        return LayoutBuilder(
          builder: (context, constraints) {
            final tileWidth = constraints.maxWidth / tilesPerRow;
            final tileHeight = constraints.maxHeight / rowCount;

            return Stack(
              children: [
                // Background main image (slightly visible at start)
                if (collageData.count > 0)
                  Positioned.fill(
                    child: Opacity(
                      opacity: 0.15,
                      child: collageData.buildImage(context, 0),
                    ),
                  ),

                // Mosaic tiles
                ...List.generate(totalTiles, (index) {
                  final row = index ~/ tilesPerRow;
                  final col = index % tilesPerRow;
                  final x = col * tileWidth;
                  final y = row * tileHeight;

                  // Calculate when this tile appears based on its order
                  final orderIndex = tileOrder.indexOf(index);
                  final tileStart = 20 + (orderIndex * 0.8);
                  final tileProgress = ((frame - tileStart) / 15).clamp(
                    0.0,
                    1.0,
                  );

                  if (tileProgress <= 0) {
                    return const SizedBox.shrink();
                  }

                  return Positioned(
                    left: x,
                    top: y,
                    child: _buildTile(
                      context,
                      index,
                      tileWidth,
                      tileHeight,
                      tileProgress,
                      colors,
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

  Widget _buildTile(
    BuildContext context,
    int index,
    double width,
    double height,
    double progress,
    TemplateTheme colors,
  ) {
    final scale = Curves.easeOutBack.transform(progress);
    final opacity = progress;

    // Each tile shows a piece of the main image OR a thumbnail
    final row = index ~/ tilesPerRow;
    final col = index % tilesPerRow;

    // Color for placeholder/color mode
    final hue = (index * 15) % 360;
    final tileColor = HSLColor.fromAHSL(
      1.0,
      hue.toDouble(),
      0.6,
      0.5,
    ).toColor();

    return Transform.scale(
      scale: scale,
      child: Opacity(
        opacity: opacity,
        child: Container(
          width: width - 1,
          height: height - 1,
          decoration: BoxDecoration(
            color: tileColor,
            borderRadius: BorderRadius.circular(2),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: collageData.count > 0
                ? _buildImageTile(
                    context,
                    row,
                    col,
                    width,
                    height,
                  )
                : null,
          ),
        ),
      ),
    );
  }

  Widget _buildImageTile(
    BuildContext context,
    int row,
    int col,
    double tileWidth,
    double tileHeight,
  ) {
    // Use FittedBox and Align to show only the relevant portion of the image
    return OverflowBox(
      maxWidth: tileWidth * tilesPerRow,
      maxHeight: tileHeight * rowCount,
      alignment: Alignment(
        -1 + (col * 2 / (tilesPerRow - 1)),
        -1 + (row * 2 / (rowCount - 1)),
      ),
      child: SizedBox(
        width: tileWidth * tilesPerRow,
        height: tileHeight * rowCount,
        child: collageData.buildImage(context, 0),
      ),
    );
  }

  Widget _buildTitle(TemplateTheme colors) {
    return AnimatedProp(
      startFrame: 150,
      duration: 35,
      animation: PropAnimation.combine([
        const PropAnimation.scale(start: 0.9, end: 1.0),
        PropAnimation.fadeIn(),
      ]),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 40),
        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
        decoration: BoxDecoration(
          color: colors.backgroundColor.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(20),
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
            if (collageData.title != null)
              Text(
                collageData.title!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w500,
                  color: colors.textColor.withValues(alpha: 0.8),
                  letterSpacing: 2,
                ),
              ),
            if (collageData.subtitle != null) ...[
              const SizedBox(height: 8),
              Text(
                collageData.subtitle!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.w900,
                  color: colors.textColor,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
