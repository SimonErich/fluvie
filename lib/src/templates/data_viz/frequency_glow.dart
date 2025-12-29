import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../presentation/time_consumer.dart';
import '../../presentation/video_composition.dart';
import '../../declarative/animations/core/animated_prop.dart';
import '../../declarative/animations/core/prop_animation.dart';
import '../_base/template_base.dart';
import '../_base/template_config.dart';
import '../_base/template_data.dart';

/// An audio waveform visualization with color changes by genre/category.
///
/// Creates a dynamic frequency visualization that responds to data,
/// with bars that glow and pulse. Colors can represent different genres
/// or categories of data.
///
/// Best used for:
/// - Genre distribution
/// - Frequency/intensity data
/// - Music-related metrics
///
/// Example:
/// ```dart
/// FrequencyGlow(
///   data: DataVizData(
///     title: 'Your Sound',
///     metrics: [
///       MetricData(label: 'Bass', value: 80, color: Colors.purple),
///       MetricData(label: 'Mid', value: 60, color: Colors.blue),
///       MetricData(label: 'Treble', value: 70, color: Colors.cyan),
///     ],
///   ),
/// )
/// ```
class FrequencyGlow extends WrappedTemplate with TemplateAnimationMixin {
  /// Number of frequency bars.
  final int barCount;

  /// Whether bars animate/pulse.
  final bool animate;

  /// Mirror the bars (top and bottom).
  final bool mirrored;

  /// Random seed for bar variations.
  final int seed;

  const FrequencyGlow({
    super.key,
    required DataVizData super.data,
    super.theme,
    super.timing,
    this.barCount = 64,
    this.animate = true,
    this.mirrored = true,
    this.seed = 42,
  });

  @override
  int get recommendedLength => 150;

  @override
  TemplateCategory get category => TemplateCategory.dataViz;

  @override
  String get description => 'Audio waveform with genre-based colors';

  @override
  TemplateTheme get defaultTheme => TemplateTheme.neon;

  DataVizData get dataVizData => data as DataVizData;

  @override
  Widget build(BuildContext context) {
    final colors = effectiveTheme;

    return Container(
      color: colors.backgroundColor,
      child: Stack(
        children: [
          // Frequency bars
          Positioned.fill(child: _buildFrequencyBars(colors)),

          // Title overlay
          Positioned(
            top: 60,
            left: 0,
            right: 0,
            child: AnimatedProp(
              startFrame: 0,
              duration: 30,
              animation: PropAnimation.fadeIn(),
              child: Text(
                dataVizData.title ?? 'Your Frequency',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.w900,
                  color: colors.textColor,
                  shadows: [
                    Shadow(
                      color: colors.primaryColor.withValues(alpha: 0.5),
                      blurRadius: 30,
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Metrics legend
          Positioned(
            bottom: 60,
            left: 0,
            right: 0,
            child: _buildLegend(colors),
          ),
        ],
      ),
    );
  }

  Widget _buildFrequencyBars(TemplateTheme colors) {
    return TimeConsumer(
      builder: (context, frame, _) {
        final composition = VideoComposition.of(context);
        final fps = composition?.fps ?? 30;
        final time = frame / fps;

        // Entry animation
        final entryProgress = ((frame - 20) / 60).clamp(0.0, 1.0);

        return LayoutBuilder(
          builder: (context, constraints) {
            return CustomPaint(
              painter: _FrequencyBarsPainter(
                barCount: barCount,
                metrics: dataVizData.metrics,
                entryProgress: entryProgress,
                time: time,
                animate: animate,
                mirrored: mirrored,
                primaryColor: colors.primaryColor,
                secondaryColor: colors.secondaryColor,
                accentColor: colors.accentColor,
                seed: seed,
              ),
              size: Size.infinite,
            );
          },
        );
      },
    );
  }

  Widget _buildLegend(TemplateTheme colors) {
    return AnimatedProp(
      startFrame: 60,
      duration: 30,
      animation: PropAnimation.slideUpFade(distance: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: dataVizData.metrics.asMap().entries.map((entry) {
          final metric = entry.value;
          final color = metric.color ?? _getDefaultColor(entry.key, colors);

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 15),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(4),
                    boxShadow: [
                      BoxShadow(
                        color: color.withValues(alpha: 0.5),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${metric.label}: ${metric.value is double ? metric.value.toStringAsFixed(0) : metric.value}%',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: colors.textColor.withValues(alpha: 0.9),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Color _getDefaultColor(int index, TemplateTheme colors) {
    final defaultColors = [
      colors.primaryColor,
      colors.secondaryColor,
      colors.accentColor,
    ];
    return defaultColors[index % defaultColors.length];
  }
}

class _FrequencyBarsPainter extends CustomPainter {
  final int barCount;
  final List<MetricData> metrics;
  final double entryProgress;
  final double time;
  final bool animate;
  final bool mirrored;
  final Color primaryColor;
  final Color secondaryColor;
  final Color accentColor;
  final int seed;

  _FrequencyBarsPainter({
    required this.barCount,
    required this.metrics,
    required this.entryProgress,
    required this.time,
    required this.animate,
    required this.mirrored,
    required this.primaryColor,
    required this.secondaryColor,
    required this.accentColor,
    required this.seed,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final random = math.Random(seed);
    final barWidth = size.width / barCount;
    final maxBarHeight = size.height * (mirrored ? 0.35 : 0.6);
    final centerY = size.height / 2;

    // Generate base heights with some pattern
    final baseHeights = List.generate(barCount, (i) {
      // Create a frequency-like pattern
      final normalized = i / barCount;
      final wave1 = math.sin(normalized * math.pi * 4) * 0.3;
      final wave2 = math.sin(normalized * math.pi * 8) * 0.2;
      final base = 0.3 + random.nextDouble() * 0.4;
      return (base + wave1 + wave2).clamp(0.1, 1.0);
    });

    for (var i = 0; i < barCount; i++) {
      final x = i * barWidth;

      // Determine color based on position (gradient across metrics)
      final colorProgress = i / barCount;
      final color = _getColorForPosition(colorProgress);

      // Base height from pattern
      var height = baseHeights[i] * maxBarHeight;

      // Animation
      if (animate) {
        final animPhase = i * 0.15;
        final animFactor = 1.0 + math.sin(time * 5 + animPhase) * 0.3;
        height *= animFactor;
      }

      // Entry animation
      final entryDelay = i * 0.02;
      final barEntry = ((entryProgress - entryDelay) / 0.3).clamp(0.0, 1.0);
      height *= Curves.easeOutCubic.transform(barEntry);

      // Glow effect
      final glowPaint = Paint()
        ..color = color.withValues(alpha: 0.3)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);

      final barPaint = Paint()
        ..shader =
            LinearGradient(
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
              colors: [
                color,
                color.withValues(alpha: 0.8),
                color.withValues(alpha: 0.6),
              ],
            ).createShader(
              Rect.fromLTWH(x, centerY - height, barWidth - 2, height),
            );

      // Draw glow
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x + 1, centerY - height, barWidth - 2, height),
          const Radius.circular(2),
        ),
        glowPaint,
      );

      // Draw bar
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x + 1, centerY - height, barWidth - 2, height),
          const Radius.circular(2),
        ),
        barPaint,
      );

      // Mirror bottom
      if (mirrored) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(x + 1, centerY, barWidth - 2, height * 0.7),
            const Radius.circular(2),
          ),
          glowPaint,
        );

        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(x + 1, centerY, barWidth - 2, height * 0.7),
            const Radius.circular(2),
          ),
          barPaint,
        );
      }
    }

    // Center line
    final linePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.3)
      ..strokeWidth = 1;
    canvas.drawLine(Offset(0, centerY), Offset(size.width, centerY), linePaint);
  }

  Color _getColorForPosition(double position) {
    if (metrics.isEmpty) {
      return primaryColor;
    }

    // Determine which metric zone we're in
    final segmentSize = 1.0 / metrics.length;
    final index = (position / segmentSize).floor().clamp(0, metrics.length - 1);

    final color = metrics[index].color;
    if (color != null) return color;

    // Default gradient between primary and secondary
    final defaultColors = [primaryColor, secondaryColor, accentColor];
    return defaultColors[index % defaultColors.length];
  }

  @override
  bool shouldRepaint(covariant _FrequencyBarsPainter oldDelegate) {
    return oldDelegate.time != time ||
        oldDelegate.entryProgress != entryProgress;
  }
}
