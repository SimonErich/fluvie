part of 'command_registry.dart';

final List<EditorCommandEntry> _timelineTransportCommands = [
  EditorCommandEntry(
    id: 'timeline.markIn',
    title: 'Mark in',
    category: 'Timeline',
    shortcut: const EditorShortcut(LogicalKeyboardKey.keyI),
    menus: const {EditorMenu.timeline},
    enabled: _hasTransport,
    execute: (scope) async => scope.setMarkIn(scope.playhead),
  ),
  EditorCommandEntry(
    id: 'timeline.markOut',
    title: 'Mark out',
    category: 'Timeline',
    shortcut: const EditorShortcut(LogicalKeyboardKey.keyO),
    menus: const {EditorMenu.timeline},
    enabled: _hasTransport,
    execute: (scope) async => scope.setMarkOut(scope.playhead),
  ),
  EditorCommandEntry(
    id: 'timeline.clearMarks',
    title: 'Clear in and out',
    category: 'Timeline',
    menus: const {EditorMenu.timeline},
    // Nothing to clear is not an error, but offering it is noise.
    enabled: (scope) => scope.markIn != null || scope.markOut != null,
    execute: (scope) async => scope.clearMarks(),
  ),
  EditorCommandEntry(
    id: 'timeline.goToIn',
    title: 'Go to in',
    category: 'Timeline',
    shortcut: const EditorShortcut(LogicalKeyboardKey.keyI, shift: true),
    menus: const {EditorMenu.timeline},
    enabled: (scope) => scope.markIn != null,
    execute: (scope) async => scope.seek?.call(scope.markIn!),
  ),
  EditorCommandEntry(
    id: 'timeline.goToOut',
    title: 'Go to out',
    category: 'Timeline',
    shortcut: const EditorShortcut(LogicalKeyboardKey.keyO, shift: true),
    menus: const {EditorMenu.timeline},
    enabled: (scope) => scope.markOut != null,
    execute: (scope) async => scope.seek?.call(scope.markOut!),
  ),
  EditorCommandEntry(
    id: 'timeline.nextEdit',
    title: 'Next edit',
    category: 'Timeline',
    // Page keys, not the arrows: the arrows nudge the selected element on the
    // canvas, and the registry dispatches by key across every surface, so
    // taking them here would silently cost the canvas its nudge.
    shortcut: const EditorShortcut(LogicalKeyboardKey.pageDown),
    menus: const {EditorMenu.timeline},
    enabled: (scope) => _hasTransport(scope) && nextEditPoint(scope) != null,
    execute: (scope) async {
      final next = nextEditPoint(scope);
      if (next != null) scope.seek?.call(next);
    },
  ),
  EditorCommandEntry(
    id: 'timeline.previousEdit',
    title: 'Previous edit',
    category: 'Timeline',
    shortcut: const EditorShortcut(LogicalKeyboardKey.pageUp),
    menus: const {EditorMenu.timeline},
    enabled: (scope) => _hasTransport(scope) && previousEditPoint(scope) != null,
    execute: (scope) async {
      final previous = previousEditPoint(scope);
      if (previous != null) scope.seek?.call(previous);
    },
  ),
];
