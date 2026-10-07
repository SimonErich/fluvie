import 'package:flutter/widgets.dart';
import 'package:fluvie_editor/src/inspector/chart_data_forms.dart';
import 'package:fluvie_editor/src/inspector/chart_map_grid.dart';
import 'package:fluvie_editor/src/inspector/chart_points_editor.dart';
import 'package:fluvie_editor/src/inspector/chart_series_editor.dart';
import 'package:fluvie_editor/src/inspector/inspector_sections.dart';
import 'package:obers_ui/obers_ui.dart';

/// The chart data editor: the map grid, the series editor, or the points
/// editor — whichever form the data holds — plus, where the variant reads
/// more than one form, a form switch that converts honestly
/// ([convertChartForm]) and refuses with a visible note where the
/// conversion would lose data.
final class ChartDataSection extends StatefulWidget {
  /// Edits the data of [element]; every change lands in [patch].
  const ChartDataSection({required this.element, required this.patch, super.key});

  /// The chart element JSON.
  final Map<String, Object?> element;

  /// Applies a content patch to the element.
  final ElementPatch patch;

  @override
  State<ChartDataSection> createState() => _ChartDataSectionState();
}

final class _ChartDataSectionState extends State<ChartDataSection> {
  String? _note;

  @override
  Widget build(BuildContext context) {
    final element = widget.element;
    final form = chartDataFormOf(element);
    final forms = chartFormsFor(element['variant'] as String?);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (forms.length > 1) ...[
          _formSelect(form, forms),
          const SizedBox(height: 4),
        ],
        if (_note case final String note)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: OiLabel.small(
              note,
              key: const ValueKey('chart-form-note'),
              color: context.colors.warning.base,
            ),
          ),
        switch (form) {
          ChartDataForm.map => ChartMapGrid(
            key: const ValueKey('chart-data-grid'),
            data: element['data'] is Map<String, Object?>
                ? element['data']! as Map<String, Object?>
                : const {},
            onChanged: (next, {mergeGroup}) => widget.patch({'data': next}, mergeGroup: mergeGroup),
          ),
          ChartDataForm.series => ChartSeriesEditor(element: element, patch: widget.patch),
          ChartDataForm.points => ChartPointsEditor(element: element, patch: widget.patch),
        },
      ],
    );
  }

  Widget _formSelect(ChartDataForm form, List<ChartDataForm> forms) => OiSelect<String>(
    key: const ValueKey('chart-data-form'),
    value: form.name,
    options: [for (final option in forms) OiSelectOption(value: option.name, label: option.name)],
    onChanged: (next) {
      if (next == null || next == form.name) return;
      final picked = ChartDataForm.values.byName(next);
      switch (convertChartForm(widget.element, picked)) {
        case ChartFormPatch(:final patch):
          setState(() => _note = null);
          widget.patch(patch);
        case ChartFormRefusal(:final note):
          setState(() => _note = note);
      }
    },
  );
}
