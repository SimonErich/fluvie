import 'package:flutter/services.dart' show HardwareKeyboard;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fluvie/fluvie.dart' show EffectSpecKind;
import 'package:fluvie/rendering.dart' show WaveformEnvelope;
import 'package:fluvie_editor/src/audio/audio_monitor_controller.dart';
import 'package:fluvie_editor/src/document/editor_command.dart';
import 'package:fluvie_editor/src/document/editor_document.dart';
import 'package:fluvie_editor/src/effects/effect_drag_data.dart';
import 'package:fluvie_editor/src/media/media_store_entry.dart';
import 'package:fluvie_editor/src/media/source_monitor.dart';
import 'package:fluvie_editor/src/selection/selection_controller.dart';
import 'package:fluvie_editor/src/shell/editor_workspace.dart';
import 'package:fluvie_editor/src/shell/inspector_tab_request.dart';
import 'package:fluvie_editor/src/shell/inspector_tabs.dart';
import 'package:fluvie_editor/src/snapping/snap_preferences.dart';
import 'package:fluvie_editor/src/timeline/keyframe_stop_math.dart';
import 'package:fluvie_editor/src/timeline/timeline_bar_selection.dart';
import 'package:fluvie_editor/src/timeline/timeline_snap.dart';
import 'package:fluvie_editor/src/transitions/clip_speed_edit.dart';
import 'package:fluvie_editor/src/transitions/transition_browser.dart';
import 'package:fluvie_editor/src/transitions/transition_edits.dart';
import 'package:fluvie_editor/src/transport/slide_transport.dart';
import 'package:fluvie_editor/src/video_mode/selected_audio.dart';
import 'package:fluvie_editor/src/video_mode/video_lane_bindings.dart';
import 'package:fluvie_editor/src/video_mode/video_lane_model.dart';
import 'package:fluvie_editor/src/video_mode/video_lane_neighbours.dart';
import 'package:fluvie_editor/src/video_mode/video_lane_snap.dart';
import 'package:fluvie_editor/src/video_mode/video_mode_edits.dart';
import 'package:fluvie_editor/src/video_mode/video_razor.dart';
import 'package:fluvie_editor/src/video_mode/video_relane.dart';
import 'package:fluvie_editor/src/video_mode/video_ripple.dart';
import 'package:fluvie_editor/src/video_mode/video_scene_retime.dart';
import 'package:fluvie_editor/src/video_mode/video_slip_slide.dart';
import 'package:fluvie_editor/src/widgets/editor_tip.dart';
import 'package:fluvie_editor/src/widgets/track_timeline/timeline_bar.dart';
import 'package:fluvie_editor/src/widgets/track_timeline/timeline_track.dart';
import 'package:fluvie_editor/src/widgets/track_timeline/track_timeline.dart';
import 'package:fluvie_editor/src/widgets/track_timeline/track_timeline_controller.dart';
import 'package:obers_ui/obers_ui.dart';

part 'video_mode_panel_effects.dart';
part 'video_mode_panel_header.dart';
part 'video_mode_panel_selection.dart';
part 'video_mode_panel_snap.dart';
part 'video_mode_panel_trim.dart';
part 'video_mode_panel_state.part.dart';
part 'video_mode_panel_timeline.part.dart';
part 'video_mode_panel_gestures.part.dart';
part 'video_mode_panel_lanes.part.dart';
part 'video_mode_panel_tracks.part.dart';

/// The video mode's timeline panel: the whole composition's lanes — scene
/// blocks on the absolute ruler, clip and window lanes, audio lanes — over
/// the shared whole-video [SlideTransport].
///
/// One direction only, like the slides panel: the document renders into
/// [VideoLaneModel], a lane gesture maps through the video-mode edit
/// functions into one command (or an honest refusal note in the header),
/// and the changed document renders again.
final class VideoModePanel extends ConsumerStatefulWidget {
  /// Shows [document]'s video timeline on [transport].
  const VideoModePanel({
    required this.document,
    required this.transport,
    required this.onCommand,
    this.onOpenChanged,
    this.height = 200,
    this.laneEnvelopes = const {},
    this.thumbnailsByBar = const {},
    this.onFilmstripNeeded,
    this.audioMonitor,
    this.onSourceDropped,
    super.key,
  });

  /// The deck being edited.
  final EditorDocument document;

  /// The whole-video playhead the canvas mounts and this panel drives.
  final SlideTransport transport;

  /// Receives the timeline's commands.
  final void Function(EditorCommand command) onCommand;

  /// Hears the header's collapse toggle.
  final ValueChanged<bool>? onOpenChanged;

  /// The open panel's body height (the header rides on top of it).
  final double height;

  /// Cached waveform envelopes keyed by timeline row id.
  final Map<String, WaveformEnvelope> laneEnvelopes;

  /// Cached decoded filmstrip frames keyed by bar id.
  final Map<String, List<TimelineThumbnail>> thumbnailsByBar;

  /// Requests only the visible frame span from the host media cache.
  final void Function(int fromFrame, int toFrame)? onFilmstripNeeded;

  /// Preview-only solo state shared with the audio workspace.
  final AudioMonitorController? audioMonitor;

  /// Places a marked source onto the given row at the whole-video frame.
  final void Function(SourceMonitorPlacement source, String trackId, int frame)? onSourceDropped;

  @override
  ConsumerState<VideoModePanel> createState() => _VideoModePanelState();
}
