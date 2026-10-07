import 'package:flutter/widgets.dart';
import 'package:fluvie/fluvie.dart' show encodeColor;
import 'package:fluvie_editor/src/inspector/background_gradient.dart';
import 'package:fluvie_editor/src/inspector/inspector_text_field.dart';
import 'package:fluvie_editor/src/theme/token_color_scope.dart';
import 'package:fluvie_editor/src/widgets/color_field.dart';
import 'package:fluvie_editor/src/widgets/gradient_editor/gradient_editor.dart';
import 'package:fluvie_editor/src/widgets/gradient_editor/gradient_editor_value.dart';
import 'package:obers_ui/obers_ui.dart';

/// The nothing-selected background section: pick a kind, then edit the
/// fields that kind reads. Every change is one scene patch. The gradient
/// kinds edit through the gradient editor: stop drags write the spec's
/// `stops` offsets (elided while every stop sits at its even-spacing value)
/// and the angle writes as `begin`/`end`.
final class BackgroundEditor extends StatelessWidget {
  /// Edits [background] (the scene's JSON, or null for none); patches land
  /// in [onPatch] as the whole new background object (null clears it).
  const BackgroundEditor({
    required this.background,
    required this.onPatch,
    this.colors = TokenColorScope.none,
    super.key,
  });

  /// The scene's current `background` JSON, or null.
  final Map<String, Object?>? background;

  /// The theme palette and session recents for the color fields.
  final TokenColorScope colors;

  /// Receives the whole new background (null removes it); its `mergeGroup`
  /// coalesces picker streams.
  final void Function(Map<String, Object?>? background, {String? mergeGroup}) onPatch;

  static const List<String> _kinds = [
    'none',
    'color',
    'gradient',
    'radial',
    'image',
    'video',
    'noise',
    'vhs',
  ];

  String get _kind => background?['kind'] as String? ?? 'none';

  void _setKind(String kind) => onPatch(switch (kind) {
    'none' => null,
    'color' => {'kind': 'color', 'color': '#101018'},
    'gradient' || 'radial' => {
      'kind': kind,
      'colors': ['#101018', '#2D3436'],
    },
    'image' || 'video' => {'kind': kind, 'source': ''},
    _ => {'kind': kind},
  });

  void _patchKey(String key, Object? value, {String? mergeGroup}) =>
      onPatch({...?background, key: value}, mergeGroup: mergeGroup);

  /// The selected stop's color field: theme swatches bind `{"token": ...}`
  /// into the colors list; literal picks stream merge-grouped per stop.
  Widget _stopColorEditor(BuildContext context, int index, GradientEditorStop stop) {
    final raw = background?['colors'];
    final entry = raw is List && index < raw.length ? raw[index] : null;
    List<Object?> withStop(Object? value) =>
        [...raw is List ? raw as List<Object?> : const <Object?>[]]..[index] = value;
    return ColorField(
      label: 'Stop color',
      color: stop.color,
      boundToken: TokenColorScope.boundTokenOf(entry),
      tokens: colors.tokens,
      recents: colors.recents,
      onCommitted: colors.onPicked,
      onTokenSelected: colors.tokens.isEmpty
          ? null
          : (name) => _patchKey('colors', withStop({'token': name})),
      onChanged: (next) =>
          _patchKey('colors', withStop(encodeColor(next)), mergeGroup: 'bg-stop-$index'),
    );
  }

  @override
  Widget build(BuildContext context) {
    final kind = _kind;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        OiPropertyGrid(
          properties: [
            OiPropertyRow(
              label: 'Kind',
              editor: OiSelect<String>(
                value: kind,
                options: [for (final name in _kinds) OiSelectOption(value: name, label: name)],
                onChanged: (next) {
                  if (next != null) _setKind(next);
                },
              ),
            ),
            if (kind == 'color')
              OiPropertyRow(
                label: 'Color',
                editor: ColorField(
                  label: 'Background color',
                  color: colors.resolve(background?['color'], const Color(0xFF101018)),
                  boundToken: TokenColorScope.boundTokenOf(background?['color']),
                  tokens: colors.tokens,
                  recents: colors.recents,
                  onCommitted: colors.onPicked,
                  onTokenSelected: colors.tokens.isEmpty
                      ? null
                      : (name) => _patchKey('color', {'token': name}),
                  onChanged: (next) =>
                      _patchKey('color', encodeColor(next), mergeGroup: 'bg-color'),
                ),
              ),
            if (kind == 'image' || kind == 'video')
              OiPropertyRow(
                label: 'Source',
                editor: InspectorTextField(
                  value: background?['source'] as String? ?? '',
                  onChanged: (next) => _patchKey('source', next),
                ),
              ),
          ],
        ),
        if (kind == 'gradient' || kind == 'radial')
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: GradientEditor(
              value: gradientValueOf(background!, colors),
              // The Kind select above already flips gradient and radial.
              showKind: false,
              stopColorEditor: _stopColorEditor,
              onChanged: (next) => onPatch(gradientBackgroundJson(next, background!, colors)),
            ),
          ),
      ],
    );
  }
}
