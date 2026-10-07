part of 'canvas_interaction.dart';

/// The canvas's face of the command registry: one [CommandScope] built from
/// the live editing state feeds the keyboard dispatch, the right-click
/// menus, and the command palette — so every surface fires the same
/// registry entry the hints advertise.
extension _CanvasCommands on _CanvasInteractionState {
  /// Snapshots the current editing state for the registry. [selection]
  /// overrides the live selection (the element menu acts on its target).
  /// Undo and redo come from [historyActionsProvider] — the host's history,
  /// or the inert default on a canvas without one.
  CommandScope _commandScope({Set<String>? selection}) {
    final geometry = _geometry;
    final history = ref.read(historyActionsProvider);
    final transport = widget.transport;
    final marks = ref.read(timelineMarksProvider);
    return CommandScope(
      document: widget.document,
      slide: widget.slide,
      selection: selection ?? ref.read(selectionProvider),
      enteredGroup: _entered,
      clipboard: ref.read(editorClipboardProvider),
      frameOrigin: _frameOrigin,
      frameSize: _frameSize,
      dispatch: (command) => widget.onCommand?.call(command),
      select: (ids) => ref.read(selectionProvider.notifier).select(ids),
      exitGroup: () => ref.read(enteredGroupProvider.notifier).exit(),
      showSlide: (slide) => widget.onShowSlide?.call(slide),
      rectOf: geometry.rectOf,
      canUndo: history.canUndo(),
      canRedo: history.canRedo(),
      undo: history.undo,
      redo: history.redo,
      // Nullable, not inert: a stage holding a settled still has no playhead
      // at all, and a no-op seek would let the transport verbs read as
      // working while writing marks nobody could reach.
      playhead: transport?.frame ?? 0,
      seek: transport?.seek,
      markIn: marks.markIn,
      markOut: marks.markOut,
      setMarks: transport == null
          ? null
          : ({markIn, markOut}) =>
                ref.read(timelineMarksProvider.notifier).set(markIn: markIn, markOut: markOut),
      timelineSelection: ref.read(timelineSelectionProvider),
    );
  }

  /// The registry side of one key press, or null for keys the registry
  /// does not bind (they fall through to the tool letters and the arrows).
  /// A matching but disabled binding reads as ignored, so no-op chords
  /// never dirty the history.
  KeyEventResult? _registryShortcut(LogicalKeyboardKey key) {
    final entry = editorCommandForKey(key, command: _snapBypass, shift: _shift);
    if (entry == null) return null;
    final scope = _commandScope();
    if (!entry.enabled(scope)) return KeyEventResult.ignored;
    unawaited(entry.execute(scope));
    return KeyEventResult.handled;
  }

  /// The right-click menu for a press at [local]: over an element the
  /// element menu for it — or for the whole selection when it is part of
  /// one — over empty canvas the canvas menu. Hitting an unselected element
  /// selects it as the menu opens (the Figma behavior); empty canvas keeps
  /// the selection as the paste target.
  List<OiMenuItem> _contextMenuItemsAt(Offset local) {
    final hit = _geometry.hitTest(widget.viewport.toCanvas(local), skip: _untouchable);
    if (hit == null) return canvasMenuItems(_commandScope());
    final selection = ref.read(selectionProvider);
    final ids = selection.contains(hit) ? selection : {hit};
    if (!setEquals(ids, selection)) ref.read(selectionProvider.notifier).select(ids);
    return elementMenuItems(_commandScope(selection: ids));
  }
}
