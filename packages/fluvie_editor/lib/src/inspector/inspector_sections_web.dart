part of 'inspector_sections.dart';

// The rasterized web surfaces: Mermaid diagrams and the WebView/Html pair,
// whose shared shape is a capture viewport in logical pixels.

List<OiPropertyRow> _mermaidRows(Map<String, Object?> element, ElementPatch patch) {
  final theme = element['theme'] as String? ?? 'default';
  return [
    _selectRow(
      'Theme',
      key: const ValueKey('style-mermaid-theme'),
      value: theme,
      options: const ['default', 'dark', 'light'],
      onPicked: (next) {
        if (next != theme) patch({'theme': next == 'default' ? null : next});
      },
    ),
    _fitRow(element, patch, fallback: 'contain'),
  ];
}

List<OiPropertyRow> _webViewRows(Map<String, Object?> element, ElementPatch patch) => [
  // The spec rejects anything but an absolute http(s) URL, so an invalid
  // commit is dropped instead of dispatched.
  OiPropertyRow(
    label: 'URL',
    editor: InspectorTextField(
      value: element['uri'] as String? ?? '',
      onChanged: (next) {
        final uri = Uri.tryParse(next);
        if (uri == null || !uri.isAbsolute) return;
        if (uri.scheme != 'http' && uri.scheme != 'https') return;
        patch({'uri': next});
      },
    ),
  ),
  ..._viewportRows(element, patch),
];

List<OiPropertyRow> _viewportRows(Map<String, Object?> element, ElementPatch patch) => [
  _viewportSideRow(element, patch, 'W', 'width'),
  _viewportSideRow(element, patch, 'H', 'height'),
];

OiPropertyRow _viewportSideRow(
  Map<String, Object?> element,
  ElementPatch patch,
  String label,
  String side,
) {
  final viewport = element['viewport'] is Map<String, Object?>
      ? element['viewport']! as Map<String, Object?>
      : const <String, Object?>{};
  return OiPropertyRow(
    label: label,
    editor: MathNumberInput(
      label: '',
      value: viewport[side] is num ? (viewport[side]! as num).toDouble() : 0,
      min: 1,
      decimals: 0,
      onChanged: (next) => patch({
        'viewport': {...viewport, side: next.round()},
      }),
    ),
  );
}
