import 'package:flutter/material.dart';

import '../../presentation/time_consumer.dart';
import '../_base/template_base.dart';
import '../_base/template_config.dart';
import '../_base/template_data.dart';

/// Bento box style layout with varied rectangle sizes.
///
/// Creates a modern, Apple-inspired bento box layout where different
/// sized rectangles contain various content types - images, stats,
/// text, and icons. Each cell animates in with staggered timing.
///
/// Best used for:
/// - Year recaps
/// - Feature highlights
/// - Stats overview
///
/// Example:
/// ```dart
/// BentoRecap(
///   data: CollageData(
///     title: 'Your 2024',
///     images: ['highlight1.jpg', 'highlight2.jpg'],
///     stats: {'Hours': '1,234', 'Songs': '5,678'},
///   ),
/// )
/// ```
class BentoRecap extends WrappedTemplate with TemplateAnimationMixin {
  /// Layout style for the bento grid.
  final BentoLayout layout;

  /// Gap between cells.
  final double cellGap;

  /// Random seed for color variations.
  final int seed;

  const BentoRecap({
    super.key,
    required CollageData super.data,
    super.theme,
    super.timing,
    this.layout = BentoLayout.balanced,
    this.cellGap = 12,
    this.seed = 42,
  });

  @override
  int get recommendedLength => 180;

  @override
  TemplateCategory get category => TemplateCategory.collage;

  @override
  String get description => 'Bento box style layout with varied sizes';

  @override
  TemplateTheme get defaultTheme => TemplateTheme.minimal;

  CollageData get collageData => data as CollageData;

  @override
  Widget build(BuildContext context) {
    final colors = effectiveTheme;

    return Container(
      color: colors.backgroundColor,
      padding: const EdgeInsets.all(24),
      child: _buildBentoGrid(colors),
    );
  }

  Widget _buildBentoGrid(TemplateTheme colors) {
    return TimeConsumer(
      builder: (context, frame, _) {
        return LayoutBuilder(
          builder: (context, constraints) {
            final cells = _getBentoLayout(layout);
            final gridWidth = constraints.maxWidth;
            final gridHeight = constraints.maxHeight;

            return Stack(
              children: cells.asMap().entries.map((entry) {
                final index = entry.key;
                final cell = entry.value;

                // Calculate position and size
                final x = cell.x * gridWidth;
                final y = cell.y * gridHeight;
                final width = cell.width * gridWidth - cellGap;
                final height = cell.height * gridHeight - cellGap;

                // Entry animation
                final entryStart = 20 + (index * 8);
                final entryProgress = ((frame - entryStart) / 35).clamp(
                  0.0,
                  1.0,
                );

                return Positioned(
                  left: x,
                  top: y,
                  child: _buildCell(
                    index,
                    cell,
                    width,
                    height,
                    entryProgress,
                    colors,
                  ),
                );
              }).toList(),
            );
          },
        );
      },
    );
  }

  Widget _buildCell(
    int index,
    BentoCell cell,
    double width,
    double height,
    double progress,
    TemplateTheme colors,
  ) {
    final scale = Curves.easeOutBack.transform(progress);
    final opacity = progress;

    return Transform.scale(
      scale: scale,
      child: Opacity(
        opacity: opacity,
        child: Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: _getCellColor(index, cell.type, colors),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: _buildCellContent(index, cell, colors),
          ),
        ),
      ),
    );
  }

  Widget _buildCellContent(int index, BentoCell cell, TemplateTheme colors) {
    switch (cell.type) {
      case BentoCellType.hero:
        return _buildHeroCell(colors);
      case BentoCellType.image:
        return _buildImageCell(index, colors);
      case BentoCellType.stat:
        return _buildStatCell(index, colors);
      case BentoCellType.icon:
        return _buildIconCell(index, colors);
      case BentoCellType.text:
        return _buildTextCell(colors);
    }
  }

  Widget _buildHeroCell(TemplateTheme colors) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [colors.primaryColor, colors.secondaryColor],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          if (collageData.title != null)
            Text(
              collageData.title!,
              style: TextStyle(
                fontSize: 42,
                fontWeight: FontWeight.w900,
                color: colors.textColor,
                height: 1.1,
              ),
            ),
          if (collageData.subtitle != null) ...[
            const SizedBox(height: 8),
            Text(
              collageData.subtitle!,
              style: TextStyle(
                fontSize: 18,
                color: colors.textColor.withValues(alpha: 0.8),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildImageCell(int index, TemplateTheme colors) {
    final imageIndex = index % (collageData.images.length.clamp(1, 10));
    final imagePath =
        collageData.images.isNotEmpty ? collageData.images[imageIndex] : null;

    if (imagePath != null) {
      return Image.asset(
        imagePath,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _buildPlaceholder(index, colors),
      );
    }

    return _buildPlaceholder(index, colors);
  }

  Widget _buildStatCell(int index, TemplateTheme colors) {
    // Get stats from collageData or generate placeholders
    final stats = collageData.stats;
    final statKeys = stats.keys.toList();

    if (statKeys.isEmpty) {
      return _buildPlaceholderStat(index, colors);
    }

    final statIndex = index % statKeys.length;
    final key = statKeys[statIndex];
    final value = stats[key] ?? '0';

    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.w900,
              color: colors.textColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            key,
            style: TextStyle(
              fontSize: 14,
              color: colors.textColor.withValues(alpha: 0.7),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceholderStat(int index, TemplateTheme colors) {
    final labels = ['Hours', 'Songs', 'Artists', 'Genres'];
    final values = ['1,234', '5,678', '892', '45'];

    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            values[index % values.length],
            style: TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.w900,
              color: colors.textColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            labels[index % labels.length],
            style: TextStyle(
              fontSize: 14,
              color: colors.textColor.withValues(alpha: 0.7),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIconCell(int index, TemplateTheme colors) {
    final icons = [
      Icons.music_note,
      Icons.favorite,
      Icons.headphones,
      Icons.star,
      Icons.album,
      Icons.queue_music,
    ];

    return Center(
      child: Icon(
        icons[index % icons.length],
        size: 48,
        color: colors.textColor.withValues(alpha: 0.9),
      ),
    );
  }

  Widget _buildTextCell(TemplateTheme colors) {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Center(
        child: Text(
          collageData.description ?? 'Your music journey',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: colors.textColor,
            height: 1.4,
          ),
        ),
      ),
    );
  }

  Widget _buildPlaceholder(int index, TemplateTheme colors) {
    return Container(
      color: _getCellColor(index, BentoCellType.image, colors),
      child: Center(
        child: Icon(
          Icons.image,
          size: 32,
          color: colors.textColor.withValues(alpha: 0.3),
        ),
      ),
    );
  }

  Color _getCellColor(int index, BentoCellType type, TemplateTheme colors) {
    switch (type) {
      case BentoCellType.hero:
        return colors.primaryColor;
      case BentoCellType.image:
        return colors.secondaryColor.withValues(alpha: 0.3);
      case BentoCellType.stat:
        final statColors = [
          colors.accentColor.withValues(alpha: 0.2),
          colors.primaryColor.withValues(alpha: 0.2),
          colors.secondaryColor.withValues(alpha: 0.2),
        ];
        return statColors[index % statColors.length];
      case BentoCellType.icon:
        return colors.primaryColor.withValues(alpha: 0.15);
      case BentoCellType.text:
        return colors.secondaryColor.withValues(alpha: 0.15);
    }
  }

  List<BentoCell> _getBentoLayout(BentoLayout layout) {
    switch (layout) {
      case BentoLayout.balanced:
        return [
          // Row 1
          BentoCell(
            x: 0,
            y: 0,
            width: 0.6,
            height: 0.5,
            type: BentoCellType.hero,
          ),
          BentoCell(
            x: 0.6,
            y: 0,
            width: 0.4,
            height: 0.25,
            type: BentoCellType.stat,
          ),
          BentoCell(
            x: 0.6,
            y: 0.25,
            width: 0.4,
            height: 0.25,
            type: BentoCellType.image,
          ),
          // Row 2
          BentoCell(
            x: 0,
            y: 0.5,
            width: 0.33,
            height: 0.25,
            type: BentoCellType.stat,
          ),
          BentoCell(
            x: 0.33,
            y: 0.5,
            width: 0.33,
            height: 0.25,
            type: BentoCellType.icon,
          ),
          BentoCell(
            x: 0.66,
            y: 0.5,
            width: 0.34,
            height: 0.25,
            type: BentoCellType.stat,
          ),
          // Row 3
          BentoCell(
            x: 0,
            y: 0.75,
            width: 0.5,
            height: 0.25,
            type: BentoCellType.image,
          ),
          BentoCell(
            x: 0.5,
            y: 0.75,
            width: 0.5,
            height: 0.25,
            type: BentoCellType.text,
          ),
        ];
      case BentoLayout.heroFocused:
        return [
          BentoCell(
            x: 0,
            y: 0,
            width: 0.7,
            height: 0.6,
            type: BentoCellType.hero,
          ),
          BentoCell(
            x: 0.7,
            y: 0,
            width: 0.3,
            height: 0.3,
            type: BentoCellType.stat,
          ),
          BentoCell(
            x: 0.7,
            y: 0.3,
            width: 0.3,
            height: 0.3,
            type: BentoCellType.stat,
          ),
          BentoCell(
            x: 0,
            y: 0.6,
            width: 0.35,
            height: 0.4,
            type: BentoCellType.image,
          ),
          BentoCell(
            x: 0.35,
            y: 0.6,
            width: 0.35,
            height: 0.4,
            type: BentoCellType.stat,
          ),
          BentoCell(
            x: 0.7,
            y: 0.6,
            width: 0.3,
            height: 0.4,
            type: BentoCellType.icon,
          ),
        ];
      case BentoLayout.gridFocused:
        return [
          BentoCell(
            x: 0,
            y: 0,
            width: 0.5,
            height: 0.33,
            type: BentoCellType.hero,
          ),
          BentoCell(
            x: 0.5,
            y: 0,
            width: 0.25,
            height: 0.33,
            type: BentoCellType.stat,
          ),
          BentoCell(
            x: 0.75,
            y: 0,
            width: 0.25,
            height: 0.33,
            type: BentoCellType.stat,
          ),
          BentoCell(
            x: 0,
            y: 0.33,
            width: 0.33,
            height: 0.34,
            type: BentoCellType.image,
          ),
          BentoCell(
            x: 0.33,
            y: 0.33,
            width: 0.34,
            height: 0.34,
            type: BentoCellType.image,
          ),
          BentoCell(
            x: 0.67,
            y: 0.33,
            width: 0.33,
            height: 0.34,
            type: BentoCellType.image,
          ),
          BentoCell(
            x: 0,
            y: 0.67,
            width: 0.5,
            height: 0.33,
            type: BentoCellType.text,
          ),
          BentoCell(
            x: 0.5,
            y: 0.67,
            width: 0.5,
            height: 0.33,
            type: BentoCellType.stat,
          ),
        ];
    }
  }
}

/// Layout style options for the bento grid.
enum BentoLayout { balanced, heroFocused, gridFocused }

/// Cell type in the bento grid.
enum BentoCellType { hero, image, stat, icon, text }

/// Represents a cell in the bento grid.
class BentoCell {
  final double x;
  final double y;
  final double width;
  final double height;
  final BentoCellType type;

  const BentoCell({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    required this.type,
  });
}
