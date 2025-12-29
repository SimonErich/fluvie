import 'package:flex_color_picker/flex_color_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/example_parameter.dart';
import '../theme.dart';

/// Color picker widget for color parameters
class ColorParameterWidget extends ConsumerWidget {
  final ExampleParameter parameter;
  final Color value;
  final ValueChanged<Color> onChanged;

  const ColorParameterWidget({
    super.key,
    required this.parameter,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hexColor =
        '#${value.toARGB32().toRadixString(16).substring(2).toUpperCase()}';

    return GalleryTheme.glassmorphicContainer(
      backgroundColor: GalleryTheme.elevatedSurface.withValues(alpha: 0.3),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            parameter.label,
            style: GalleryTheme.textTheme.titleLarge?.copyWith(fontSize: 15),
          ),
          const SizedBox(height: 12),
          InkWell(
            onTap: () => _showColorPicker(context),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              height: 60,
              decoration: BoxDecoration(
                color: value,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: GalleryTheme.glassBorder, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: value.withValues(alpha: 0.4),
                    blurRadius: 12,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    hexColor,
                    style: TextStyle(
                      color: value.computeLuminance() > 0.5
                          ? Colors.black
                          : Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
              ),
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

  Future<void> _showColorPicker(BuildContext context) async {
    Color selectedColor = value;

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(parameter.label),
        content: SingleChildScrollView(
          child: ColorPicker(
            color: value,
            onColorChanged: (color) => selectedColor = color,
            width: 40,
            height: 40,
            borderRadius: 8,
            spacing: 5,
            runSpacing: 5,
            wheelDiameter: 200,
            heading: Text(
              'Select color',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            subheading: Text(
              'Select shade',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            pickersEnabled: const {
              ColorPickerType.both: false,
              ColorPickerType.primary: true,
              ColorPickerType.accent: false,
              ColorPickerType.wheel: true,
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              onChanged(selectedColor);
              Navigator.of(context).pop();
            },
            child: const Text('Select'),
          ),
        ],
      ),
    );
  }
}
