import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/example_parameter.dart';
import '../theme.dart';

/// Slider widget for numeric parameters
class SliderParameterWidget extends ConsumerWidget {
  final ExampleParameter parameter;
  final num value;
  final ValueChanged<num> onChanged;

  const SliderParameterWidget({
    super.key,
    required this.parameter,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final minValue = (parameter.minValue as num).toDouble();
    final maxValue = (parameter.maxValue as num).toDouble();
    final currentValue = value.toDouble();
    final divisions = parameter.divisions ??
        (maxValue - minValue).toInt(); // Default to range size

    return GalleryTheme.glassmorphicContainer(
      backgroundColor: GalleryTheme.elevatedSurface.withValues(alpha: 0.3),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  parameter.label,
                  style: GalleryTheme.textTheme.titleLarge?.copyWith(
                    fontSize: 15,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  gradient: GalleryTheme.primaryGradient,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  parameter.divisions != null && parameter.divisions! > 0
                      ? currentValue.toStringAsFixed(1)
                      : currentValue.toInt().toString(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SliderTheme(
            data: SliderThemeData(
              trackHeight: 6,
              activeTrackColor: GalleryTheme.accentPink,
              inactiveTrackColor: GalleryTheme.elevatedSurface,
              thumbColor: GalleryTheme.accentPink,
              overlayColor: GalleryTheme.accentPink.withValues(alpha: 0.2),
              thumbShape: const RoundSliderThumbShape(
                enabledThumbRadius: 10,
                elevation: 4,
              ),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 20),
            ),
            child: Slider(
              value: currentValue.clamp(minValue, maxValue),
              min: minValue,
              max: maxValue,
              divisions: divisions,
              label: parameter.divisions != null && parameter.divisions! > 0
                  ? currentValue.toStringAsFixed(1)
                  : currentValue.toInt().toString(),
              onChanged: (newValue) {
                if (parameter.divisions != null && parameter.divisions! > 0) {
                  onChanged(newValue);
                } else {
                  onChanged(newValue.toInt());
                }
              },
            ),
          ),
          if (parameter.description.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              parameter.description,
              style: GalleryTheme.textTheme.bodyMedium?.copyWith(fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }
}
