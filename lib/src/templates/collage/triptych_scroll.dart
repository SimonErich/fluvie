import 'package:flutter/material.dart';

import '../../presentation/time_consumer.dart';
import '../../declarative/animations/core/animated_prop.dart';
import '../../declarative/animations/core/prop_animation.dart';
import '../_base/template_base.dart';
import '../_base/template_config.dart';
import '../_base/template_data.dart';

/// Three columns with parallax scrolling effect.
///
/// Creates a visually rich display with three columns of images that
/// scroll at different speeds, creating a parallax depth effect.
/// Ideal for showcasing many images in an engaging way.
///
/// Best used for:
/// - Photo galleries
/// - Album art showcases
/// - Memory reels
///
/// Example:
/// ```dart
/// TriptychScroll(
///   data: CollageData(
///     title: 'Your Year',
///     images: ['img1.jpg', 'img2.jpg', ...], // Many images
///   ),
/// )
/// ```
class TriptychScroll extends WrappedTemplate with TemplateAnimationMixin {
  /// Number of columns.
  final int columnCount;

  /// Scroll speed multiplier.
  final double scrollSpeed;

  /// Whether to show title overlay.
  final bool showTitle;

  /// Gap between images.
  final double imageGap;

  const TriptychScroll({
    super.key,
    required CollageData super.data,
    super.theme,
    super.timing,
    this.columnCount = 3,
    this.scrollSpeed = 1.0,
    this.showTitle = true,
    this.imageGap = 8,
  });

  @override
  int get recommendedLength => 200;

  @override
  TemplateCategory get category => TemplateCategory.collage;

  @override
  String get description => 'Three columns with parallax scrolling';

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
          // Parallax columns
          Positioned.fill(child: _buildParallaxColumns(colors)),

          // Gradient overlays
          Positioned.fill(child: _buildGradientOverlay(colors)),

          // Title overlay
          if (showTitle)
            Positioned.fill(child: Center(child: _buildTitleOverlay(colors))),
        ],
      ),
    );
  }

  Widget _buildParallaxColumns(TemplateTheme colors) {
    return TimeConsumer(
      builder: (context, frame, _) {
        return LayoutBuilder(
          builder: (context, constraints) {
            final columnWidth =
                (constraints.maxWidth - (columnCount - 1) * imageGap) /
                    columnCount;
            final imageHeight = columnWidth * 1.5; // 2:3 aspect ratio

            return Row(
              children: List.generate(columnCount, (colIndex) {
                // Different speeds for parallax effect
                final speedMultiplier = [1.0, 0.7, 1.3][colIndex % 3];
                final direction = colIndex.isEven ? 1 : -1;

                // Calculate scroll offset
                final baseSpeed = scrollSpeed * speedMultiplier * direction;
                final scrollOffset =
                    (frame * baseSpeed * 2) % (imageHeight * 2 + imageGap);

                return Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(
                      left: colIndex == 0 ? 0 : imageGap / 2,
                      right: colIndex == columnCount - 1 ? 0 : imageGap / 2,
                    ),
                    child: _buildColumn(
                      colIndex,
                      columnWidth,
                      imageHeight,
                      scrollOffset,
                      constraints.maxHeight,
                      colors,
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

  Widget _buildColumn(
    int columnIndex,
    double imageWidth,
    double imageHeight,
    double scrollOffset,
    double viewportHeight,
    TemplateTheme colors,
  ) {
    final images = collageData.images;
    final imagesPerColumn =
        (viewportHeight / (imageHeight + imageGap)).ceil() + 2;

    // Distribute images across columns
    final columnImages = <String>[];
    for (var i = columnIndex; i < images.length; i += columnCount) {
      columnImages.add(images[i]);
    }

    if (columnImages.isEmpty) {
      // Use placeholder colors if no images
      columnImages.addAll(List.generate(imagesPerColumn, (i) => ''));
    }

    return ClipRect(
      child: Transform.translate(
        offset: Offset(0, scrollOffset),
        child: Column(
          children: List.generate(imagesPerColumn * 2, (index) {
            final imageIndex = index % columnImages.length;
            final imagePath = columnImages[imageIndex];

            return Padding(
              padding: EdgeInsets.only(bottom: imageGap),
              child: Container(
                width: imageWidth,
                height: imageHeight,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: _getPlaceholderColor(columnIndex, index, colors),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: imagePath.isNotEmpty
                      ? Image.asset(
                          imagePath,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              _buildPlaceholder(columnIndex, index, colors),
                        )
                      : _buildPlaceholder(columnIndex, index, colors),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }

  Widget _buildPlaceholder(int colIndex, int rowIndex, TemplateTheme colors) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _getPlaceholderColor(colIndex, rowIndex, colors),
            _getPlaceholderColor(
              colIndex,
              rowIndex + 1,
              colors,
            ).withValues(alpha: 0.8),
          ],
        ),
      ),
      child: Center(
        child: Icon(
          Icons.music_note,
          size: 32,
          color: colors.textColor.withValues(alpha: 0.3),
        ),
      ),
    );
  }

  Color _getPlaceholderColor(int colIndex, int rowIndex, TemplateTheme colors) {
    final colorIndex = (colIndex * 3 + rowIndex) % 6;
    final placeholderColors = [
      colors.primaryColor,
      colors.secondaryColor,
      colors.accentColor,
      colors.primaryColor.withValues(alpha: 0.7),
      colors.secondaryColor.withValues(alpha: 0.7),
      colors.accentColor.withValues(alpha: 0.7),
    ];
    return placeholderColors[colorIndex];
  }

  Widget _buildGradientOverlay(TemplateTheme colors) {
    return Column(
      children: [
        // Top gradient
        Container(
          height: 150,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                colors.backgroundColor,
                colors.backgroundColor.withValues(alpha: 0.0),
              ],
            ),
          ),
        ),
        const Spacer(),
        // Bottom gradient
        Container(
          height: 150,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
              colors: [
                colors.backgroundColor,
                colors.backgroundColor.withValues(alpha: 0.0),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTitleOverlay(TemplateTheme colors) {
    return AnimatedProp(
      startFrame: 30,
      duration: 40,
      animation: PropAnimation.combine([
        const PropAnimation.scale(start: 0.9, end: 1.0),
        PropAnimation.fadeIn(),
      ]),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 30),
        decoration: BoxDecoration(
          color: colors.backgroundColor.withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 30,
              spreadRadius: 10,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              collageData.title ?? 'Your Gallery',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 48,
                fontWeight: FontWeight.w900,
                color: colors.textColor,
              ),
            ),
            if (collageData.subtitle != null) ...[
              const SizedBox(height: 12),
              Text(
                collageData.subtitle!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 20,
                  color: colors.textColor.withValues(alpha: 0.8),
                ),
              ),
            ],
            if (collageData.description != null) ...[
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: colors.primaryColor,
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Text(
                  collageData.description!,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: colors.backgroundColor,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
