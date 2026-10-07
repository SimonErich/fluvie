part of 'inspector_sections.dart';

/// The chart variants the spec accepts, mirroring the Chart codec's list.
const List<String> _chartVariants = ['bar', 'pie', 'donut', 'line', 'area', 'scatter'];

// The variant select offers exactly the variants the current DATA FORM can
// feed (the codec's own families): the map form feeds every variant; the
// series form feeds line and area, plus scatter for a single series; the
// points form is scatter's alone. Changing the data form is the Data
// section's job (an honest conversion), so a variant switch never converts
// data. Leaving donut scrubs `innerRadius`, the one variant-owned knob.
List<OiPropertyRow> _chartRows(Map<String, Object?> element, ElementPatch patch) {
  final variant = element['variant'] as String?;
  final options = _variantOptions(element);
  return [
    _selectRow(
      'Variant',
      key: const ValueKey('style-variant'),
      value: variant,
      options: options,
      enabled: options.length > 1,
      onPicked: (next) {
        if (next == variant) return;
        patch({'variant': next, if (next != 'donut') 'innerRadius': null});
      },
    ),
    _timeRow(element, patch, 'Reveal', 'reveal', placeholder: '0.6r'),
    if (element['data'] is Map<String, Object?> && variant == 'donut')
      _numberRow(
        element,
        patch,
        'Inner',
        'innerRadius',
        0.6,
        min: 0,
        max: 1,
        step: 0.05,
        decimals: 2,
      ),
  ];
}

List<String> _variantOptions(Map<String, Object?> element) {
  final series = element['series'];
  if (series is List) {
    return ['line', 'area', if (series.length == 1) 'scatter'];
  }
  if (element['points'] is List) return const ['scatter'];
  return _chartVariants;
}
