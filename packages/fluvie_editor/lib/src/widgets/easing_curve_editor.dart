import 'package:flutter/widgets.dart';
import 'package:fluvie/fluvie.dart' show decodeCurve, encodeCurve, namedEases;
import 'package:fluvie_editor/src/widgets/math_number_input.dart';
import 'package:obers_ui/obers_ui.dart';

part 'easing_curve_painter.dart';

/// A named-or-cubic easing editor shared by animations and effect segments.
/// Drags stay local until release; committing a gesture creates one undo step.
final class EasingCurveEditor extends StatefulWidget {
  /// Edits a serialized ease, defaulting to linear when unset.
  const EasingCurveEditor({required this.value, required this.onChanged, super.key});

  /// A named curve or `{'cubic': [x1, y1, x2, y2]}`.
  final Object? value;

  /// Receives the canonical named shape whenever it matches exactly.
  final ValueChanged<Object> onChanged;
  @override
  State<EasingCurveEditor> createState() => _EasingCurveEditorState();
}

final class _EasingCurveEditorState extends State<EasingCurveEditor> {
  List<double>? _draft;
  int _handle = 0;
  Curve get _curve => decodeCurve(widget.value ?? 'linear');
  List<double> get _points =>
      _draft ??
      switch (_curve) {
        final Cubic curve => [curve.a, curve.b, curve.c, curve.d],
        _ => [0, 0, 1, 1],
      };
  void _commit(List<double> p) => widget.onChanged(encodeCurve(Cubic(p[0], p[1], p[2], p[3])));
  @override
  Widget build(BuildContext context) {
    final points = _points;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OiSelect<String>(
          value: widget.value is String ? widget.value! as String : 'custom',
          options: [
            for (final name in namedEases.keys) OiSelectOption(value: name, label: name),
            if (widget.value is! String)
              const OiSelectOption(value: 'custom', label: 'Custom cubic'),
          ],
          onChanged: (name) {
            if (name != null && name != 'custom') widget.onChanged(name);
          },
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 130,
          child: LayoutBuilder(
            builder: (context, bounds) {
              Offset normalized(Offset p) => Offset(
                (p.dx / bounds.maxWidth).clamp(0, 1),
                (1 - p.dy / bounds.maxHeight).clamp(-1, 2),
              );
              return Semantics(
                label: 'Easing curve. Drag a control point or edit its coordinates below.',
                child: GestureDetector(
                  key: const ValueKey('easing-curve-plot'),
                  onPanStart: (event) {
                    final point = normalized(event.localPosition);
                    final first = Offset(points[0], points[1]);
                    final second = Offset(points[2], points[3]);
                    setState(() {
                      _handle = (point - first).distance <= (point - second).distance ? 0 : 2;
                      _draft = [...points];
                    });
                  },
                  onPanUpdate: (event) {
                    final point = normalized(event.localPosition);
                    setState(() {
                      _draft![_handle] = point.dx;
                      _draft![_handle + 1] = point.dy;
                    });
                  },
                  onPanEnd: (_) {
                    final next = _draft;
                    setState(() => _draft = null);
                    if (next != null) _commit(next);
                  },
                  onPanCancel: () => setState(() => _draft = null),
                  child: CustomPaint(
                    painter: _EasingPainter(
                      _draft == null ? _curve : Cubic(points[0], points[1], points[2], points[3]),
                      points,
                      context.colors.accent.base,
                      context.colors.borderSubtle,
                    ),
                    child: const SizedBox.expand(),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 6),
        for (var i = 0; i < 4; i++)
          MathNumberInput(
            label: const ['Control 1 X', 'Control 1 Y', 'Control 2 X', 'Control 2 Y'][i],
            key: ValueKey('easing-control-$i'),
            value: points[i],
            min: i.isEven ? 0 : -1,
            max: i.isEven ? 1 : 2,
            step: 0.01,
            decimals: 3,
            onChanged: (value) {
              final next = [...points]..[i] = value;
              _commit(next);
            },
          ),
      ],
    );
  }
}
