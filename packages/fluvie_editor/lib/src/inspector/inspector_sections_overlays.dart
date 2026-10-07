part of 'inspector_sections.dart';

// The overlay and wrapper types: audio bars, the broadcast pair, the
// snapshot wrappers, and the annotation wrappers. Color fallbacks mirror
// each widget's own default.

List<OiPropertyRow> _barsRows(Map<String, Object?> element, ElementPatch patch) => [
  _intRow(element, patch, 'Count', 'count', 24, min: 1),
  _selectRow(
    'Band',
    key: const ValueKey('style-band'),
    value: element['band'] as String? ?? 'bass',
    options: const ['bass', 'mid', 'treble'],
    onPicked: (next) => patch({'band': next}),
  ),
  _numberRow(element, patch, 'Gain', 'gain', 1, min: 0),
];

List<OiPropertyRow> _lowerThirdRows(
  Map<String, Object?> element,
  ElementPatch patch,
  TokenColorScope colors,
) => [
  _textRow(element, patch, 'Name', 'name'),
  _textRow(element, patch, 'Title', 'title', emptyClears: true),
  _colorRow(element, patch, colors, fallback: const Color(0xCC101418)),
];

List<OiPropertyRow> _titleCardRows(
  Map<String, Object?> element,
  ElementPatch patch,
  TokenColorScope colors,
) => [
  _textRow(element, patch, 'Title', 'title'),
  _textRow(element, patch, 'Subtitle', 'subtitle', emptyClears: true),
  _colorRow(element, patch, colors, fallback: const Color(0xFFFFFFFF)),
];

List<OiPropertyRow> _deviceFrameRows(Map<String, Object?> element, ElementPatch patch) {
  final variant = element['variant'] as String?;
  return [
    // A notch belongs to a phone and a url to a browser; switching the
    // variant scrubs the keys the spec would reject on the new one.
    _selectRow(
      'Variant',
      key: const ValueKey('style-variant'),
      value: variant,
      options: const ['phone', 'browser', 'tablet'],
      onPicked: (next) {
        if (next == variant) return;
        patch({
          'variant': next,
          if (next != 'phone') 'notch': null,
          if (next != 'browser') 'url': null,
        });
      },
    ),
    if (variant == 'phone') _switchRow(element, patch, 'Notch', 'notch', fallback: true),
    if (variant == 'browser') _textRow(element, patch, 'URL', 'url', emptyClears: true),
  ];
}

List<OiPropertyRow> _calloutRows(
  Map<String, Object?> element,
  ElementPatch patch,
  TokenColorScope colors,
) => [
  _textRow(element, patch, 'Label', 'label'),
  _colorRow(element, patch, colors),
];

List<OiPropertyRow> _spotlightRows(
  Map<String, Object?> element,
  ElementPatch patch,
  TokenColorScope colors,
) => [
  _colorRow(element, patch, colors, fallback: const Color(0xB3000000)),
  _timeRow(element, patch, 'Reveal', 'reveal'),
];
