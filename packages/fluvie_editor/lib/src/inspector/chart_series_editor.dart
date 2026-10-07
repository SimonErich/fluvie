import 'package:flutter/widgets.dart';
import 'package:fluvie/fluvie.dart' show decodeColor, encodeColor;
import 'package:fluvie_editor/src/inspector/chart_map_grid.dart';
import 'package:fluvie_editor/src/inspector/inspector_sections.dart';
import 'package:fluvie_editor/src/inspector/inspector_text_field.dart';
import 'package:fluvie_editor/src/widgets/color_field.dart';
import 'package:fluvie_editor/src/widgets/editor_tip.dart';
import 'package:obers_ui/obers_ui.dart';

/// The editor over a `Chart`'s `series` form: per series its name, its
/// color, and — for a data-map series — the same grid the map form edits
/// with. Series add (line and area only; scatter takes exactly one) and
/// remove down to one, and an empty rename drops.
final class ChartSeriesEditor extends StatelessWidget {
  /// Edits the `series` of [element]; every change lands in [patch].
  const ChartSeriesEditor({required this.element, required this.patch, super.key});

  /// The chart element JSON.
  final Map<String, Object?> element;

  /// Applies a content patch to the element.
  final ElementPatch patch;

  List<Map<String, Object?>> get _series => [
    for (final entry in element['series']! as List<Object?>) entry! as Map<String, Object?>,
  ];

  /// Whether the variant reads more than one series (line and area do,
  /// scatter takes exactly one).
  bool get _multiSeries => element['variant'] == 'line' || element['variant'] == 'area';

  @override
  Widget build(BuildContext context) {
    final series = _series;
    return Column(
      key: const ValueKey('chart-series-editor'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < series.length; i++) _seriesBlock(context, series, i),
        if (_multiSeries)
          Row(
            children: [
              EditorTip(
                message: 'Add series',
                child: OiIconButton(
                  icon: OiIcons.plus,
                  semanticLabel: 'Add series',
                  size: OiButtonSize.small,
                  onTap: () => _write([
                    ...series,
                    {
                      'name': 'Series ${series.length + 1}',
                      'data': {'A': 0},
                    },
                  ]),
                ),
              ),
            ],
          ),
      ],
    );
  }

  Widget _seriesBlock(BuildContext context, List<Map<String, Object?>> series, int index) {
    final one = series[index];
    final data = one['data'];
    return Padding(
      key: ValueKey('chart-series-$index'),
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: InspectorTextField(
                  key: ValueKey('series-name-$index'),
                  value: (one['name'] as String?) ?? '',
                  onChanged: (next) {
                    if (next.isEmpty) return;
                    _replace(series, index, {...one, 'name': next});
                  },
                ),
              ),
              const SizedBox(width: 4),
              ColorField(
                label: 'Series color',
                color: _colorOf(one['color']),
                onChanged: (next) => _replace(series, index, {
                  ...one,
                  'color': encodeColor(next),
                }, mergeGroup: 'series-color-$index'),
              ),
              EditorTip(
                message: 'Remove series',
                child: OiIconButton(
                  icon: OiIcons.trash,
                  semanticLabel: 'Remove series $index',
                  size: OiButtonSize.small,
                  onTap: series.length <= 1 ? null : () => _write([...series]..removeAt(index)),
                ),
              ),
            ],
          ),
          if (data is Map<String, Object?>)
            Padding(
              padding: const EdgeInsets.only(left: 8, top: 4),
              child: ChartMapGrid(
                key: const ValueKey('chart-map-grid'),
                data: data,
                onChanged: (next, {mergeGroup}) =>
                    _replace(series, index, {...one, 'data': next}, mergeGroup: mergeGroup),
              ),
            )
          else
            OiLabel.small('points series (raw JSON)', color: context.colors.textSubtle),
        ],
      ),
    );
  }

  Color _colorOf(Object? raw) {
    if (raw == null) return const Color(0xFF6C5CE7);
    try {
      return decodeColor(raw);
    } on Object {
      return const Color(0xFF6C5CE7);
    }
  }

  void _replace(
    List<Map<String, Object?>> series,
    int index,
    Map<String, Object?> one, {
    String? mergeGroup,
  }) => _write([...series]..[index] = one, mergeGroup: mergeGroup);

  void _write(List<Map<String, Object?>> series, {String? mergeGroup}) =>
      patch({'series': series}, mergeGroup: mergeGroup);
}
