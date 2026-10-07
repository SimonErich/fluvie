part of 'timeline_panel.dart';

/// The panel's link and marker handlers: a dropped link becomes a trigger
/// write (minting the target's anchor when it has none), a marker gesture
/// becomes a `steps` rewrite through the pure boundary math — one command
/// per gesture, drags coalescing like every other timeline drag.
extension _TimelinePanelSteps on _TimelinePanelState {
  List<Object?> get _stepsJson =>
      (widget.document.sceneJson(widget.slide)['steps'] as List<Object?>?) ?? const [];

  void _dispatchSteps(List<Object?>? steps, {bool merge = false}) {
    widget.onCommand(
      SetSceneStepsCommand(
        index: widget.slide,
        steps: steps,
        mergeGroup: merge ? _dragGroup : null,
      ),
    );
  }

  void _markerInserted(SlideTimelineModel model, double frame) {
    final next = stepsAfterMarkerInsert(
      stepsJson: _stepsJson,
      layout: model.stepLayout,
      frame: frame.round(),
    );
    if (next == null) return;
    _dispatchSteps(next);
  }

  void _markerMoved(SlideTimelineModel model, String id, double frame) {
    final boundary = _boundaryOf(id);
    if (boundary == null) return;
    final steps = _stepsJson;
    final next = stepsAfterMarkerMove(
      stepsJson: steps,
      layout: model.stepLayout,
      boundary: boundary,
      frame: frame.round(),
    );
    if (next == null || jsonEncode(next) == jsonEncode(steps)) return;
    _dispatchSteps(next, merge: true);
  }

  void _markerRemoved(SlideTimelineModel model, String id) {
    final boundary = _boundaryOf(id);
    if (boundary == null) return;
    final next = stepsAfterMarkerRemove(stepsJson: _stepsJson, boundary: boundary);
    _dispatchSteps(next.isEmpty ? null : next, merge: _dragGroup != null);
    if (_selectedMarkerId == id) _clearOverlaySelection();
  }

  void _markerTapped(String id) {
    _selectOverlay(marker: id);
    ref.read(keyframeSelectionProvider.notifier).clear();
  }

  /// The step boundary a marker id names (`step:<k>`), or null.
  int? _boundaryOf(String id) => id.startsWith('step:') ? int.tryParse(id.substring(5)) : null;

  /// A dropped link: onto another element it writes `whenEnds` off the
  /// target's anchor (minted as the target's element id when absent); onto
  /// the same element's preceding bar it writes `previous`; anything else —
  /// including a drop that would cycle the trigger graph — is refused.
  void _linkDropped(SlideTimelineModel model, String fromBarId, String toBarId) {
    final from = model.bindings[fromBarId];
    final to = model.bindings[toBarId];
    if (from == null || to == null) return;
    if (from.elementId == to.elementId) {
      if (to.index == from.index - 1) {
        widget.onCommand(
          SetAnimationTriggerCommand(id: from.elementId, index: from.index, trigger: 'previous'),
        );
      }
      return;
    }
    final target = widget.document.elementJson(to.elementId)!;
    final command = SetAnimationAnchorTriggerCommand(
      id: from.elementId,
      index: from.index,
      kind: 'whenEnds',
      targetId: to.elementId,
      anchorId: target['anchor'] as String? ?? mintedAnchorId(widget.document, to.elementId),
    );
    if (!resolvesAfter(widget.document, command)) return;
    widget.onCommand(command);
  }

  void _linkTapped(String id) {
    _selectOverlay(link: id);
    ref.read(keyframeSelectionProvider.notifier).clear();
  }

  /// Deleting a link reverts the animation's trigger to the auto default.
  void _linkDeleted(SlideTimelineModel model, String id) {
    final binding = model.bindings[id];
    if (binding == null) return;
    widget.onCommand(
      SetAnimationTriggerCommand(id: binding.elementId, index: binding.index, trigger: null),
    );
    if (_selectedLinkId == id) _clearOverlaySelection();
  }
}
