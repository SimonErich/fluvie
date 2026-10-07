import 'dart:ui' show Offset, Rect, Size;

import 'package:flutter/foundation.dart' show immutable;
import 'package:flutter/painting.dart' show Axis;
import 'package:fluvie/fluvie.dart'
    show Placement, decodePlacement, encodePlacement, introspectTimeline;
import 'package:fluvie_editor/src/arrange/align_math.dart';
import 'package:fluvie_editor/src/arrange/arrange_order.dart';
import 'package:fluvie_editor/src/blocks/block_spec.dart';
import 'package:fluvie_editor/src/document/editor_document.dart';
import 'package:fluvie_editor/src/gizmo/transform_drag.dart';
import 'package:fluvie_editor/src/media/media_store_entry.dart';
import 'package:fluvie_editor/src/templates/template_merge.dart';

part 'align_commands.dart';
part 'animation_commands.dart';
part 'animation_edit_commands.dart';
part 'arrange_commands.dart';
part 'audio_commands.dart';
part 'auto_animate_commands.dart';
part 'block_commands.dart';
part 'clipboard_commands.dart';
part 'effect_commands.dart';
part 'colour_commands.dart';
part 'effect_stop_commands.dart';
part 'element_commands.dart';
part 'set_transforms_command.dart';
part 'replace_element_command.dart';
part 'replace_shared_members_command.dart';
part 'insert_element_command.dart';
part 'remove_element_command.dart';
part 'reorder_element_command.dart';
part 'set_element_meta_command.dart';
part 'keyframe_commands.dart';
part 'keyframe_stop_commands.dart';
part 'lane_commands.dart';
part 'master_commands.dart';
part 'media_commands.dart';
part 'move_commands.dart';
part 'notes_commands.dart';
part 'overlay_commands.dart';
part 'razor_commands.dart';
part 'scene_commands.dart';
part 'sequence_commands.dart';
part 'show_commands.dart';
part 'step_commands.dart';
part 'template_commands.dart';
part 'title_commands.dart';
part 'theme_commands.dart';

/// One intention against the document: applying it produces the next
/// document state, and its metadata drives the history (labels, selection
/// after undo, drag coalescing).
///
/// Commands are the only way the editor mutates a deck. They are sealed so
/// the history, the palette, and the tests can enumerate every intention.
@immutable
sealed class EditorCommand {
  const EditorCommand();

  /// The next document after this command.
  EditorDocument apply(EditorDocument document);

  /// What the undo menu calls this ("Move el-3").
  String get label;

  /// The element ids this command touches; undo re-selects them.
  Set<String> get affectedIds;

  /// Commands with the same non-null key coalesce into one undo step (a
  /// drag is a stream of [SetTransformCommand]s, undone as one).
  String? get mergeKey => null;
}
