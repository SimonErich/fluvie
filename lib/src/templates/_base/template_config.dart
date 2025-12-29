import 'package:flutter/widgets.dart';

/// Theme configuration for templates.
///
/// Provides a consistent color scheme and typography across templates.
/// Use the provided presets or create custom themes.
///
/// Example:
/// ```dart
/// TheNeonGate(
///   data: IntroData(title: 'Your 2024'),
///   theme: TemplateTheme.spotify,
/// )
/// ```
class TemplateTheme {
  /// Primary brand color.
  final Color primaryColor;

  /// Secondary/accent color.
  final Color secondaryColor;

  /// Background color.
  final Color backgroundColor;

  /// Primary text color.
  final Color textColor;

  /// Accent/highlight color.
  final Color accentColor;

  /// Muted/secondary text color.
  final Color? mutedColor;

  /// Error/warning color.
  final Color? errorColor;

  /// Success color.
  final Color? successColor;

  /// Optional font family.
  final String? fontFamily;

  /// Text style for headings.
  final TextStyle? headingStyle;

  /// Text style for body text.
  final TextStyle? bodyStyle;

  /// Text style for labels/captions.
  final TextStyle? labelStyle;

  /// Text style for large display text.
  final TextStyle? displayStyle;

  const TemplateTheme({
    required this.primaryColor,
    required this.secondaryColor,
    required this.backgroundColor,
    required this.textColor,
    required this.accentColor,
    this.mutedColor,
    this.errorColor,
    this.successColor,
    this.fontFamily,
    this.headingStyle,
    this.bodyStyle,
    this.labelStyle,
    this.displayStyle,
  });

  /// Merge with another theme, preferring this theme's non-null values.
  TemplateTheme merge(TemplateTheme other) {
    return TemplateTheme(
      primaryColor: primaryColor,
      secondaryColor: secondaryColor,
      backgroundColor: backgroundColor,
      textColor: textColor,
      accentColor: accentColor,
      mutedColor: mutedColor ?? other.mutedColor,
      errorColor: errorColor ?? other.errorColor,
      successColor: successColor ?? other.successColor,
      fontFamily: fontFamily ?? other.fontFamily,
      headingStyle: headingStyle ?? other.headingStyle,
      bodyStyle: bodyStyle ?? other.bodyStyle,
      labelStyle: labelStyle ?? other.labelStyle,
      displayStyle: displayStyle ?? other.displayStyle,
    );
  }

  /// Creates a copy with updated fields.
  TemplateTheme copyWith({
    Color? primaryColor,
    Color? secondaryColor,
    Color? backgroundColor,
    Color? textColor,
    Color? accentColor,
    Color? mutedColor,
    Color? errorColor,
    Color? successColor,
    String? fontFamily,
    TextStyle? headingStyle,
    TextStyle? bodyStyle,
    TextStyle? labelStyle,
    TextStyle? displayStyle,
  }) {
    return TemplateTheme(
      primaryColor: primaryColor ?? this.primaryColor,
      secondaryColor: secondaryColor ?? this.secondaryColor,
      backgroundColor: backgroundColor ?? this.backgroundColor,
      textColor: textColor ?? this.textColor,
      accentColor: accentColor ?? this.accentColor,
      mutedColor: mutedColor ?? this.mutedColor,
      errorColor: errorColor ?? this.errorColor,
      successColor: successColor ?? this.successColor,
      fontFamily: fontFamily ?? this.fontFamily,
      headingStyle: headingStyle ?? this.headingStyle,
      bodyStyle: bodyStyle ?? this.bodyStyle,
      labelStyle: labelStyle ?? this.labelStyle,
      displayStyle: displayStyle ?? this.displayStyle,
    );
  }

  // =========================================================================
  // Pre-built themes
  // =========================================================================

  /// Spotify-inspired green and black theme.
  static const TemplateTheme spotify = TemplateTheme(
    primaryColor: Color(0xFF1DB954),
    secondaryColor: Color(0xFF191414),
    backgroundColor: Color(0xFF121212),
    textColor: Color(0xFFFFFFFF),
    accentColor: Color(0xFF1ED760),
    mutedColor: Color(0xFFB3B3B3),
  );

  /// Neon/cyberpunk theme with magenta and cyan.
  static const TemplateTheme neon = TemplateTheme(
    primaryColor: Color(0xFFFF00FF),
    secondaryColor: Color(0xFF00FFFF),
    backgroundColor: Color(0xFF0D0D0D),
    textColor: Color(0xFFFFFFFF),
    accentColor: Color(0xFFFFFF00),
    mutedColor: Color(0xFF808080),
  );

  /// Soft pastel theme.
  static const TemplateTheme pastel = TemplateTheme(
    primaryColor: Color(0xFFE8D5B7),
    secondaryColor: Color(0xFFB8D4E3),
    backgroundColor: Color(0xFFFAF7F2),
    textColor: Color(0xFF2D2D2D),
    accentColor: Color(0xFFE6B8AF),
    mutedColor: Color(0xFF9E9E9E),
  );

  /// Dark purple/violet theme.
  static const TemplateTheme midnight = TemplateTheme(
    primaryColor: Color(0xFF6366F1),
    secondaryColor: Color(0xFF8B5CF6),
    backgroundColor: Color(0xFF1A1A2E),
    textColor: Color(0xFFFFFFFF),
    accentColor: Color(0xFFA855F7),
    mutedColor: Color(0xFF9CA3AF),
  );

  /// Warm orange/red gradient theme.
  static const TemplateTheme sunset = TemplateTheme(
    primaryColor: Color(0xFFFF6B35),
    secondaryColor: Color(0xFFFF8E53),
    backgroundColor: Color(0xFF1F1F1F),
    textColor: Color(0xFFFFFFFF),
    accentColor: Color(0xFFFFD700),
    mutedColor: Color(0xFFADADAD),
  );

  /// Clean white/minimal theme.
  static const TemplateTheme minimal = TemplateTheme(
    primaryColor: Color(0xFF000000),
    secondaryColor: Color(0xFF333333),
    backgroundColor: Color(0xFFFFFFFF),
    textColor: Color(0xFF000000),
    accentColor: Color(0xFF0066FF),
    mutedColor: Color(0xFF666666),
  );

  /// Retro/vintage warm theme.
  static const TemplateTheme retro = TemplateTheme(
    primaryColor: Color(0xFFD84315),
    secondaryColor: Color(0xFFBF360C),
    backgroundColor: Color(0xFFFFF8E1),
    textColor: Color(0xFF3E2723),
    accentColor: Color(0xFF00897B),
    mutedColor: Color(0xFF8D6E63),
  );

  /// Ocean/water theme.
  static const TemplateTheme ocean = TemplateTheme(
    primaryColor: Color(0xFF0077B6),
    secondaryColor: Color(0xFF00B4D8),
    backgroundColor: Color(0xFF03045E),
    textColor: Color(0xFFFFFFFF),
    accentColor: Color(0xFF90E0EF),
    mutedColor: Color(0xFFCAF0F8),
  );
}

/// Timing configuration for template animations.
///
/// Controls the timing of entry, hold, and exit animations
/// within a template.
class TemplateTiming {
  /// Delay before entry animation starts (in frames).
  final int entryDelay;

  /// Delay between staggered elements (in frames).
  final int staggerDelay;

  /// Duration of entry animations (in frames).
  final int entryDuration;

  /// Duration to hold visible before exit (in frames).
  final int holdDuration;

  /// Duration of exit animations (in frames).
  final int exitDuration;

  /// Curve for entry animations.
  final Curve entryCurve;

  /// Curve for exit animations.
  final Curve exitCurve;

  const TemplateTiming({
    this.entryDelay = 0,
    this.staggerDelay = 5,
    this.entryDuration = 30,
    this.holdDuration = 60,
    this.exitDuration = 20,
    this.entryCurve = Curves.easeOutCubic,
    this.exitCurve = Curves.easeInCubic,
  });

  /// Total duration including delays and animations.
  int get totalDuration =>
      entryDelay + entryDuration + holdDuration + exitDuration;

  /// Frame at which entry animation starts.
  int get entryStart => entryDelay;

  /// Frame at which entry animation ends.
  int get entryEnd => entryDelay + entryDuration;

  /// Frame at which exit animation starts.
  int get exitStart => entryDelay + entryDuration + holdDuration;

  /// Frame at which exit animation ends.
  int get exitEnd => totalDuration;

  /// Returns the entry start frame for a staggered element at [index].
  int staggeredEntryStart(int index) => entryDelay + (index * staggerDelay);

  /// Creates a copy with updated fields.
  TemplateTiming copyWith({
    int? entryDelay,
    int? staggerDelay,
    int? entryDuration,
    int? holdDuration,
    int? exitDuration,
    Curve? entryCurve,
    Curve? exitCurve,
  }) {
    return TemplateTiming(
      entryDelay: entryDelay ?? this.entryDelay,
      staggerDelay: staggerDelay ?? this.staggerDelay,
      entryDuration: entryDuration ?? this.entryDuration,
      holdDuration: holdDuration ?? this.holdDuration,
      exitDuration: exitDuration ?? this.exitDuration,
      entryCurve: entryCurve ?? this.entryCurve,
      exitCurve: exitCurve ?? this.exitCurve,
    );
  }

  // =========================================================================
  // Pre-built timing presets
  // =========================================================================

  /// Quick timing for fast-paced templates.
  static const TemplateTiming quick = TemplateTiming(
    entryDelay: 0,
    staggerDelay: 3,
    entryDuration: 20,
    holdDuration: 40,
    exitDuration: 15,
    entryCurve: Curves.easeOutCubic,
    exitCurve: Curves.easeInCubic,
  );

  /// Standard timing for balanced templates.
  static const TemplateTiming standard = TemplateTiming(
    entryDelay: 5,
    staggerDelay: 5,
    entryDuration: 30,
    holdDuration: 60,
    exitDuration: 20,
    entryCurve: Curves.easeOutCubic,
    exitCurve: Curves.easeInCubic,
  );

  /// Slow/dramatic timing for impactful templates.
  static const TemplateTiming dramatic = TemplateTiming(
    entryDelay: 10,
    staggerDelay: 8,
    entryDuration: 45,
    holdDuration: 90,
    exitDuration: 30,
    entryCurve: Curves.easeOutBack,
    exitCurve: Curves.easeInCubic,
  );

  /// Snappy timing with elastic feel.
  static const TemplateTiming elastic = TemplateTiming(
    entryDelay: 0,
    staggerDelay: 4,
    entryDuration: 35,
    holdDuration: 50,
    exitDuration: 20,
    entryCurve: Curves.elasticOut,
    exitCurve: Curves.easeInCubic,
  );

  /// Slow reveal timing.
  static const TemplateTiming slowReveal = TemplateTiming(
    entryDelay: 15,
    staggerDelay: 10,
    entryDuration: 60,
    holdDuration: 120,
    exitDuration: 40,
    entryCurve: Curves.easeOutQuad,
    exitCurve: Curves.easeInQuad,
  );
}
