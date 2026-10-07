part of 'command_registry.dart';

/// The history commands: undo and redo against the scope's history
/// callables. Enabled follows [CommandScope.canUndo] / [CommandScope.canRedo],
/// so a surface without a history (a viewer, the slide strip) simply shows
/// them disabled — the same inert-defaults contract as the other callbacks.
final List<EditorCommandEntry> _historyCommands = [
  EditorCommandEntry(
    id: 'edit.undo',
    title: 'Undo',
    category: 'Edit',
    shortcut: const EditorShortcut(LogicalKeyboardKey.keyZ, command: true),
    menus: const {EditorMenu.canvas},
    enabled: (scope) => scope.canUndo,
    execute: (scope) async => scope.undo(),
  ),
  EditorCommandEntry(
    id: 'edit.redo',
    title: 'Redo',
    category: 'Edit',
    shortcut: const EditorShortcut(
      LogicalKeyboardKey.keyZ,
      command: true,
      shift: true,
      alternates: [EditorShortcut(LogicalKeyboardKey.keyY, command: true)],
    ),
    menus: const {EditorMenu.canvas},
    enabled: (scope) => scope.canRedo,
    execute: (scope) async => scope.redo(),
  ),
];
