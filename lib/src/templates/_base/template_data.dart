import 'package:flutter/widgets.dart';
import '../../declarative/helpers/media_types.dart';

/// Base data contract for all templates.
///
/// Template data classes define the content that will be displayed
/// in each template type. They are immutable and can be serialized.
abstract class TemplateData {
  const TemplateData();
}

/// Data for intro/identity templates.
///
/// Used by templates like TheNeonGate, DigitalMirror, TheMixtape, etc.
///
/// You can provide images either via asset paths (legacy) or via builders
/// (recommended). Builders allow maximum flexibility for network images,
/// SVGs, or custom widgets.
///
/// Example with builders (recommended):
/// ```dart
/// IntroData(
///   title: 'Your 2024',
///   logoBuilder: (ctx) => Image.network('https://example.com/logo.png'),
///   profileImageBuilder: (ctx) => Image.network('https://example.com/profile.jpg'),
/// )
/// ```
class IntroData extends TemplateData {
  /// Main title text (e.g., "Your 2024").
  final String title;

  /// Optional subtitle text.
  final String? subtitle;

  /// Path to logo asset.
  ///
  /// Deprecated: Use [logoBuilder] instead for more flexibility.
  @Deprecated('Use logoBuilder instead for network images, SVGs, etc.')
  final String? logoPath;

  /// Builder for the logo widget.
  ///
  /// This allows maximum flexibility - use [Image.asset], [Image.network],
  /// SVGs, or any custom widget.
  final MediaBuilder? logoBuilder;

  /// Year to display.
  final int? year;

  /// User's name for personalization.
  final String? userName;

  /// User's profile image path.
  ///
  /// Deprecated: Use [profileImageBuilder] instead for more flexibility.
  @Deprecated('Use profileImageBuilder instead for network images, SVGs, etc.')
  final String? profileImagePath;

  /// Builder for the profile image widget.
  ///
  /// This allows maximum flexibility - use [Image.asset], [Image.network],
  /// SVGs, or any custom widget.
  final MediaBuilder? profileImageBuilder;

  const IntroData({
    required this.title,
    this.subtitle,
    @Deprecated('Use logoBuilder instead') this.logoPath,
    this.logoBuilder,
    this.year,
    this.userName,
    @Deprecated('Use profileImageBuilder instead') this.profileImagePath,
    this.profileImageBuilder,
  });

  /// Builds the logo widget.
  ///
  /// Returns the widget from [logoBuilder] if provided, otherwise creates
  /// an [Image.asset] from [logoPath], or null if neither is provided.
  Widget? buildLogo(BuildContext context) {
    if (logoBuilder != null) return logoBuilder!(context);
    if (logoPath != null) {
      return Image.asset(
        logoPath!,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => const SizedBox.shrink(),
      );
    }
    return null;
  }

  /// Builds the profile image widget.
  ///
  /// Returns the widget from [profileImageBuilder] if provided, otherwise
  /// creates an [Image.asset] from [profileImagePath], or null if neither
  /// is provided.
  Widget? buildProfileImage(BuildContext context) {
    if (profileImageBuilder != null) return profileImageBuilder!(context);
    if (profileImagePath != null) {
      return Image.asset(
        profileImagePath!,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => const SizedBox.shrink(),
      );
    }
    return null;
  }
}

/// A single item in a ranking list.
///
/// You can provide images either via asset paths (legacy) or via builders
/// (recommended). Builders allow maximum flexibility for network images,
/// SVGs, or custom widgets.
class RankingItem {
  /// The rank number (1 = first place).
  final int rank;

  /// Display label for this item.
  final String label;

  /// Optional subtitle text.
  final String? subtitle;

  /// Optional numeric or string value.
  final dynamic value;

  /// Path to image asset for this item.
  ///
  /// Deprecated: Use [imageBuilder] instead for more flexibility.
  @Deprecated('Use imageBuilder instead for network images, SVGs, etc.')
  final String? imagePath;

  /// Builder for the image widget.
  ///
  /// This allows maximum flexibility - use [Image.asset], [Image.network],
  /// SVGs, or any custom widget.
  final MediaBuilder? imageBuilder;

  /// Additional metadata (e.g., play count, duration).
  final Map<String, dynamic>? metadata;

  const RankingItem({
    required this.rank,
    required this.label,
    this.subtitle,
    this.value,
    @Deprecated('Use imageBuilder instead') this.imagePath,
    this.imageBuilder,
    this.metadata,
  });

  /// Builds the image widget.
  ///
  /// Returns the widget from [imageBuilder] if provided, otherwise creates
  /// an [Image.asset] from [imagePath], or null if neither is provided.
  Widget? buildImage(BuildContext context) {
    if (imageBuilder != null) return imageBuilder!(context);
    if (imagePath != null) {
      return Image.asset(
        imagePath!,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => const SizedBox.shrink(),
      );
    }
    return null;
  }

  /// Creates a copy with updated fields.
  RankingItem copyWith({
    int? rank,
    String? label,
    String? subtitle,
    dynamic value,
    String? imagePath,
    MediaBuilder? imageBuilder,
    Map<String, dynamic>? metadata,
  }) {
    return RankingItem(
      rank: rank ?? this.rank,
      label: label ?? this.label,
      subtitle: subtitle ?? this.subtitle,
      value: value ?? this.value,
      imagePath: imagePath ?? this.imagePath,
      imageBuilder: imageBuilder ?? this.imageBuilder,
      metadata: metadata ?? this.metadata,
    );
  }
}

/// Data for ranking/list templates.
///
/// Used by templates like StackClimb, SlotMachine, TheSpotlight, etc.
class RankingData extends TemplateData {
  /// The list of ranked items (must have at least 1 item).
  final List<RankingItem> items;

  /// Optional title for the ranking.
  final String? title;

  /// Optional subtitle.
  final String? subtitle;

  /// Whether this is a "Top N" style ranking.
  final bool isTopList;

  const RankingData({
    required this.items,
    this.title,
    this.subtitle,
    this.isTopList = true,
  }) : assert(items.length > 0, 'RankingData must have at least 1 item');

  /// Returns items sorted by rank.
  List<RankingItem> get sortedItems =>
      [...items]..sort((a, b) => a.rank.compareTo(b.rank));

  /// Returns the top-ranked item.
  RankingItem get topItem => sortedItems.first;

  /// Returns the number of items.
  int get count => items.length;
}

/// A single metric for data visualization.
class MetricData {
  /// Label for this metric (e.g., "Minutes Listened").
  final String label;

  /// Numeric value.
  final num value;

  /// Optional unit (e.g., "minutes", "songs", "%").
  final String? unit;

  /// Optional icon to display.
  final IconData? icon;

  /// Trend direction (-1.0 = down, 0 = neutral, 1.0 = up).
  final double? trend;

  /// Optional color for this metric.
  final Color? color;

  /// Optional percentage of total (0.0 - 1.0).
  final double? percentage;

  const MetricData({
    required this.label,
    required this.value,
    this.unit,
    this.icon,
    this.trend,
    this.color,
    this.percentage,
  });

  /// Creates a percentage metric.
  factory MetricData.percentage({
    required String label,
    required double value,
    IconData? icon,
    Color? color,
  }) {
    return MetricData(
      label: label,
      value: value,
      unit: '%',
      icon: icon,
      color: color,
      percentage: value / 100,
    );
  }

  /// Creates a duration metric in minutes.
  factory MetricData.minutes({
    required String label,
    required int minutes,
    IconData? icon,
    Color? color,
  }) {
    return MetricData(
      label: label,
      value: minutes,
      unit: 'min',
      icon: icon,
      color: color,
    );
  }

  /// Creates a count metric.
  factory MetricData.count({
    required String label,
    required int count,
    String? unit,
    IconData? icon,
    Color? color,
  }) {
    return MetricData(
      label: label,
      value: count,
      unit: unit,
      icon: icon,
      color: color,
    );
  }
}

/// Data for data visualization templates.
///
/// Used by templates like TheGrowthTree, OrbitalMetrics, FrequencyGlow, etc.
class DataVizData extends TemplateData {
  /// List of metrics to visualize.
  final List<MetricData> metrics;

  /// Optional title.
  final String? title;

  /// Optional subtitle.
  final String? subtitle;

  /// Optional time series data (frame -> value).
  final Map<int, double>? timeSeries;

  /// Optional category breakdown.
  final Map<String, double>? categories;

  /// Maximum value for scaling (optional, calculated from metrics if not provided).
  final double? maxValue;

  const DataVizData({
    required this.metrics,
    this.title,
    this.subtitle,
    this.timeSeries,
    this.categories,
    this.maxValue,
  });

  /// Returns the total of all metric values.
  num get total => metrics.fold(0, (sum, m) => sum + m.value);

  /// Returns metrics sorted by value descending.
  List<MetricData> get sortedByValue =>
      [...metrics]..sort((a, b) => b.value.compareTo(a.value));

  /// Returns the effective max value (provided or calculated).
  double get effectiveMaxValue =>
      maxValue ??
      metrics.fold<double>(
        0,
        (max, m) => m.value > max ? m.value.toDouble() : max,
      );
}

/// Data for collage/grid templates.
///
/// Used by templates like TheGridShuffle, MosaicReveal, TriptychScroll, etc.
///
/// You can provide images either via asset paths (legacy) or via builders
/// (recommended). Builders allow maximum flexibility for network images,
/// SVGs, or custom widgets.
///
/// Example with builders (recommended):
/// ```dart
/// CollageData(
///   imageBuilders: [
///     (ctx) => Image.network('https://example.com/photo1.jpg', fit: BoxFit.cover),
///     (ctx) => Image.network('https://example.com/photo2.jpg', fit: BoxFit.cover),
///   ],
///   title: 'Your Year in Photos',
/// )
/// ```
class CollageData extends TemplateData {
  /// List of image asset paths.
  ///
  /// Deprecated: Use [imageBuilders] instead for more flexibility.
  @Deprecated('Use imageBuilders instead for network images, SVGs, etc.')
  final List<String> images;

  /// Builders for the image widgets.
  ///
  /// This allows maximum flexibility - use [Image.asset], [Image.network],
  /// SVGs, or any custom widget.
  final List<MediaBuilder>? imageBuilders;

  /// Optional title.
  final String? title;

  /// Optional subtitle.
  final String? subtitle;

  /// Optional description text.
  final String? description;

  /// Optional captions for each image.
  final List<String>? captions;

  /// Optional featured image index.
  final int? featuredIndex;

  /// Optional layout hint (grid size, arrangement).
  final TemplateCollageLayout layout;

  /// Optional statistics map.
  final Map<String, dynamic> stats;

  const CollageData({
    @Deprecated('Use imageBuilders instead') this.images = const [],
    this.imageBuilders,
    this.title,
    this.subtitle,
    this.description,
    this.captions,
    this.featuredIndex,
    this.layout = TemplateCollageLayout.grid,
    this.stats = const {},
  }) : assert(
          images.length > 0 ||
              (imageBuilders != null && imageBuilders.length > 0),
          'CollageData must have at least 1 image',
        );

  /// Number of images.
  int get count => imageBuilders?.length ?? images.length;

  /// Builds all image widgets.
  ///
  /// Returns widgets from [imageBuilders] if provided, otherwise creates
  /// [Image.asset] widgets from [images].
  List<Widget> buildImages(BuildContext context) {
    if (imageBuilders != null) {
      return imageBuilders!.map((b) => b(context)).toList();
    }
    return images
        .map(
          (path) => Image.asset(
            path,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => const SizedBox.shrink(),
          ),
        )
        .toList();
  }

  /// Builds the image widget at the given index.
  ///
  /// Returns the widget from [imageBuilders] if provided, otherwise creates
  /// an [Image.asset] from [images].
  Widget buildImage(BuildContext context, int index) {
    if (imageBuilders != null && index < imageBuilders!.length) {
      return imageBuilders![index](context);
    }
    if (index < images.length) {
      return Image.asset(
        images[index],
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => const SizedBox.shrink(),
      );
    }
    throw RangeError.index(index, this, 'image');
  }

  /// Returns the featured image path, or the first image if not specified.
  ///
  /// Note: This returns the path string. For the widget, use [buildFeaturedImage].
  @Deprecated('Use buildFeaturedImage instead')
  String get featuredImage => featuredIndex != null && images.isNotEmpty
      ? images[featuredIndex!]
      : images.isNotEmpty
          ? images.first
          : '';

  /// Builds the featured image widget.
  Widget? buildFeaturedImage(BuildContext context) {
    final index = featuredIndex ?? 0;
    if (imageBuilders != null && imageBuilders!.isNotEmpty) {
      return imageBuilders![index.clamp(0, imageBuilders!.length - 1)](context);
    }
    if (images.isNotEmpty) {
      return Image.asset(
        images[index.clamp(0, images.length - 1)],
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => const SizedBox.shrink(),
      );
    }
    return null;
  }
}

/// Layout hints for collage templates.
enum TemplateCollageLayout {
  /// Standard grid layout.
  grid,

  /// Masonry/Pinterest-style layout.
  masonry,

  /// Single featured image with smaller thumbnails.
  featured,

  /// Horizontal scrolling strip.
  strip,

  /// Diagonal arrangement.
  diagonal,
}

/// A single highlight or achievement.
///
/// You can provide images either via asset paths (legacy) or via builders
/// (recommended). Builders allow maximum flexibility for network images,
/// SVGs, or custom widgets.
class HighlightItem {
  /// Title of the highlight.
  final String title;

  /// Optional description.
  final String? description;

  /// Optional icon.
  final IconData? icon;

  /// Optional image path.
  ///
  /// Deprecated: Use [imageBuilder] instead for more flexibility.
  @Deprecated('Use imageBuilder instead for network images, SVGs, etc.')
  final String? imagePath;

  /// Builder for the image widget.
  ///
  /// This allows maximum flexibility - use [Image.asset], [Image.network],
  /// SVGs, or any custom widget.
  final MediaBuilder? imageBuilder;

  /// Optional value or statistic.
  final String? value;

  const HighlightItem({
    required this.title,
    this.description,
    this.icon,
    @Deprecated('Use imageBuilder instead') this.imagePath,
    this.imageBuilder,
    this.value,
  });

  /// Builds the image widget.
  ///
  /// Returns the widget from [imageBuilder] if provided, otherwise creates
  /// an [Image.asset] from [imagePath], or null if neither is provided.
  Widget? buildImage(BuildContext context) {
    if (imageBuilder != null) return imageBuilder!(context);
    if (imagePath != null) {
      return Image.asset(
        imagePath!,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => const SizedBox.shrink(),
      );
    }
    return null;
  }
}

/// Data for conclusion/summary templates.
///
/// Used by templates like TheSummaryPoster, WrappedReceipt, etc.
class SummaryData extends TemplateData {
  /// Main title text.
  final String? title;

  /// Optional subtitle text.
  final String? subtitle;

  /// User's name.
  final String? name;

  /// Key highlights to display.
  final List<HighlightItem>? highlights;

  /// Statistics map (e.g., {'Hours': '1,234', 'Songs': '5,678'}).
  final Map<String, dynamic> stats;

  /// Total statistics map (legacy, prefer stats).
  ///
  /// **Deprecated**: Use [stats] instead. This field will be removed in v1.0.0.
  @Deprecated('Use stats instead. Will be removed in v1.0.0')
  final Map<String, dynamic>? totalStats;

  /// Closing message.
  final String? message;

  /// Call-to-action text.
  final String? ctaText;

  /// Share URL or deep link.
  final String? shareUrl;

  /// QR code data (if applicable).
  final String? qrData;

  /// Year being summarized.
  final int? year;

  /// User's name (legacy, prefer name).
  ///
  /// **Deprecated**: Use [name] instead. This field will be removed in v1.0.0.
  @Deprecated('Use name instead. Will be removed in v1.0.0')
  final String? userName;

  const SummaryData({
    this.title,
    this.subtitle,
    this.name,
    this.highlights,
    this.stats = const {},
    this.totalStats,
    this.message,
    this.ctaText,
    this.shareUrl,
    this.qrData,
    this.year,
    this.userName,
  });
}

/// Data for thematic/vibe templates.
///
/// Used by templates like LofiWindow, GlitchReality, Kaleidoscope, etc.
///
/// You can provide images either via asset paths (legacy) or via builders
/// (recommended). Builders allow maximum flexibility for network images,
/// SVGs, or custom widgets.
class ThematicData extends TemplateData {
  /// Primary text content.
  final String text;

  /// Optional title text.
  final String? title;

  /// Optional subtitle text.
  final String? subtitle;

  /// Optional secondary text (alias for subtitle).
  final String? secondaryText;

  /// Optional description text.
  final String? description;

  /// List of image paths for visual elements.
  ///
  /// Deprecated: Use [imageBuilders] instead for more flexibility.
  @Deprecated('Use imageBuilders instead for network images, SVGs, etc.')
  final List<String>? images;

  /// Builders for the image widgets.
  ///
  /// This allows maximum flexibility - use [Image.asset], [Image.network],
  /// SVGs, or any custom widget.
  final List<MediaBuilder>? imageBuilders;

  /// Primary value to display.
  final String? value;

  /// Primary statistic or value to reveal (alias for value).
  final String? statValue;

  /// Label for the statistic.
  final String? statLabel;

  /// Theme/vibe name (e.g., "lofi", "retro", "glitch").
  final String? theme;

  /// Optional accent color override.
  final Color? accentColor;

  /// Optional metadata map.
  final Map<String, dynamic>? metadata;

  const ThematicData({
    required this.text,
    this.title,
    this.subtitle,
    this.secondaryText,
    this.description,
    @Deprecated('Use imageBuilders instead') this.images,
    this.imageBuilders,
    this.value,
    this.statValue,
    this.statLabel,
    this.theme,
    this.accentColor,
    this.metadata,
  });

  /// Builds all image widgets.
  ///
  /// Returns widgets from [imageBuilders] if provided, otherwise creates
  /// [Image.asset] widgets from [images], or null if neither is provided.
  List<Widget>? buildImages(BuildContext context) {
    if (imageBuilders != null) {
      return imageBuilders!.map((b) => b(context)).toList();
    }
    if (images != null) {
      return images!
          .map(
            (path) => Image.asset(
              path,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const SizedBox.shrink(),
            ),
          )
          .toList();
    }
    return null;
  }

  /// Builds the image widget at the given index.
  ///
  /// Returns the widget from [imageBuilders] or [images] at the given index,
  /// or null if no images are available or index is out of range.
  Widget? buildImage(BuildContext context, int index) {
    if (imageBuilders != null && index < imageBuilders!.length) {
      return imageBuilders![index](context);
    }
    if (images != null && index < images!.length) {
      return Image.asset(
        images![index],
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => const SizedBox.shrink(),
      );
    }
    return null;
  }
}
