import 'package:flutter/widgets.dart';
import 'package:fluvie/fluvie.dart' show FluvieSpecError, decodeTime, encodeColor;
import 'package:fluvie_editor/src/inspector/inspector_text_field.dart';
import 'package:fluvie_editor/src/theme/token_color_scope.dart';
import 'package:fluvie_editor/src/widgets/color_field.dart';
import 'package:fluvie_editor/src/widgets/math_number_input.dart';
import 'package:obers_ui/obers_ui.dart';

part 'inspector_sections_chart.dart';
part 'inspector_sections_fields.dart';
part 'inspector_sections_overlays.dart';
part 'inspector_sections_rich.dart';
part 'inspector_sections_web.dart';

/// Applies an element patch: content keys merge over the element, a null
/// value removes its key, and a non-null [mergeGroup] coalesces a stream
/// (a picker drag) into one step.
typedef ElementPatch = void Function(Map<String, Object?> patch, {String? mergeGroup});

/// The per-type style rows of the inspector — registered by element type,
/// so a new codec brings its section here and nowhere else. [colors]
/// carries the theme palette and session recents into every color field.
/// [tokenStyle] supplies inherited text values without materializing a binding.
/// A `Group` returns no rows: it edits through the Block section.
List<OiPropertyRow> styleRowsFor(
  Map<String, Object?> element,
  ElementPatch patch, {
  TokenColorScope colors = TokenColorScope.none,
  TextStyle? tokenStyle,
}) => switch (element['type']) {
  'Text' => _textStyleRows(element, patch, colors, tokenStyle),
  'SplitText' => [
    ..._textStyleRows(element, patch, colors, tokenStyle),
    OiPropertyRow(
      label: 'Split by',
      editor: OiSelect<String>(
        value: element['by'] as String? ?? 'word',
        options: const [
          OiSelectOption(value: 'character', label: 'Character'),
          OiSelectOption(value: 'word', label: 'Word'),
          OiSelectOption(value: 'line', label: 'Line'),
        ],
        onChanged: (value) {
          if (value != null) patch({'by': value});
        },
      ),
    ),
  ],
  'Box' => [_colorRow(element, patch, colors)],
  'Shape' => [
    _colorRow(element, patch, colors),
    _numberRow(element, patch, 'Stroke', 'strokeWidth', 3, min: 0),
  ],
  'Arrow' => [
    _colorRow(element, patch, colors),
    _numberRow(element, patch, 'Stroke', 'strokeWidth', 3, min: 0),
    _numberRow(element, patch, 'Head', 'headLength', 16, min: 0),
  ],
  'Connector' => [
    _colorRow(element, patch, colors),
    _numberRow(element, patch, 'Stroke', 'strokeWidth', 2, min: 0),
    _switchRow(element, patch, 'Elbow', 'elbow'),
  ],
  'Image' => [
    _numberRow(element, patch, 'Radius', 'cornerRadius', 0, min: 0),
    _fitRow(element, patch),
  ],
  'Clip' => [
    _numberRow(element, patch, 'Volume', 'volume', 1, min: 0),
    _fitRow(element, patch),
  ],
  'Counter' => [
    _numberRow(element, patch, 'From', 'from', 0),
    _numberRow(element, patch, 'To', 'to', 100),
  ],
  'Typewriter' => _typewriterRows(element, patch),
  'Markdown' => _markdownRows(element, patch),
  'Terminal' => _terminalRows(element, patch),
  'Code' => _codeRows(element, patch),
  'Chart' => _chartRows(element, patch),
  'Mermaid' => _mermaidRows(element, patch),
  'WebView' => _webViewRows(element, patch),
  'Html' => _viewportRows(element, patch),
  'Bars' => _barsRows(element, patch),
  'LowerThird' => _lowerThirdRows(element, patch, colors),
  'TitleCard' => _titleCardRows(element, patch, colors),
  'Snapshot' => [_fitRow(element, patch, fallback: 'contain')],
  'DeviceFrame' => _deviceFrameRows(element, patch),
  'Callout' => _calloutRows(element, patch, colors),
  'Spotlight' => _spotlightRows(element, patch, colors),
  _ => const [],
};
