import 'dart:async' show unawaited;

import 'package:flutter/foundation.dart' show setEquals;
import 'package:flutter/gestures.dart' show DragStartBehavior, PointerHoverEvent;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fluvie/fluvie.dart' show Placement, decodePlacement, encodePlacement;
import 'package:fluvie_editor/src/chrome/selection_toolbar.dart';
import 'package:fluvie_editor/src/commands/command_palette.dart';
import 'package:fluvie_editor/src/commands/command_registry.dart';
import 'package:fluvie_editor/src/commands/command_scope.dart';
import 'package:fluvie_editor/src/commands/context_menu_host.dart';
import 'package:fluvie_editor/src/commands/editor_clipboard.dart';
import 'package:fluvie_editor/src/commands/history_actions.dart';
import 'package:fluvie_editor/src/commands/menu_templates.dart';
import 'package:fluvie_editor/src/document/editor_command.dart';
import 'package:fluvie_editor/src/document/editor_document.dart';
import 'package:fluvie_editor/src/effects/effect_drag_data.dart';
import 'package:fluvie_editor/src/gizmo/gizmo_session.dart';
import 'package:fluvie_editor/src/gizmo/transform_drag.dart';
import 'package:fluvie_editor/src/masters/master_slot_overlay.dart';
import 'package:fluvie_editor/src/media/media_import.dart';
import 'package:fluvie_editor/src/selection/entered_group.dart';
import 'package:fluvie_editor/src/selection/scene_geometry.dart';
import 'package:fluvie_editor/src/selection/selection_chrome.dart';
import 'package:fluvie_editor/src/selection/selection_controller.dart';
import 'package:fluvie_editor/src/snapping/guide_layer.dart';
import 'package:fluvie_editor/src/snapping/manual_guide.dart';
import 'package:fluvie_editor/src/snapping/snap_engine.dart';
import 'package:fluvie_editor/src/snapping/snap_guide_overlay.dart';
import 'package:fluvie_editor/src/snapping/snap_line.dart';
import 'package:fluvie_editor/src/snapping/snap_preferences.dart';
import 'package:fluvie_editor/src/timeline/timeline_bar_selection.dart';
import 'package:fluvie_editor/src/timeline/timeline_marks.dart';
import 'package:fluvie_editor/src/tools/element_placer.dart';
import 'package:fluvie_editor/src/tools/inline_text_editor.dart';
import 'package:fluvie_editor/src/tools/media_importer.dart';
import 'package:fluvie_editor/src/tools/tool_controller.dart';
import 'package:fluvie_editor/src/transport/slide_transport.dart';
import 'package:fluvie_editor/src/widgets/canvas_viewport.dart';
import 'package:fluvie_editor/src/widgets/gizmo_geometry.dart';
import 'package:fluvie_editor/src/widgets/transform_gizmo.dart';
import 'package:obers_ui/obers_ui.dart'
    show OiBuildContextThemeExt, OiFloating, OiFloatingAlignment, OiLabel, OiMenuItem;

part 'canvas_commands.dart';
part 'canvas_gestures.dart';
part 'canvas_drag_gestures.dart';
part 'canvas_authoring_actions.dart';
part 'canvas_group_actions.dart';
part 'canvas_layers.dart';
part 'canvas_master_slots.dart';
part 'canvas_interaction_state.dart';
part 'canvas_interaction_geometry.dart';

/// The canvas's input layer: clicks select, shift-clicks extend, a drag on
/// empty canvas sweeps a marquee, Space plus drag pans — and over the
/// selection, the transform gizmo moves, resizes, and rotates through the
/// command layer. Every position resolves against the document's geometry
/// through the one shared camera mapping.
final class CanvasInteraction extends ConsumerStatefulWidget {
  /// Wires input over slide [slide] of [document] under [viewport]'s
  /// camera. Gizmo drags stream placements into [overrides] (the canvas's
  /// fast path) and commit through [onCommand] on release.
  const CanvasInteraction({
    required this.document,
    required this.slide,
    required this.viewport,
    required this.overrides,
    this.transport,
    this.settleFrame = 0,
    this.onCommand,
    this.onShowSlide,
    super.key,
  });

  /// The deck being edited.
  final EditorDocument document;

  /// The scene index on stage.
  final int slide;

  /// The camera; positions map through it.
  final CanvasViewportController viewport;

  /// The live placement overrides a drag streams into.
  final ValueNotifier<Map<String, Placement>> overrides;

  /// The whole-document preview's absolute clock, or null when the stage
  /// holds a settled still (slides and master editing). When set, the input
  /// layer stays inert below [settleFrame], where the on-stage [slide] is
  /// still displaced by its incoming transition.
  final SlideTransport? transport;

  /// The on-stage scene's settled frame on [transport]'s clock; ignored
  /// without a [transport].
  final int settleFrame;

  /// Receives the committed commands; null disables editing gestures'
  /// effect (they still preview, but nothing commits).
  final void Function(EditorCommand command)? onCommand;

  /// Asks the host to put a slide on stage (the registry's slide commands
  /// follow their result); null leaves the stage where it is.
  final void Function(int slide)? onShowSlide;

  @override
  ConsumerState<CanvasInteraction> createState() => _CanvasInteractionState();
}
