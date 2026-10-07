import 'package:flutter/widgets.dart';
import 'package:fluvie/fluvie.dart' show LaneKind, LaneSpec;
import 'package:fluvie/rendering.dart' show ClipMetadata, WaveformEnvelope;
import 'package:fluvie_editor/src/audio/audio_ducking.dart';
import 'package:fluvie_editor/src/audio/audio_meter.dart';
import 'package:fluvie_editor/src/audio/audio_monitor_controller.dart';
import 'package:fluvie_editor/src/audio/audio_track_view.dart';
import 'package:fluvie_editor/src/audio/volume_automation_editor.dart';
import 'package:fluvie_editor/src/document/editor_command.dart';
import 'package:fluvie_editor/src/document/editor_document.dart';
import 'package:fluvie_editor/src/video_mode/video_timebase.dart';
import 'package:fluvie_editor/src/widgets/math_number_input.dart';
import 'package:obers_ui/obers_ui.dart';

part 'audio_workspace_meter.dart';
part 'audio_workspace_state.dart';
part 'audio_workspace_view.dart';
part 'audio_workspace_controls.dart';

/// Audio workspace: lane gain, mute, audition solo, cached meters, editable
/// automation stops and a single-undo ducking action.
final class AudioWorkspacePanel extends StatefulWidget {
  /// Edits [document] through [onCommand]. Waveforms are cached by source value.
  const AudioWorkspacePanel({
    required this.document,
    required this.timebase,
    required this.currentFrame,
    required this.onCommand,
    this.monitor,
    this.envelopes = const {},
    this.clipMetadata = const {},
    super.key,
  });

  /// Current immutable document.
  final EditorDocument document;

  /// Composition clock.
  final VideoTimebase timebase;

  /// Absolute playhead frame.
  final int currentFrame;

  /// Command/history dispatch.
  final ValueChanged<EditorCommand> onCommand;

  /// Optional shared monitoring state; otherwise owned by this panel.
  final AudioMonitorController? monitor;

  /// Cached waveforms keyed by authored source value.
  final Map<String, WaveformEnvelope> envelopes;

  /// Probed clip facts keyed by authored source value.
  final Map<String, ClipMetadata> clipMetadata;
  @override
  State<AudioWorkspacePanel> createState() => _AudioWorkspacePanelState();
}
