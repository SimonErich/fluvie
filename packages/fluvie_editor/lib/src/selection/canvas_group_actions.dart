part of 'canvas_interaction.dart';

/// How far (in canvas pixels) a dragged child's center must leave the
/// entered block's box before the drop releases it from the block.
const double _blockReleaseThreshold = 12;

/// The group-scope half of the canvas input: which ids the current scope
/// edits and the taps that leave an entered group. The arrange chords the
/// 5.3 epic parked here (group, ungroup, the brackets) migrated into the
/// command registry with 5.4.
extension _CanvasGroupActions on _CanvasInteractionState {
  /// The ids the current scope edits: the slide's top level, or the entered
  /// group's children.
  List<String> get _scopeIds {
    final entered = _entered;
    return entered == null
        ? widget.document.elementIdsInScene(widget.slide)
        : widget.document.childIdsOfGroup(entered);
  }

  /// Locked or hidden elements neither hit nor hover.
  Set<String> get _untouchable => _untouchableOf(_scopeIds);

  Set<String> _untouchableOf(Iterable<String> ids) => {
    for (final id in ids)
      if (widget.document.elementMeta(id)['locked'] == true ||
          widget.document.elementJson(id)?['visible'] == false)
        id,
  };

  /// The release-from-block commit, or null when the drop stays a plain
  /// transform commit: a single child body-dragged out of an entered BLOCK
  /// group (its live center beyond the group's box by more than the
  /// threshold) leaves the group instead of snapping back — one undo step
  /// through [ReleaseFromBlockCommand]. Plain groups never release.
  ReleaseFromBlockCommand? _blockReleaseCommand(GizmoSession session) {
    final entered = _entered;
    if (entered == null || !session.isMove || !session.changed) return null;
    if (widget.document.blockOf(entered) == null) return null;
    final live = session.live;
    if (live.length != 1) return null;
    final id = live.keys.single;
    final rect = session.displayRectOf(id);
    if (rect == null) return null;
    final bounds = (Offset.zero & _frameSize).inflate(_blockReleaseThreshold);
    if (bounds.contains(rect.center)) return null;
    return ReleaseFromBlockCommand(
      groupId: entered,
      childId: id,
      transform: encodePlacement(live[id]!),
    );
  }

  /// A tap that missed every child of the entered group: on the group's own
  /// box the selection just clears; anywhere else exits the group and the
  /// tap lands at the top level.
  void _tapOutsideEnteredGroup(Offset canvasPoint) {
    final topLevel = SceneGeometry.of(widget.document, widget.slide);
    final topHit = topLevel.hitTest(
      canvasPoint,
      skip: _untouchableOf(widget.document.elementIdsInScene(widget.slide)),
    );
    if (topHit == _entered) {
      ref.read(selectionProvider.notifier).click(null, additive: _shift);
      return;
    }
    ref.read(enteredGroupProvider.notifier).exit();
    ref.read(selectionProvider.notifier).click(topHit, additive: _shift);
  }
}
