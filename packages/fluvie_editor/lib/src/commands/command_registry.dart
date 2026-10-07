import 'dart:math' show max, min;
import 'dart:ui' show Rect;

import 'package:flutter/foundation.dart' show immutable;
import 'package:flutter/painting.dart' show Axis;
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:fluvie_editor/src/arrange/align_math.dart';
import 'package:fluvie_editor/src/arrange/arrange_order.dart';
import 'package:fluvie_editor/src/blocks/block_spec.dart';
import 'package:fluvie_editor/src/commands/command_scope.dart';
import 'package:fluvie_editor/src/commands/copied_slide.dart';
import 'package:fluvie_editor/src/commands/editor_clipboard.dart';
import 'package:fluvie_editor/src/commands/editor_shortcut.dart';
import 'package:fluvie_editor/src/commands/paste_remint.dart';
import 'package:fluvie_editor/src/document/deck_sections.dart';
import 'package:fluvie_editor/src/document/editor_command.dart';
import 'package:fluvie_editor/src/document/editor_document.dart';
import 'package:fluvie_editor/src/video_mode/video_lane_model.dart';
import 'package:fluvie_editor/src/video_mode/video_lift.dart';
import 'package:fluvie_editor/src/video_mode/video_razor.dart';
import 'package:fluvie_editor/src/video_mode/video_ripple.dart';
import 'package:fluvie_editor/src/video_mode/video_timebase.dart';

part 'catalog_arrange.dart';
part 'catalog_blocks.dart';
part 'catalog_clipboard.dart';
part 'catalog_effects.dart';
part 'catalog_history.dart';
part 'catalog_masters.dart';
part 'catalog_slides.dart';
part 'catalog_timeline.dart';
part 'catalog_timeline_transport.dart';
part 'catalog_timeline_edits.dart';
part 'catalog_timeline_structure.dart';

/// The context menus a registry command can surface in.
enum EditorMenu {
  /// The right-click menu over an element (or a selection).
  element,

  /// The right-click menu over empty canvas.
  canvas,

  /// The right-click menu on a slide-strip tile.
  slideStrip,

  /// The timeline's own menu: the verbs that act on time rather than on the
  /// canvas.
  timeline,
}

/// One editor command as the registry knows it: identity, display, the
/// binding, where it surfaces, and how it decides and acts against a
/// [CommandScope].
///
/// The registry is the single source of truth — the context menus, the
/// command palette, and the canvas's keyboard dispatch all enumerate it, so
/// the hint a menu prints is by construction the binding that fires.
@immutable
final class EditorCommandEntry {
  /// Describes one command.
  const EditorCommandEntry({
    required this.id,
    required this.title,
    required this.category,
    required this.menus,
    required this.enabled,
    required this.execute,
    this.shortcut,
    this.destructive = false,
    this.checked,
  });

  /// The stable identity ("edit.copy").
  final String id;

  /// What menus and the palette call it.
  final String title;

  /// The palette's grouping header.
  final String category;

  /// The keyboard binding, or null for menu-only commands.
  final EditorShortcut? shortcut;

  /// The context menus this command surfaces in (never empty — every
  /// command is reachable from a menu).
  final Set<EditorMenu> menus;

  /// Whether the command destroys content (menus print it in the error
  /// color).
  final bool destructive;

  /// The toggle state for check-marked items (lock, hide), or null for
  /// plain commands.
  final bool? Function(CommandScope scope)? checked;

  /// Whether the command applies to [CommandScope]'s selection and slide.
  final bool Function(CommandScope scope) enabled;

  /// Runs the command against the scope.
  final Future<void> Function(CommandScope scope) execute;
}

/// Every editor command, in catalog order.
final List<EditorCommandEntry> editorCommands = List.unmodifiable([
  ..._historyCommands,
  ..._clipboardCommands,
  ..._effectsCommands,
  ..._arrangeCommands,
  ..._blockCommands,
  ..._slideCommands,
  ..._masterCommands,
  ..._timelineCommands,
]);

/// The entry with [id]. Throws a [StateError] for an unknown id.
EditorCommandEntry editorCommandById(String id) =>
    editorCommands.firstWhere((entry) => entry.id == id);

/// The entry whose binding fires on [key] under the given modifier state,
/// or null when the registry binds nothing to it.
EditorCommandEntry? editorCommandForKey(
  LogicalKeyboardKey key, {
  required bool command,
  required bool shift,
}) {
  for (final entry in editorCommands) {
    final shortcut = entry.shortcut;
    if (shortcut != null && shortcut.matches(key, command: command, shift: shift)) {
      return entry;
    }
  }
  return null;
}
