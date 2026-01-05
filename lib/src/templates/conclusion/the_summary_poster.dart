import 'package:flutter/material.dart';

import '../../declarative/animations/core/animated_prop.dart';
import '../../declarative/animations/core/prop_animation.dart';
import '../../declarative/effects/particle_effect.dart';
import '../_base/template_base.dart';
import '../_base/template_config.dart';
import '../_base/template_data.dart';

/// High-design poster layout with QR code and summary stats.
///
/// Creates a shareable poster-style summary of the year with
/// key stats, a QR code for sharing, and beautiful typography.
/// Designed to look great as a screenshot.
///
/// Best used for:
/// - Final summaries
/// - Shareable content
/// - Year recaps
///
/// Example:
/// ```dart
/// TheSummaryPoster(
///   data: SummaryData(
///     title: 'Your 2024 Wrapped',
///     name: 'John Doe',
///     stats: {'Hours': '1,234', 'Songs': '5,678'},
///     qrData: 'https://wrapped.example.com/share/123',
///   ),
/// )
/// ```
class TheSummaryPoster extends WrappedTemplate with TemplateAnimationMixin {
  /// Whether to show QR code.
  final bool showQR;

  /// Whether to show decorative elements.
  final bool showDecorations;

  /// Layout style.
  final PosterLayout layout;

  const TheSummaryPoster({
    super.key,
    required SummaryData super.data,
    super.theme,
    super.timing,
    this.showQR = true,
    this.showDecorations = true,
    this.layout = PosterLayout.centered,
  });

  @override
  int get recommendedLength => 180;

  @override
  TemplateCategory get category => TemplateCategory.conclusion;

  @override
  String get description => 'High-design poster with summary stats';

  @override
  TemplateTheme get defaultTheme => TemplateTheme.spotify;

  SummaryData get summaryData => data as SummaryData;

  @override
  Widget build(BuildContext context) {
    final colors = effectiveTheme;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colors.backgroundColor,
            colors.secondaryColor.withValues(alpha: 0.3),
          ],
        ),
      ),
      child: Stack(
        children: [
          // Decorative elements
          if (showDecorations)
            Positioned.fill(
              child: ParticleEffect.sparkles(
                count: 30,
                color: colors.primaryColor.withValues(alpha: 0.3),
              ),
            ),

          // Main content
          Positioned.fill(
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(40),
                child: _buildPosterContent(colors),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPosterContent(TemplateTheme colors) {
    switch (layout) {
      case PosterLayout.centered:
        return _buildCenteredLayout(colors);
      case PosterLayout.leftAligned:
        return _buildLeftAlignedLayout(colors);
      case PosterLayout.grid:
        return _buildGridLayout(colors);
    }
  }

  Widget _buildCenteredLayout(TemplateTheme colors) {
    return Column(
      children: [
        // Header
        AnimatedProp(
          startFrame: 10,
          duration: 30,
          animation: PropAnimation.slideUpFade(distance: 20),
          child: Text(
            summaryData.title ?? 'Your Year Wrapped',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.w800,
              color: colors.textColor,
              letterSpacing: 2,
            ),
          ),
        ),

        const SizedBox(height: 20),

        // User name
        if (summaryData.name != null)
          AnimatedProp(
            startFrame: 30,
            duration: 25,
            animation: PropAnimation.fadeIn(),
            child: Text(
              summaryData.name!,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w500,
                color: colors.primaryColor,
              ),
            ),
          ),

        const SizedBox(height: 50),

        // Stats grid
        Expanded(child: _buildStatsGrid(colors)),

        const SizedBox(height: 30),

        // QR code and footer
        _buildFooter(colors),
      ],
    );
  }

  Widget _buildLeftAlignedLayout(TemplateTheme colors) {
    return Row(
      children: [
        // Left side - text content
        Expanded(
          flex: 3,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AnimatedProp(
                startFrame: 10,
                duration: 30,
                animation: PropAnimation.slideUpFade(distance: 20),
                child: Text(
                  summaryData.title ?? 'Your Year Wrapped',
                  style: TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.w900,
                    color: colors.textColor,
                    height: 1.1,
                  ),
                ),
              ),

              const SizedBox(height: 30),

              if (summaryData.name != null)
                AnimatedProp(
                  startFrame: 30,
                  duration: 25,
                  animation: PropAnimation.fadeIn(),
                  child: Text(
                    summaryData.name!,
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w500,
                      color: colors.primaryColor,
                    ),
                  ),
                ),

              const Spacer(),

              // Stats list
              ...summaryData.stats.entries.take(4).map((entry) {
                final index = summaryData.stats.keys.toList().indexOf(
                      entry.key,
                    );
                return AnimatedProp(
                  startFrame: 60 + index * 15,
                  duration: 25,
                  animation: PropAnimation.slideUpFade(distance: 15),
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 20),
                    child: _buildStatRow(entry.key, entry.value, colors),
                  ),
                );
              }),

              const Spacer(),
            ],
          ),
        ),

        // Right side - decorative/QR
        if (showQR)
          Expanded(flex: 2, child: Center(child: _buildQRSection(colors))),
      ],
    );
  }

  Widget _buildGridLayout(TemplateTheme colors) {
    return Column(
      children: [
        // Title
        AnimatedProp(
          startFrame: 10,
          duration: 30,
          animation: PropAnimation.slideUpFade(distance: 20),
          child: Text(
            summaryData.title ?? 'Your Year Wrapped',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w800,
              color: colors.textColor,
            ),
          ),
        ),

        const SizedBox(height: 30),

        // Stats in 2x2 grid
        Expanded(child: _buildStatsGrid(colors)),

        const SizedBox(height: 20),

        // Footer with year
        _buildFooter(colors),
      ],
    );
  }

  Widget _buildStatsGrid(TemplateTheme colors) {
    final stats = summaryData.stats;
    final statsList = stats.entries.take(4).toList();

    return GridView.count(
      crossAxisCount: 2,
      mainAxisSpacing: 20,
      crossAxisSpacing: 20,
      childAspectRatio: 1.3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: statsList.asMap().entries.map((entry) {
        final index = entry.key;
        final stat = entry.value;

        return AnimatedProp(
          startFrame: 50 + index * 12,
          duration: 30,
          animation: PropAnimation.combine([
            const PropAnimation.scale(start: 0.9, end: 1.0),
            PropAnimation.fadeIn(),
          ]),
          child: _buildStatCard(stat.key, stat.value, colors, index),
        );
      }).toList(),
    );
  }

  Widget _buildStatCard(
    String label,
    dynamic value,
    TemplateTheme colors,
    int index,
  ) {
    final cardColors = [
      colors.primaryColor,
      colors.secondaryColor,
      colors.accentColor,
      colors.primaryColor.withValues(alpha: 0.8),
    ];

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: cardColors[index % cardColors.length].withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: cardColors[index % cardColors.length].withValues(alpha: 0.3),
          width: 2,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            value.toString(),
            style: TextStyle(
              fontSize: 42,
              fontWeight: FontWeight.w900,
              color: colors.textColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: colors.textColor.withValues(alpha: 0.7),
              letterSpacing: 2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatRow(String label, dynamic value, TemplateTheme colors) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(
          value.toString(),
          style: TextStyle(
            fontSize: 48,
            fontWeight: FontWeight.w900,
            color: colors.textColor,
          ),
        ),
        const SizedBox(width: 16),
        Text(
          label.toLowerCase(),
          style: TextStyle(
            fontSize: 20,
            color: colors.textColor.withValues(alpha: 0.6),
          ),
        ),
      ],
    );
  }

  Widget _buildQRSection(TemplateTheme colors) {
    return AnimatedProp(
      startFrame: 100,
      duration: 35,
      animation: PropAnimation.combine([
        const PropAnimation.scale(start: 0.8, end: 1.0),
        PropAnimation.fadeIn(),
      ]),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 150,
            height: 150,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Center(
              child: Icon(
                Icons.qr_code_2,
                size: 120,
                color: colors.backgroundColor,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Scan to share',
            style: TextStyle(
              fontSize: 14,
              color: colors.textColor.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter(TemplateTheme colors) {
    return AnimatedProp(
      startFrame: 140,
      duration: 25,
      animation: PropAnimation.slideUpFade(distance: 15),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (showQR && layout == PosterLayout.centered)
            Container(
              width: 60,
              height: 60,
              margin: const EdgeInsets.only(right: 20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.qr_code_2,
                size: 50,
                color: colors.backgroundColor,
              ),
            ),
          Column(
            crossAxisAlignment: layout == PosterLayout.centered
                ? CrossAxisAlignment.center
                : CrossAxisAlignment.start,
            children: [
              Text(
                summaryData.year?.toString() ?? DateTime.now().year.toString(),
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: colors.primaryColor,
                ),
              ),
              if (summaryData.subtitle != null)
                Text(
                  summaryData.subtitle!,
                  style: TextStyle(
                    fontSize: 14,
                    color: colors.textColor.withValues(alpha: 0.6),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Poster layout options.
enum PosterLayout { centered, leftAligned, grid }
