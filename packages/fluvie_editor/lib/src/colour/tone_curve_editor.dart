import 'package:flutter/widgets.dart';
import 'package:fluvie/fluvie.dart' show ToneCurve;
import 'package:fluvie_editor/src/widgets/math_number_input.dart';
import 'package:obers_ui/obers_ui.dart';

part 'tone_curve_painter.dart';

/// Per-channel tone-curve authoring. Drag points or use the numeric fields;
/// a drag commits once on release so one undo restores the whole gesture.
final class ToneCurveEditor extends StatefulWidget {
  /// Edits the curves object carried by a curves effect.
  const ToneCurveEditor({required this.curves, required this.onChanged, super.key});

  /// Authored channels; missing channels use the identity curve.
  final Map<String, Object?> curves;

  /// Commits the edited channels.
  final ValueChanged<Map<String, Object?>> onChanged;

  @override
  State<ToneCurveEditor> createState() => _ToneCurveEditorState();
}

final class _ToneCurveEditorState extends State<ToneCurveEditor> {
  String _channel = 'master';
  int _selected = 0;
  List<Offset>? _drag;

  List<Offset> get _points =>
      _drag ??
      [
        for (final point
            in (widget.curves[_channel] as List? ??
                const [
                  [0, 0],
                  [1, 1],
                ]))
          Offset(((point as List)[0] as num).toDouble(), (point[1] as num).toDouble()),
      ];

  void _commit(List<Offset> points) => widget.onChanged({
    ...widget.curves,
    _channel: [
      for (final point in points) [point.dx, point.dy],
    ],
  });

  List<Offset> _moved(Offset value) {
    final points = [..._points];
    final left = _selected == 0 ? 0.0 : points[_selected - 1].dx + 0.001;
    final right = _selected == points.length - 1 ? 1.0 : points[_selected + 1].dx - 0.001;
    points[_selected] = Offset(value.dx.clamp(left, right), value.dy.clamp(0, 1));
    return points;
  }

  @override
  Widget build(BuildContext context) {
    final points = _points;
    _selected = _selected.clamp(0, points.length - 1);
    final selected = points[_selected];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OiSelect<String>(
          key: const ValueKey('curve-channel'),
          value: _channel,
          options: [
            for (final channel in ['master', 'red', 'green', 'blue'])
              OiSelectOption(value: channel, label: channel),
          ],
          onChanged: (value) {
            if (value != null) {
              setState(() {
                _channel = value;
                _selected = 0;
              });
            }
          },
        ),
        const SizedBox(height: 8),
        Semantics(
          label: 'Tone curve. Select a point to edit its input and output below.',
          child: AspectRatio(
            aspectRatio: 1.6,
            child: LayoutBuilder(
              builder: (context, box) {
                Offset normalized(Offset p) =>
                    Offset(p.dx / box.maxWidth, 1 - p.dy / box.maxHeight);
                return GestureDetector(
                  key: const ValueKey('curve-plot'),
                  onPanStart: (details) {
                    final p = normalized(details.localPosition);
                    var nearest = 0;
                    for (var i = 1; i < points.length; i++) {
                      if ((points[i] - p).distance < (points[nearest] - p).distance) nearest = i;
                    }
                    setState(() {
                      _selected = nearest;
                      _drag = [...points];
                    });
                  },
                  onPanUpdate: (details) =>
                      setState(() => _drag = _moved(normalized(details.localPosition))),
                  onPanEnd: (_) {
                    final next = _drag;
                    setState(() => _drag = null);
                    if (next != null) _commit(next);
                  },
                  onPanCancel: () => setState(() => _drag = null),
                  child: CustomPaint(
                    painter: _CurvePainter(
                      points,
                      _selected,
                      context.colors.accent.base,
                      context.colors.borderSubtle,
                      context.colors.surfaceSubtle,
                    ),
                    child: const SizedBox.expand(),
                  ),
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 8),
        OiSelect<int>(
          key: const ValueKey('curve-point'),
          value: _selected,
          options: [
            for (var i = 0; i < points.length; i++)
              OiSelectOption(value: i, label: 'Point ${i + 1}'),
          ],
          onChanged: (value) {
            if (value != null) setState(() => _selected = value);
          },
        ),
        MathNumberInput(
          key: const ValueKey('curve-input'),
          label: 'Input',
          value: selected.dx,
          min: _selected == 0 ? 0 : points[_selected - 1].dx + 0.001,
          max: _selected == points.length - 1 ? 1 : points[_selected + 1].dx - 0.001,
          decimals: 3,
          step: 0.01,
          onChanged: (x) => _commit(_moved(Offset(x, selected.dy))),
        ),
        MathNumberInput(
          key: const ValueKey('curve-output'),
          label: 'Output',
          value: selected.dy,
          min: 0,
          max: 1,
          decimals: 3,
          step: 0.01,
          onChanged: (y) => _commit(_moved(Offset(selected.dx, y))),
        ),
        Wrap(
          spacing: 6,
          children: [
            OiButton.ghost(
              label: 'Add point',
              onTap: points.length >= 64
                  ? null
                  : () {
                      var gap = 0;
                      for (var i = 1; i < points.length - 1; i++) {
                        if (points[i + 1].dx - points[i].dx > points[gap + 1].dx - points[gap].dx) {
                          gap = i;
                        }
                      }
                      final x = (points[gap].dx + points[gap + 1].dx) / 2;
                      final curve = ToneCurve.fromPoints([for (final p in points) (p.dx, p.dy)]);
                      final next = [...points]..insert(gap + 1, Offset(x, curve.at(x)));
                      setState(() => _selected = gap + 1);
                      _commit(next);
                    },
            ),
            OiButton.ghost(
              label: 'Remove point',
              onTap: points.length <= 2
                  ? null
                  : () {
                      final next = [...points]..removeAt(_selected);
                      _commit(next);
                    },
            ),
            OiButton.ghost(
              label: 'Reset curve',
              onTap: () => _commit(const [Offset.zero, Offset(1, 1)]),
            ),
          ],
        ),
      ],
    );
  }
}
