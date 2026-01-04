import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../example_base.dart';
import '../models/example_parameter.dart';
import 'parameter_widgets/checkbox_parameter.dart';
import 'parameter_widgets/color_parameter.dart';
import 'parameter_widgets/dropdown_parameter.dart';
import 'parameter_widgets/slider_parameter.dart';
import 'parameter_widgets/text_parameter.dart';
import 'theme.dart';

/// Provider for parameter values
final parameterValuesProvider = StateProvider<Map<String, dynamic>>(
  (ref) => {},
);

/// Panel displaying parameter controls
class ControlsPanel extends ConsumerWidget {
  final InteractiveExample? example;

  const ControlsPanel({super.key, this.example});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (example == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.tune, size: 64, color: GalleryTheme.textTertiary),
            const SizedBox(height: 16),
            Text(
              'Select an example to see controls',
              style: GalleryTheme.textTheme.bodyLarge,
            ),
          ],
        ),
      );
    }

    final parameters = example!.parameters;
    final parameterValues = ref.watch(parameterValuesProvider);

    // Initialize parameter values if not set
    if (parameterValues.isEmpty && parameters.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(parameterValuesProvider.notifier).state =
            example!.defaultParameters;
      });
    }

    return Container(
      color: GalleryTheme.surfaceBackground,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Modern header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              ShaderMask(
                shaderCallback: (bounds) =>
                    GalleryTheme.primaryGradient.createShader(bounds),
                child: Text(
                  'Parameters',
                  style: GalleryTheme.textTheme.headlineMedium?.copyWith(
                    fontSize: 20,
                    color: Colors.white,
                  ),
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  gradient: GalleryTheme.accentGradient,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: GalleryTheme.glowEffect(
                    color: GalleryTheme.accentPink,
                    blurRadius: 10,
                  ),
                ),
                child: IconButton(
                  icon: const Icon(
                    Icons.refresh,
                    color: Colors.white,
                    size: 20,
                  ),
                  tooltip: 'Reset to defaults',
                  onPressed: () {
                    ref.read(parameterValuesProvider.notifier).state =
                        example!.defaultParameters;
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Parameter widgets
          Expanded(
            child: parameters.isEmpty
                ? Center(
                    child: Text(
                      'No adjustable parameters',
                      style: GalleryTheme.textTheme.bodyLarge,
                    ),
                  )
                : ListView.separated(
                    itemCount: parameters.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 20),
                    itemBuilder: (context, index) {
                      final parameter = parameters[index];
                      final value = parameterValues[parameter.id] ??
                          parameter.defaultValue;

                      return _buildParameterWidget(
                        context,
                        ref,
                        parameter,
                        value,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildParameterWidget(
    BuildContext context,
    WidgetRef ref,
    ExampleParameter parameter,
    dynamic value,
  ) {
    void updateValue(dynamic newValue) {
      final current = ref.read(parameterValuesProvider);
      ref.read(parameterValuesProvider.notifier).state = {
        ...current,
        parameter.id: newValue,
      };
    }

    switch (parameter.type) {
      case ParameterType.slider:
        return SliderParameterWidget(
          parameter: parameter,
          value: value as num,
          onChanged: updateValue,
        );

      case ParameterType.colorPicker:
        return ColorParameterWidget(
          parameter: parameter,
          value: value as Color,
          onChanged: updateValue,
        );

      case ParameterType.dropdown:
        return DropdownParameterWidget(
          parameter: parameter,
          value: value as String,
          onChanged: updateValue,
        );

      case ParameterType.text:
        return TextParameterWidget(
          parameter: parameter,
          value: value as String,
          onChanged: updateValue,
        );

      case ParameterType.checkbox:
        return CheckboxParameterWidget(
          parameter: parameter,
          value: value as bool,
          onChanged: updateValue,
        );
    }
  }
}
