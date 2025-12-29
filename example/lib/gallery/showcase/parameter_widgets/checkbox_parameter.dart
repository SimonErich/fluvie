import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/example_parameter.dart';

/// Checkbox widget for boolean parameters
class CheckboxParameterWidget extends ConsumerWidget {
  final ExampleParameter parameter;
  final bool value;
  final ValueChanged<bool> onChanged;

  const CheckboxParameterWidget({
    super.key,
    required this.parameter,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CheckboxListTile(
          title: Text(
            parameter.label,
            style: Theme.of(context).textTheme.titleSmall,
          ),
          subtitle: parameter.description.isNotEmpty
              ? Text(
                  parameter.description,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey[600],
                      ),
                )
              : null,
          value: value,
          onChanged: (newValue) {
            if (newValue != null) {
              onChanged(newValue);
            }
          },
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
        ),
      ],
    );
  }
}
