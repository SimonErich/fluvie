import 'package:flutter/widgets.dart';
import 'package:fluvie/fluvie.dart' show VideoSize;
import 'package:fluvie_editor/src/document/editor_command.dart';
import 'package:fluvie_editor/src/widgets/math_number_input.dart';
import 'package:obers_ui/obers_ui.dart';

/// The exact-value transform fields: x/y/w/h in canvas pixels, rotation in
/// degrees, opacity 0..1. Each commit is one `SetTransformsCommand`, so
/// each field edit is one undo step.
final class TransformSection extends StatelessWidget {
  /// Edits [id]'s [transform] JSON against the [canvas] size.
  const TransformSection({
    required this.id,
    required this.transform,
    required this.canvas,
    required this.onCommand,
    super.key,
  });

  /// The element being placed.
  final String id;

  /// The element's current `transform` JSON.
  final Map<String, Object?> transform;

  /// The deck's canvas size (fraction-to-pixel context).
  final VideoSize canvas;

  /// Receives the transform commands.
  final void Function(EditorCommand command) onCommand;

  double _fraction(String key, double fallback) =>
      transform[key] is num ? (transform[key]! as num).toDouble() : fallback;

  void _patch(String key, Object? value) {
    final next = {...transform};
    if (value == null) {
      next.remove(key);
    } else {
      next[key] = value;
    }
    onCommand(SetTransformsCommand(transforms: {id: next}));
  }

  @override
  Widget build(BuildContext context) {
    final width = canvas.width.toDouble();
    final height = canvas.height.toDouble();
    final sized = transform['w'] is num && transform['h'] is num;
    return OiPropertyGrid(
      properties: [
        OiPropertyRow(
          label: 'X',
          editor: MathNumberInput(
            label: '',
            value: _fraction('x', 0.5) * width,
            onChanged: (next) => _patch('x', next / width),
          ),
        ),
        OiPropertyRow(
          label: 'Y',
          editor: MathNumberInput(
            label: '',
            value: _fraction('y', 0.5) * height,
            onChanged: (next) => _patch('y', next / height),
          ),
        ),
        if (sized) ...[
          OiPropertyRow(
            label: 'W',
            editor: MathNumberInput(
              label: '',
              value: _fraction('w', 0) * width,
              min: 1,
              onChanged: (next) => _patch('w', next / width),
            ),
          ),
          OiPropertyRow(
            label: 'H',
            editor: MathNumberInput(
              label: '',
              value: _fraction('h', 0) * height,
              min: 1,
              onChanged: (next) => _patch('h', next / height),
            ),
          ),
        ],
        OiPropertyRow(
          label: 'Angle',
          editor: MathNumberInput(
            label: '',
            value: _fraction('rotation', 0),
            onChanged: (next) => _patch('rotation', next == 0 ? null : next),
          ),
        ),
        OiPropertyRow(
          label: 'Opacity',
          editor: MathNumberInput(
            label: '',
            value: _fraction('opacity', 1),
            min: 0,
            max: 1,
            step: 0.05,
            decimals: 2,
            onChanged: (next) => _patch('opacity', next == 1 ? null : next),
          ),
        ),
      ],
    );
  }
}

/// The deck's slide size, edited as whole pixels.
final class SlideSizeSection extends StatelessWidget {
  /// Edits [width] x [height]; commits land in [onChanged] together.
  const SlideSizeSection({
    required this.width,
    required this.height,
    required this.onChanged,
    super.key,
  });

  /// The current canvas width in pixels.
  final double width;

  /// The current canvas height in pixels.
  final double height;

  /// Receives the new size.
  final void Function(double width, double height) onChanged;

  @override
  Widget build(BuildContext context) => OiPropertyGrid(
    properties: [
      OiPropertyRow(
        label: 'W',
        editor: MathNumberInput(
          label: '',
          value: width,
          min: 16,
          decimals: 0,
          onChanged: (next) => onChanged(next, height),
        ),
      ),
      OiPropertyRow(
        label: 'H',
        editor: MathNumberInput(
          label: '',
          value: height,
          min: 16,
          decimals: 0,
          onChanged: (next) => onChanged(width, next),
        ),
      ),
    ],
  );
}
