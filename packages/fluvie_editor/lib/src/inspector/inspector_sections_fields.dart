part of 'inspector_sections.dart';

// The shared row builders every per-type section composes: a themed color
// field, numeric and integer inputs, a switch, plain and validated text,
// spec-time strings, and a string select.

OiPropertyRow _colorRow(
  Map<String, Object?> element,
  ElementPatch patch,
  TokenColorScope colors, {
  String key = 'color',
  Color fallback = const Color(0xFF6C5CE7),
}) => OiPropertyRow(
  label: 'Color',
  editor: ColorField(
    label: 'Color',
    color: colors.resolve(element[key], fallback),
    boundToken: TokenColorScope.boundTokenOf(element[key]),
    tokens: colors.tokens,
    recents: colors.recents,
    onCommitted: colors.onPicked,
    onTokenSelected: colors.tokens.isEmpty
        ? null
        : (name) => patch({
            key: {'token': name},
          }),
    onChanged: (next) => patch({key: encodeColor(next)}, mergeGroup: 'pick-$key'),
  ),
);

OiPropertyRow _numberRow(
  Map<String, Object?> element,
  ElementPatch patch,
  String label,
  String key,
  double fallback, {
  double? min,
  double? max,
  double step = 1,
  int decimals = 1,
}) => OiPropertyRow(
  label: label,
  editor: MathNumberInput(
    label: '',
    value: element[key] is num ? (element[key]! as num).toDouble() : fallback,
    min: min,
    max: max,
    step: step,
    decimals: decimals,
    onChanged: (next) => patch({key: next}),
  ),
);

/// An integer-valued number row: commits land as `int` (spec fields like
/// `count` and viewport sides reject fractions).
OiPropertyRow _intRow(
  Map<String, Object?> element,
  ElementPatch patch,
  String label,
  String key,
  int fallback, {
  double? min,
}) => OiPropertyRow(
  label: label,
  editor: MathNumberInput(
    label: '',
    value: element[key] is num ? (element[key]! as num).toDouble() : fallback.toDouble(),
    min: min,
    decimals: 0,
    onChanged: (next) => patch({key: next.round()}),
  ),
);

OiPropertyRow _switchRow(
  Map<String, Object?> element,
  ElementPatch patch,
  String label,
  String key, {
  bool fallback = false,
}) => OiPropertyRow(
  label: label,
  editor: OiSwitch(
    value: element[key] is bool ? element[key]! as bool : fallback,
    onChanged: (next) => patch({key: next}),
  ),
);

/// A plain string row; with [emptyClears], committing an empty value
/// removes the key so the element falls back to its widget default.
OiPropertyRow _textRow(
  Map<String, Object?> element,
  ElementPatch patch,
  String label,
  String key, {
  String? placeholder,
  int? maxLines = 1,
  bool emptyClears = false,
}) => OiPropertyRow(
  label: label,
  editor: InspectorTextField(
    value: element[key] as String? ?? '',
    placeholder: placeholder,
    maxLines: maxLines,
    onChanged: (next) => patch({key: emptyClears && next.isEmpty ? null : next}),
  ),
);

/// A spec-time row (`2s`, `30f`, `0.3r`): an invalid commit is dropped, an
/// empty one removes the key.
OiPropertyRow _timeRow(
  Map<String, Object?> element,
  ElementPatch patch,
  String label,
  String key, {
  String? placeholder,
}) => OiPropertyRow(
  label: label,
  editor: InspectorTextField(
    value: element[key] as String? ?? '',
    placeholder: placeholder,
    onChanged: (next) {
      if (next.isEmpty) return patch({key: null});
      try {
        decodeTime(next);
      } on FluvieSpecError {
        return;
      }
      patch({key: next});
    },
  ),
);

OiPropertyRow _selectRow(
  String label, {
  required Key key,
  required String? value,
  required List<String> options,
  required ValueChanged<String> onPicked,
  bool enabled = true,
}) => OiPropertyRow(
  label: label,
  editor: OiSelect<String>(
    key: key,
    value: value,
    enabled: enabled,
    options: [for (final option in options) OiSelectOption(value: option, label: option)],
    onChanged: (next) {
      if (next != null) onPicked(next);
    },
  ),
);

OiPropertyRow _fitRow(
  Map<String, Object?> element,
  ElementPatch patch, {
  String fallback = 'cover',
}) => _selectRow(
  'Fit',
  key: const ValueKey('style-fit'),
  value: element['fit'] as String? ?? fallback,
  options: const ['cover', 'contain', 'fill', 'fitWidth', 'fitHeight'],
  onPicked: (next) => patch({'fit': next}),
);
