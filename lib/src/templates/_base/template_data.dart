import 'package:flutter/widgets.dart';

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
class IntroData extends TemplateData {
  /// Main title text (e.g., "Your 2024").
  final String title;

  /// Optional subtitle text.
  final String? subtitle;

  /// Path to logo asset.
  final String? logoPath;

  /// Year to display.
  final int? year;

  /// User's name for personalization.
  final String? userName;

  /// User's profile image path.
  final String? profileImagePath;

  const IntroData({
    required this.title,
    this.subtitle,
    this.logoPath,
    this.year,
    this.userName,
    this.profileImagePath,
  });
}

/// A single item in a ranking list.
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
  final String? imagePath;

  /// Additional metadata (e.g., play count, duration).
  final Map<String, dynamic>? metadata;

  const RankingItem({
    required this.rank,
    required this.label,
    this.subtitle,
    this.value,
    this.imagePath,
    this.metadata,
  });

  /// Creates a copy with updated fields.
  RankingItem copyWith({
    int? rank,
    String? label,
    String? subtitle,
    dynamic value,
    String? imagePath,
    Map<String, dynamic>? metadata,
  }) {
    return RankingItem(
      rank: rank ?? this.rank,
      label: label ?? this.label,
      subtitle: subtitle ?? this.subtitle,
      value: value ?? this.value,
      imagePath: imagePath ?? this.imagePath,
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
class CollageData extends TemplateData {
  /// List of image asset paths.
  final List<String> images;

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
    required this.images,
    this.title,
    this.subtitle,
    this.description,
    this.captions,
    this.featuredIndex,
    this.layout = TemplateCollageLayout.grid,
    this.stats = const {},
  }) : assert(images.length > 0, 'CollageData must have at least 1 image');

  /// Number of images.
  int get count => images.length;

  /// Returns the featured image path, or the first image if not specified.
  String get featuredImage =>
      featuredIndex != null ? images[featuredIndex!] : images.first;
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
class HighlightItem {
  /// Title of the highlight.
  final String title;

  /// Optional description.
  final String? description;

  /// Optional icon.
  final IconData? icon;

  /// Optional image path.
  final String? imagePath;

  /// Optional value or statistic.
  final String? value;

  const HighlightItem({
    required this.title,
    this.description,
    this.icon,
    this.imagePath,
    this.value,
  });
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
  final List<String>? images;

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
    this.images,
    this.value,
    this.statValue,
    this.statLabel,
    this.theme,
    this.accentColor,
    this.metadata,
  });
}
