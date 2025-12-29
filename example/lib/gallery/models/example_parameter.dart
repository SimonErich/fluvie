import 'package:flutter/material.dart';

/// Type of parameter control widget
enum ParameterType {
  /// Numeric slider with min/max bounds
  slider,

  /// Color picker widget
  colorPicker,

  /// Dropdown with predefined options
  dropdown,

  /// Text input field
  text,

  /// Boolean checkbox
  checkbox,
}

/// Defines an adjustable parameter for an interactive example
class ExampleParameter {
  /// Unique identifier for this parameter
  final String id;

  /// Display label shown in the UI
  final String label;

  /// Description explaining what this parameter does
  final String description;

  /// Type of control widget to display
  final ParameterType type;

  /// Default value for this parameter
  final dynamic defaultValue;

  /// Minimum value (for slider type)
  final dynamic minValue;

  /// Maximum value (for slider type)
  final dynamic maxValue;

  /// List of options (for dropdown type)
  final List<DropdownOption>? options;

  /// Number of decimal places for slider (default: 0 for integers)
  final int? divisions;

  const ExampleParameter({
    required this.id,
    required this.label,
    required this.description,
    required this.type,
    required this.defaultValue,
    this.minValue,
    this.maxValue,
    this.options,
    this.divisions,
  });

  /// Create a slider parameter
  factory ExampleParameter.slider({
    required String id,
    required String label,
    required String description,
    required num defaultValue,
    required num minValue,
    required num maxValue,
    int? divisions,
  }) {
    return ExampleParameter(
      id: id,
      label: label,
      description: description,
      type: ParameterType.slider,
      defaultValue: defaultValue,
      minValue: minValue,
      maxValue: maxValue,
      divisions: divisions,
    );
  }

  /// Create a color picker parameter
  factory ExampleParameter.color({
    required String id,
    required String label,
    required String description,
    required Color defaultValue,
  }) {
    return ExampleParameter(
      id: id,
      label: label,
      description: description,
      type: ParameterType.colorPicker,
      defaultValue: defaultValue,
    );
  }

  /// Create a dropdown parameter
  factory ExampleParameter.dropdown({
    required String id,
    required String label,
    required String description,
    required String defaultValue,
    required List<DropdownOption> options,
  }) {
    return ExampleParameter(
      id: id,
      label: label,
      description: description,
      type: ParameterType.dropdown,
      defaultValue: defaultValue,
      options: options,
    );
  }

  /// Create a text input parameter
  factory ExampleParameter.text({
    required String id,
    required String label,
    required String description,
    required String defaultValue,
  }) {
    return ExampleParameter(
      id: id,
      label: label,
      description: description,
      type: ParameterType.text,
      defaultValue: defaultValue,
    );
  }

  /// Create a checkbox parameter
  factory ExampleParameter.checkbox({
    required String id,
    required String label,
    required String description,
    required bool defaultValue,
  }) {
    return ExampleParameter(
      id: id,
      label: label,
      description: description,
      type: ParameterType.checkbox,
      defaultValue: defaultValue,
    );
  }
}

/// Option for dropdown parameters
class DropdownOption {
  /// Value of this option
  final String value;

  /// Display label for this option
  final String label;

  /// Optional description
  final String? description;

  const DropdownOption({
    required this.value,
    required this.label,
    this.description,
  });
}
