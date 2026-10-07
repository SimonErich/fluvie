import 'package:flutter/widgets.dart';
import 'package:fluvie/fluvie.dart' show FrameSpan, KeyframedNumber, Time, decodeCurve, encodeCurve;
import 'package:fluvie_editor/src/document/editor_command.dart';
import 'package:fluvie_editor/src/document/editor_document.dart';
import 'package:fluvie_editor/src/transitions/clip_speed_edit.dart';
import 'package:fluvie_editor/src/video_mode/clip_trim_seconds.dart';
import 'package:fluvie_editor/src/video_mode/video_lane_model.dart';
import 'package:fluvie_editor/src/video_mode/video_mode_edits.dart';
import 'package:fluvie_editor/src/video_mode/video_timebase.dart';
import 'package:fluvie_editor/src/widgets/easing_curve_editor.dart';
import 'package:fluvie_editor/src/widgets/math_number_input.dart';
import 'package:obers_ui/obers_ui.dart';

part 'clip_speed_ramp_editor.part.dart';

/// Clip playback speed, keeping the source range and displayed length linked.
final class ClipSpeedSection extends StatefulWidget {
  /// Inspects [id] and dispatches undoable changes through [onCommand].
  const ClipSpeedSection({
    required this.document,
    required this.id,
    required this.onCommand,
    super.key,
  });

  /// Current immutable document.
  final EditorDocument document;

  /// The selected clip.
  final String id;

  /// Receives speed commands.
  final void Function(EditorCommand) onCommand;
  @override
  State<ClipSpeedSection> createState() => _ClipSpeedSectionState();
}

final class _ClipSpeedSectionState extends State<ClipSpeedSection> {
  String? _note;
  void _set(double value) {
    final edit = clipSpeedEdited(
      widget.document,
      widget.id,
      value,
      mergeGroup: 'speed:${widget.id}',
    );
    setState(() => _note = edit.note);
    if (edit.command case final command?) widget.onCommand(command);
  }

  void _ramp(KeyframedNumber ramp) {
    _apply(
      clipSpeedRampEdited(widget.document, widget.id, ramp, mergeGroup: 'speed-ramp:${widget.id}'),
    );
  }

  void _apply(VideoLaneEdit edit) {
    setState(() => _note = edit.note);
    if (edit.command case final command?) widget.onCommand(command);
  }

  List<double> _positions(KeyframedNumber ramp) {
    final model = VideoLaneModel.build(document: widget.document);
    final window =
        model.elementBars.values
            .expand((bar) => bar.members.isEmpty ? [bar] : bar.members)
            .where((bar) => bar.elementId == widget.id)
            .firstOrNull
            ?.window ??
        model.overlayBars.values.firstWhere((bar) => bar.elementId == widget.id).window;
    final scope = OwnerFrameScope(model.fps, FrameSpan(0, window.durationFrames));
    return [
      for (final position in ramp.positions) position.resolveFrames(scope) / window.durationFrames,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final speed = clipSpeedOf(widget.document.elementJson(widget.id) ?? const {});
    final ramp = KeyframedNumber.maybeFromJson(widget.document.elementJson(widget.id)?['speed']);
    final positions = ramp == null ? <double>[] : _positions(ramp);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (ramp == null)
          MathNumberInput(
            label: 'Speed ×',
            value: speed.abs(),
            min: 0.01,
            step: 0.05,
            decimals: 3,
            onChanged: (value) => _set(value * speed.sign),
          ),
        const SizedBox(height: 6),
        if (ramp == null)
          OiButton.ghost(
            label: speed < 0 ? 'Reverse: on' : 'Reverse: off',
            onTap: () => _set(-speed),
          ),
        if (ramp == null && speed > 0)
          OiButton.ghost(
            label: 'Add speed ramp',
            onTap: () => _ramp(
              KeyframedNumber.linear(
                values: [speed, speed / 2],
                positions: const [Time.relative(0), Time.relative(1)],
              ),
            ),
          ),
        if (ramp != null)
          _ClipSpeedRampEditor(
            ramp: ramp,
            positions: positions,
            onRamp: _ramp,
            onConstant: () => _set(1),
          ),
        if (speed < 0)
          OiLabel.small(
            'Reversed clips play without source audio.',
            color: context.colors.textSubtle,
          ),
        if (_note case final note?) OiLabel.small(note, color: context.colors.warning.base),
      ],
    );
  }
}
