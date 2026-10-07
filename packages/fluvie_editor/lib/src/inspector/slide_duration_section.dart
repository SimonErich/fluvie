import 'package:flutter/widgets.dart';
import 'package:fluvie_editor/src/document/editor_command.dart';
import 'package:fluvie_editor/src/document/editor_document.dart';
import 'package:fluvie_editor/src/video_mode/video_lane_model.dart';
import 'package:fluvie_editor/src/video_mode/video_scene_retime.dart';
import 'package:fluvie_editor/src/video_mode/video_timebase.dart';
import 'package:fluvie_editor/src/widgets/math_number_input.dart';
import 'package:fluvie_editor/src/widgets/numeric_unit.dart';
import 'package:obers_ui/obers_ui.dart';

/// The slide's length, in frames and in seconds.
///
/// The same edit the boundary hairline makes, one gesture apart: direct
/// manipulation on the timeline, a number here, and a refusal explains itself
/// either way rather than writing a document the engine would reject.
final class SlideDurationSection extends StatelessWidget {
  /// Inspects slide [slide] of [document]; commands land in [onCommand] and a
  /// refusal or a clamp in [onNote].
  const SlideDurationSection({
    required this.document,
    required this.slide,
    required this.onCommand,
    this.onNote,
    super.key,
  });

  /// The deck being edited.
  final EditorDocument document;

  /// The slide on stage.
  final int slide;

  /// Receives the retime command.
  final void Function(EditorCommand command) onCommand;

  /// Hears the honest explanation of a refusal or a clamp, or null on a
  /// surface with nowhere to show one.
  final ValueChanged<String>? onNote;

  @override
  Widget build(BuildContext context) {
    final timebase = VideoTimebase.of(document);
    if (slide < 0 || slide >= timebase.sceneSpans.length) return const SizedBox.shrink();
    final frames = timebase.sceneSpans[slide].durationFrames;
    return OiPropertyGrid(
      properties: [
        OiPropertyRow(
          label: 'Length',
          editor: MathNumberInput(
            label: '',
            value: frames.toDouble(),
            min: 1,
            decimals: 0,
            format: NumericFormat(unit: NumericUnit.frames, fps: timebase.fps),
            onChanged: (next) => _retime(next.round()),
          ),
        ),
        OiPropertyRow(
          label: 'Seconds',
          editor: MathNumberInput(
            label: '',
            value: frames / timebase.fps,
            min: 1 / timebase.fps,
            decimals: 2,
            onChanged: (next) => _retime((next * timebase.fps).round()),
          ),
        ),
      ],
    );
  }

  void _retime(int frames) {
    final edit = videoSceneRetimed(
      VideoLaneModel.build(document: document),
      slide,
      frames,
      document: document,
    );
    if (edit == null) return;
    final note = edit.note;
    if (note != null) onNote?.call(note);
    final command = edit.command;
    if (command != null) onCommand(command);
  }
}
