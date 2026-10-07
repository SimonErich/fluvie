part of 'command_registry.dart';

final List<EditorCommandEntry> _timelineEditCommands = [
  EditorCommandEntry(
    id: 'timeline.razor',
    title: 'Razor at playhead',
    category: 'Timeline',
    // A bare letter, the way every NLE spells it. The registry is consulted
    // before the tool letters, and B is not one of them.
    shortcut: const EditorShortcut(LogicalKeyboardKey.keyB),
    menus: const {EditorMenu.timeline},
    // Not a delete, but it does turn one clip into two, so the menus print it
    // in the colour that says this changes content.
    destructive: true,
    enabled: (scope) => razorableBars(scope).isNotEmpty,
    execute: (scope) async {
      final bars = razorableBars(scope);
      if (bars.isEmpty) return;
      // Every id up front: the cuts apply one after another, and minting from
      // the document each time would hand the same id to two tails.
      final ids = scope.document.nextIds(bars.length);
      final model = VideoLaneModel.build(document: scope.document);
      final group = 'razor:${scope.playhead}:${bars.join(',')}';
      for (var i = 0; i < bars.length; i++) {
        final edit = videoBarRazored(
          model,
          bars[i],
          scope.playhead,
          document: scope.document,
          tailId: ids[i],
          mergeGroup: group,
        );
        final command = edit?.command;
        if (command != null) scope.dispatch(command);
      }
    },
  ),
  EditorCommandEntry(
    id: 'timeline.rippleDelete',
    title: 'Ripple delete',
    category: 'Timeline',
    // The NLE spelling. Plain Delete belongs to the canvas selection, which
    // is a different set of things entirely.
    shortcut: const EditorShortcut(LogicalKeyboardKey.delete, shift: true),
    menus: const {EditorMenu.timeline},
    destructive: true,
    enabled: (scope) =>
        videoRippleDeleted(
          VideoLaneModel.build(document: scope.document),
          scope.timelineSelection,
          document: scope.document,
        )?.command !=
        null,
    execute: (scope) async {
      final edit = videoRippleDeleted(
        VideoLaneModel.build(document: scope.document),
        scope.timelineSelection,
        document: scope.document,
      );
      final command = edit?.command;
      if (command != null) scope.dispatch(command);
    },
  ),
  EditorCommandEntry(
    id: 'timeline.razorAll',
    title: 'Razor all lanes',
    category: 'Timeline',
    shortcut: const EditorShortcut(LogicalKeyboardKey.keyB, shift: true),
    menus: const {EditorMenu.timeline},
    destructive: true,
    enabled: (scope) => scope.canSeek && _razorAll(scope).isNotEmpty,
    execute: (scope) async {
      final model = VideoLaneModel.build(document: scope.document);
      final bars = _razorAll(scope);
      final ids = scope.document.nextIds(bars.length);
      final commands = <EditorCommand>[];
      for (var i = 0; i < bars.length; i++) {
        final command = videoBarRazored(
          model,
          bars[i],
          scope.playhead,
          document: scope.document,
          tailId: ids[i],
        )?.command;
        if (command != null) commands.add(command);
      }
      if (commands.isNotEmpty) scope.dispatch(SequenceCommand(commands, label: 'Razor all lanes'));
    },
  ),
  EditorCommandEntry(
    id: 'timeline.lift',
    title: 'Lift',
    category: 'Timeline',
    shortcut: const EditorShortcut(LogicalKeyboardKey.keyX),
    menus: const {EditorMenu.timeline},
    destructive: true,
    enabled: (scope) => _liftCommand(scope) != null,
    execute: (scope) async {
      final command = _liftCommand(scope);
      if (command != null) scope.dispatch(command);
    },
  ),
  EditorCommandEntry(
    id: 'timeline.extract',
    title: 'Extract marked range',
    category: 'Timeline',
    shortcut: const EditorShortcut(LogicalKeyboardKey.keyX, shift: true),
    menus: const {EditorMenu.timeline},
    destructive: true,
    enabled: (scope) => _extractCommand(scope) != null,
    execute: (scope) async {
      final command = _extractCommand(scope);
      if (command != null) scope.dispatch(command);
    },
  ),
];
