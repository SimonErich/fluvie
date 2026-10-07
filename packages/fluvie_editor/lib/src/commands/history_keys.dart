import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:fluvie_editor/src/commands/command_registry.dart';

/// The editor-wide undo/redo chords, matched against the command registry's
/// own `edit.undo` / `edit.redo` bindings so the keys can never drift from
/// the hints the menus print.
///
/// Like `TransportKeys`, the widget wraps the whole editing surface and
/// hears whatever key events the focused descendant leaves unhandled — so
/// the chords work with focus in any panel. The canvas never lets them
/// bubble this far: its own key path dispatches the registry first (it must,
/// because the palette's shortcut scope above the canvas focus swallows a
/// stray Ctrl+Z). A focus inside a text editor keeps the field's own text
/// undo, and a disabled step reads as ignored.
final class HistoryKeys extends StatelessWidget {
  /// Wires the registry's undo and redo chords over [child].
  const HistoryKeys({
    required this.canUndo,
    required this.canRedo,
    required this.onUndo,
    required this.onRedo,
    required this.child,
    super.key,
  });

  /// Whether an undo step exists — false leaves the chord unhandled.
  final bool canUndo;

  /// Whether a redo step exists.
  final bool canRedo;

  /// Undoes one history step.
  final VoidCallback onUndo;

  /// Redoes one history step.
  final VoidCallback onRedo;

  /// The editing surface the key events bubble out of.
  final Widget child;

  // Not const: LogicalKeyboardKey has no primitive equality.
  static final Set<LogicalKeyboardKey> _commandKeys = {
    LogicalKeyboardKey.controlLeft,
    LogicalKeyboardKey.controlRight,
    LogicalKeyboardKey.metaLeft,
    LogicalKeyboardKey.metaRight,
  };
  static final Set<LogicalKeyboardKey> _shiftKeys = {
    LogicalKeyboardKey.shiftLeft,
    LogicalKeyboardKey.shiftRight,
  };

  /// Whether the primary focus sits inside a text editor — its Ctrl+Z is
  /// the field's own text undo, never document history.
  static bool _editingText() {
    final context = FocusManager.instance.primaryFocus?.context;
    return context != null && context.findAncestorWidgetOfExactType<EditableText>() != null;
  }

  KeyEventResult _onKeyEvent(FocusNode node, KeyEvent event) {
    if (event is KeyUpEvent) return KeyEventResult.ignored;
    if (_editingText()) return KeyEventResult.ignored;
    final pressed = HardwareKeyboard.instance.logicalKeysPressed;
    final entry = editorCommandForKey(
      event.logicalKey,
      command: pressed.any(_commandKeys.contains),
      shift: pressed.any(_shiftKeys.contains),
    );
    return switch (entry?.id) {
      'edit.undo' when canUndo => _run(onUndo),
      'edit.redo' when canRedo => _run(onRedo),
      _ => KeyEventResult.ignored,
    };
  }

  static KeyEventResult _run(VoidCallback action) {
    action();
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) => Focus(
    canRequestFocus: false,
    skipTraversal: true,
    includeSemantics: false,
    onKeyEvent: _onKeyEvent,
    child: child,
  );
}
