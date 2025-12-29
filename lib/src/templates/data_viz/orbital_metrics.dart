import 'dart:math' as math;

import 'package:flutter/material.dart' hide Easing;

import '../../presentation/time_consumer.dart';
import '../../declarative/utils/easing.dart';
import '../../declarative/animations/core/animated_prop.dart';
import '../../declarative/animations/core/prop_animation.dart';
import '../../declarative/effects/particle_effect.dart';
import '../_base/template_base.dart';
import '../_base/template_config.dart';
import '../_base/template_data.dart';

/// A central planet with smaller moons (metrics) orbiting it.
///
/// Creates a solar system visualization where the main stat or artist
/// is the central "planet" and supporting metrics orbit around it
/// as moons with their own labels.
///
/// Best used for:
/// - Main stat with supporting data
/// - Genre breakdowns
/// - Artist/category relationships
///
/// Example:
/// ```dart
/// OrbitalMetrics(
///   data: DataVizData(
///     title: 'Your Music Universe',
///     metrics: [
///       MetricData(label: 'Pop', value: 45, color: Colors.pink),
///       MetricData(label: 'Rock', value: 25, color: Colors.red),
///       MetricData(label: 'Hip Hop', value: 20, color: Colors.purple),
///       MetricData(label: 'Jazz', value: 10, color: Colors.blue),
///     ],
///   ),
/// )
/// ```
class OrbitalMetrics extends WrappedTemplate with TemplateAnimationMixin {
  /// Radius of the orbital path.
  final double orbitRadius;

  /// Speed of the orbit (rotations per minute at 30fps).
  final double orbitSpeed;

  /// Central element label.
  final String? centerLabel;

  /// Central element value.
  final String? centerValue;

  const OrbitalMetrics({
    super.key,
    required DataVizData super.data,
    super.theme,
    super.timing,
    this.orbitRadius = 200,
    this.orbitSpeed = 0.3,
    this.centerLabel,
    this.centerValue,
  });

  @override
  int get recommendedLength => 180;

  @override
  TemplateCategory get category => TemplateCategory.dataViz;

  @override
  String get description => 'Central planet with orbiting metric moons';

  @override
  TemplateTheme get defaultTheme => TemplateTheme.midnight;

  DataVizData get dataVizData => data as DataVizData;

  @override
  Widget build(BuildContext context) {
    final colors = effectiveTheme;

    return Container(
      color: colors.backgroundColor,
      child: Stack(
        children: [
          // Star field background
          Positioned.fill(
            child: ParticleEffect.sparkles(
              count: 50,
              color: colors.textColor.withValues(alpha: 0.3),
            ),
          ),

          // Title
          Positioned(
            top: 60,
            left: 0,
            right: 0,
            child: AnimatedProp(
              startFrame: 5,
              duration: 30,
              animation: PropAnimation.slideUpFade(distance: 30),
              child: Text(
                dataVizData.title ?? 'Your Stats',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.w700,
                  color: colors.textColor,
                ),
              ),
            ),
          ),

          // Orbital system
          Positioned.fill(child: Center(child: _buildOrbitalSystem(colors))),
        ],
      ),
    );
  }

  Widget _buildOrbitalSystem(TemplateTheme colors) {
    return TimeConsumer(
      builder: (context, frame, _) {
        final time = frame / 30.0;

        final metrics = dataVizData.metrics;
        final entryProgress = calculateEntryProgress(frame, 30, 50);

        return Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            // Orbit path (decorative)
            ...List.generate(metrics.length, (index) {
              final radius = orbitRadius + (index * 50);
              final pathOpacity = entryProgress * 0.2;

              return Container(
                width: radius * 2,
                height: radius * 2,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: colors.primaryColor.withValues(alpha: pathOpacity),
                    width: 1,
                  ),
                ),
              );
            }),

            // Central planet
            AnimatedProp(
              startFrame: 40,
              duration: 40,
              animation: PropAnimation.combine([
                PropAnimation.zoomIn(start: 0.3),
                PropAnimation.fadeIn(),
              ]),
              curve: Easing.elastic,
              child: _buildCentralPlanet(colors),
            ),

            // Orbiting moons
            ...List.generate(metrics.length, (index) {
              final metric = metrics[index];
              final orbitIndex = index;
              final radius = orbitRadius + (orbitIndex * 50);

              // Each moon has different starting angle
              final startAngle = (index / metrics.length) * 2 * math.pi;
              // Different speeds for visual interest
              final speed = orbitSpeed * (1 - index * 0.1);
              final currentAngle = startAngle + (time * speed * 2 * math.pi);

              final x = math.cos(currentAngle) * radius;
              final y = math.sin(currentAngle) * radius;

              // Entry delay per moon
              final moonEntryStart = 60 + (index * 10);
              final moonProgress = calculateEntryProgress(
                frame,
                moonEntryStart,
                30,
              );
              final moonScale = Curves.easeOutBack.transform(moonProgress);

              return Transform.translate(
                offset: Offset(x, y),
                child: Transform.scale(
                  scale: moonScale,
                  child: Opacity(
                    opacity: moonProgress,
                    child: _buildMoon(metric, colors, index),
                  ),
                ),
              );
            }),
          ],
        );
      },
    );
  }

  Widget _buildCentralPlanet(TemplateTheme colors) {
    return Container(
      width: 150,
      height: 150,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            colors.primaryColor,
            colors.primaryColor.withValues(alpha: 0.6),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: colors.primaryColor.withValues(alpha: 0.5),
            blurRadius: 40,
            spreadRadius: 10,
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (centerValue != null)
            Text(
              centerValue!,
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w900,
                color: colors.textColor,
              ),
            )
          else
            Text(
              '${dataVizData.total.toInt()}',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w900,
                color: colors.textColor,
              ),
            ),
          if (centerLabel != null)
            Text(
              centerLabel!,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: colors.textColor.withValues(alpha: 0.8),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMoon(MetricData metric, TemplateTheme colors, int index) {
    final moonColor = metric.color ?? _getDefaultColor(index, colors);
    final size =
        60.0 + (metric.percentage ?? metric.value / dataVizData.total) * 40;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: moonColor,
            boxShadow: [
              BoxShadow(
                color: moonColor.withValues(alpha: 0.5),
                blurRadius: 15,
                spreadRadius: 3,
              ),
            ],
          ),
          child: Center(
            child: Text(
              metric.value is double
                  ? '${metric.value.toStringAsFixed(0)}${metric.unit ?? ''}'
                  : '${metric.value}${metric.unit ?? ''}',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: colors.textColor,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: colors.backgroundColor.withValues(alpha: 0.8),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            metric.label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: colors.textColor,
            ),
          ),
        ),
      ],
    );
  }

  Color _getDefaultColor(int index, TemplateTheme colors) {
    final defaultColors = [
      colors.primaryColor,
      colors.secondaryColor,
      colors.accentColor,
      colors.primaryColor.withValues(alpha: 0.7),
      colors.secondaryColor.withValues(alpha: 0.7),
    ];
    return defaultColors[index % defaultColors.length];
  }
}
