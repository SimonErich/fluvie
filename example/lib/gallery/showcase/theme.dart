import 'package:flutter/material.dart';
import 'dart:ui';

/// Modern dark theme color palette for Fluvie Gallery
class GalleryTheme {
  // Background layers
  static const Color deepBackground = Color(0xFF0A0E27);
  static const Color surfaceBackground = Color(0xFF151932);
  static const Color elevatedSurface = Color(0xFF1E2139);

  // Accent gradient (purple-to-pink)
  static const Color gradientStart = Color(0xFF667EEA);
  static const Color gradientEnd = Color(0xFF764BA2);
  static const Color accentPink = Color(0xFFF857A6);

  // Semantic colors
  static const Color success = Color(0xFF4ECDC4);
  static const Color warning = Color(0xFFFFE66D);
  static const Color error = Color(0xFFFF6B6B);

  // Text hierarchy
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xB3FFFFFF); // 70% opacity
  static const Color textTertiary = Color(0x80FFFFFF); // 50% opacity

  // Glassmorphism border
  static const Color glassBorder = Color(0x1AFFFFFF); // 10% opacity
  static const Color glassBackground = Color(0x0DFFFFFF); // 5% opacity

  /// Primary gradient used throughout the app
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [gradientStart, gradientEnd],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Accent gradient with pink
  static const LinearGradient accentGradient = LinearGradient(
    colors: [gradientEnd, accentPink],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Background gradient for panels
  static const LinearGradient backgroundGradient = LinearGradient(
    colors: [deepBackground, surfaceBackground],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  /// Creates a glassmorphic container decoration
  static BoxDecoration glassmorphic({
    double borderRadius = 16,
    double borderWidth = 1.5,
    Color? backgroundColor,
    Color? borderColor,
  }) {
    return BoxDecoration(
      color: backgroundColor ?? glassBackground,
      borderRadius: BorderRadius.circular(borderRadius),
      border: Border.all(color: borderColor ?? glassBorder, width: borderWidth),
    );
  }

  /// Creates a glassmorphic container with blur
  static Widget glassmorphicContainer({
    required Widget child,
    double borderRadius = 16,
    double borderWidth = 1.5,
    Color? backgroundColor,
    Color? borderColor,
    EdgeInsetsGeometry? padding,
    double blur = 10,
  }) {
    return Container(
      decoration: glassmorphic(
        borderRadius: borderRadius,
        borderWidth: borderWidth,
        backgroundColor: backgroundColor,
        borderColor: borderColor,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child:
              padding != null ? Padding(padding: padding, child: child) : child,
        ),
      ),
    );
  }

  /// Creates a glow effect for hover states
  static List<BoxShadow> glowEffect({
    Color? color,
    double blurRadius = 20,
    double spreadRadius = 2,
  }) {
    return [
      BoxShadow(
        color: (color ?? gradientStart).withValues(alpha: 0.3),
        blurRadius: blurRadius,
        spreadRadius: spreadRadius,
      ),
    ];
  }

  /// Difficulty color mapping
  static Color getDifficultyColor(String difficulty) {
    switch (difficulty.toLowerCase()) {
      case 'beginner':
        return success;
      case 'intermediate':
        return warning;
      case 'advanced':
        return error;
      default:
        return textTertiary;
    }
  }

  /// Difficulty icon mapping
  static IconData getDifficultyIcon(String difficulty) {
    switch (difficulty.toLowerCase()) {
      case 'beginner':
        return Icons.star;
      case 'intermediate':
        return Icons.stars;
      case 'advanced':
        return Icons.workspace_premium;
      default:
        return Icons.circle;
    }
  }

  /// Custom text theme for the gallery
  static TextTheme textTheme = const TextTheme(
    displayLarge: TextStyle(
      fontSize: 32,
      fontWeight: FontWeight.bold,
      color: textPrimary,
      height: 1.2,
    ),
    headlineMedium: TextStyle(
      fontSize: 24,
      fontWeight: FontWeight.w600,
      color: textPrimary,
      height: 1.3,
    ),
    titleLarge: TextStyle(
      fontSize: 18,
      fontWeight: FontWeight.w500,
      color: textPrimary,
      height: 1.4,
    ),
    bodyLarge: TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.normal,
      color: textSecondary,
      height: 1.5,
    ),
    bodyMedium: TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.normal,
      color: textTertiary,
      height: 1.5,
    ),
    labelSmall: TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.normal,
      color: textTertiary,
      height: 1.4,
    ),
  );

  /// Material theme data for the app
  static ThemeData themeData = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: deepBackground,
    colorScheme: ColorScheme.dark(
      primary: gradientStart,
      secondary: accentPink,
      surface: surfaceBackground,
      error: error,
      onPrimary: textPrimary,
      onSecondary: textPrimary,
      onSurface: textPrimary,
      onError: textPrimary,
    ),
    textTheme: textTheme,
    cardTheme: CardThemeData(
      color: elevatedSurface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: glassBorder),
      ),
    ),
    iconTheme: const IconThemeData(color: textPrimary),
    dividerTheme: DividerThemeData(color: glassBorder, thickness: 1),
    chipTheme: ChipThemeData(
      backgroundColor: glassBackground,
      labelStyle: const TextStyle(color: textPrimary, fontSize: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: glassBorder),
      ),
    ),
  );
}
