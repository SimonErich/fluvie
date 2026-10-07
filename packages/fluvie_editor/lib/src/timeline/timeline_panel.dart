import 'dart:convert' show jsonEncode;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fluvie_editor/src/document/anchor_triggers.dart';
import 'package:fluvie_editor/src/document/editor_command.dart';
import 'package:fluvie_editor/src/document/editor_document.dart';
import 'package:fluvie_editor/src/selection/keyframe_selection.dart';
import 'package:fluvie_editor/src/selection/selection_controller.dart';
import 'package:fluvie_editor/src/shell/inspector_tab_request.dart';
import 'package:fluvie_editor/src/shell/inspector_tabs.dart';
import 'package:fluvie_editor/src/timeline/keyframe_stop_math.dart';
import 'package:fluvie_editor/src/timeline/slide_timeline_model.dart';
import 'package:fluvie_editor/src/timeline/step_boundaries.dart';
import 'package:fluvie_editor/src/timeline/timeline_link_palette.dart';
import 'package:fluvie_editor/src/transport/frame_range.dart';
import 'package:fluvie_editor/src/transport/slide_transport.dart';
import 'package:fluvie_editor/src/widgets/editor_tip.dart';
import 'package:fluvie_editor/src/widgets/track_timeline/timeline_bar.dart';
import 'package:fluvie_editor/src/widgets/track_timeline/track_timeline.dart';
import 'package:obers_ui/obers_ui.dart';

part 'timeline_panel_state.dart';
part 'timeline_panel_edits.dart';
part 'timeline_panel_steps.dart';
part 'timeline_panel_transport.dart';

/// The collapsible timeline panel under the canvas: the current slide's
/// tracks, animation bars, keyframe diamonds, trigger links, and build
/// markers, edited through the command layer.
///
/// One direction only: the panel renders the document (via introspection),
/// a bar, diamond, link, or marker edit dispatches a scene-relative command,
/// and the changed document renders again. With a [transport] the shared
/// playhead is the one truth — scrubs seek it and the ruler follows its
/// frame — and the header grows the transport face (play/pause, the
/// readout, the loop toggle). Without one the playhead is panel state.
final class TimelinePanel extends ConsumerStatefulWidget {
  /// Shows slide [slide] of [document].
  const TimelinePanel({
    required this.document,
    required this.slide,
    required this.onCommand,
    this.transport,
    this.onScrub,
    this.onOpenChanged,
    this.height = 200,
    super.key,
  });

  /// The deck being edited.
  final EditorDocument document;

  /// The slide whose timeline shows.
  final int slide;

  /// Receives the timeline's commands.
  final void Function(EditorCommand command) onCommand;

  /// The slide's shared playhead — the same transport the canvas mounts.
  /// The owner swaps it per slide. Null keeps the playhead panel-local.
  final SlideTransport? transport;

  /// Hears playhead scrubs in slide-relative whole frames.
  final ValueChanged<int>? onScrub;

  /// Hears the header's collapse toggle — how the owner keeps Space's
  /// open-panel context honest.
  final ValueChanged<bool>? onOpenChanged;

  /// The open panel's body height (the header rides on top of it).
  final double height;

  @override
  ConsumerState<TimelinePanel> createState() => _TimelinePanelState();
}
