part of 'command_registry.dart';

final List<EditorCommandEntry> _timelineStructureCommands = [
  EditorCommandEntry(
    id: 'timeline.snap',
    title: 'Timeline snapping',
    category: 'Timeline',
    shortcut: const EditorShortcut(LogicalKeyboardKey.keyS, shift: true),
    menus: const {EditorMenu.timeline},
    enabled: (scope) => scope.toggleSnap != null,
    checked: (scope) => scope.snapEnabled,
    execute: (scope) async => scope.toggleSnap?.call(),
  ),
  EditorCommandEntry(
    id: 'timeline.addLane',
    title: 'Add lane',
    category: 'Timeline',
    shortcut: const EditorShortcut(LogicalKeyboardKey.keyN, shift: true),
    menus: const {EditorMenu.timeline},
    enabled: _hasTransport,
    execute: (scope) async {
      if (!scope.canSeek) return;
      final lanes = scope.document.spec.lanes;
      final used = lanes.map((lane) => lane.id).toSet();
      var next = 1;
      while (used.contains('lane-$next')) {
        next++;
      }
      scope.dispatch(
        UpdateVideoCommand(
          patch: {
            'lanes': [
              ...lanes.map((lane) => lane.toJson()),
              {'id': 'lane-$next', 'name': 'Lane $next'},
            ],
          },
        ),
      );
    },
  ),
  EditorCommandEntry(
    id: 'timeline.deleteLane',
    title: 'Delete lane',
    category: 'Timeline',
    menus: const {EditorMenu.timeline},
    destructive: true,
    enabled: (scope) =>
        scope.document.spec.lanes.any((lane) => lane.id == scope.activeLane && !lane.locked),
    execute: (scope) async {
      final id = scope.activeLane;
      if (id != null && scope.document.spec.lanes.any((lane) => lane.id == id && !lane.locked)) {
        scope.dispatch(RemoveLaneCommand(id: id));
      }
    },
  ),
];
