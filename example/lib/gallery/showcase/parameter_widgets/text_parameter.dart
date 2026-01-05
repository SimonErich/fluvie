import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/example_parameter.dart';
import '../theme.dart';

/// Text input widget for string parameters
class TextParameterWidget extends ConsumerStatefulWidget {
  final ExampleParameter parameter;
  final String value;
  final ValueChanged<String> onChanged;

  const TextParameterWidget({
    super.key,
    required this.parameter,
    required this.value,
    required this.onChanged,
  });

  @override
  ConsumerState<TextParameterWidget> createState() =>
      _TextParameterWidgetState();
}

class _TextParameterWidgetState extends ConsumerState<TextParameterWidget> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value);
  }

  @override
  void didUpdateWidget(TextParameterWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != oldWidget.value && widget.value != _controller.text) {
      _controller.text = widget.value;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GalleryTheme.glassmorphicContainer(
      backgroundColor: GalleryTheme.elevatedSurface.withValues(alpha: 0.3),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.parameter.label,
            style: GalleryTheme.textTheme.titleLarge?.copyWith(fontSize: 15),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _controller,
            style: GalleryTheme.textTheme.bodyLarge?.copyWith(fontSize: 14),
            decoration: InputDecoration(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 12,
              ),
              filled: true,
              fillColor: GalleryTheme.deepBackground,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: GalleryTheme.glassBorder),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                  color: GalleryTheme.glassBorder,
                  width: 1.5,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                  color: GalleryTheme.accentPink,
                  width: 2,
                ),
              ),
              hintText: 'Enter ${widget.parameter.label.toLowerCase()}',
              hintStyle: GalleryTheme.textTheme.bodyMedium?.copyWith(
                fontSize: 14,
              ),
            ),
            onChanged: widget.onChanged,
          ),
          if (widget.parameter.description.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              widget.parameter.description,
              style: GalleryTheme.textTheme.bodyMedium?.copyWith(fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }
}
