part of 'timeline_panel.dart';

/// The panel's edit handlers: every timeline intention turned into one
/// scene-relative document command (bar retimes and trims, keyframe stop
/// adds, moves, and deletes, and the selection they carry).
extension _TimelinePanelEdits on _TimelinePanelState {
  void _barMoved(SlideTimelineModel model, String barId, double newStart) {
    final binding = model.bindings[barId];
    if (binding == null) return; // A reveal bar has no binding — nothing to retime.
    final bar = _barOf(model, barId);
    final delta = newStart.round() - bar.start.round();
    final delay = binding.delayFrames + delta;
    if (delta == 0 || delay < 0) return;
    widget.onCommand(
      SetAnimationDelayCommand(
        id: binding.elementId,
        index: binding.index,
        delayFrames: delay,
        mergeGroup: _dragGroup,
      ),
    );
  }

  void _barResized(SlideTimelineModel model, String barId, double newStart, double newEnd) {
    final binding = model.bindings[barId];
    if (binding == null) return; // A reveal bar has no binding — nothing to trim.
    final bar = _barOf(model, barId);
    final startDelta = newStart.round() - bar.start.round();
    final duration = newEnd.round() - newStart.round();
    final delay = binding.delayFrames + startDelta;
    if (duration < 1 || delay < 0) return;
    // A keyframes bar with authored positions keeps its stops proportional
    // through the trim; when the new span cannot hold them, the trim stops.
    List<int>? positions;
    if (binding.stopFrames != null && _animationOf(binding).containsKey('positions')) {
      positions = rescaledStopFrames(
        binding.stopFrames!,
        from: binding.durationFrames,
        to: duration,
      );
      if (positions == null) return;
    }
    widget.onCommand(
      SetAnimationDurationCommand(
        id: binding.elementId,
        index: binding.index,
        durationFrames: duration,
        delayFrames: startDelta == 0 ? null : delay,
        positionFrames: positions,
        mergeGroup: _dragGroup,
      ),
    );
  }

  void _barTapped(SlideTimelineModel model, String barId, {bool additive = false}) {
    final binding = model.bindings[barId];
    // A binding-less bar is a reveal bar `<elementId>:reveal`; select its
    // element instead, since there is no animation to select.
    final elementId = binding == null ? _revealElementId(barId) : binding.elementId;
    ref.read(selectionProvider.notifier).click(elementId, additive: additive);
    ref.read(keyframeSelectionProvider.notifier).clear();
    _clearOverlaySelection();
  }

  /// The element id behind a reveal bar id `<elementId>:reveal`.
  String _revealElementId(String barId) => barId.substring(0, barId.length - ':reveal'.length);

  /// A tap on a track's label: selects its element (the slide track id is the
  /// element id), the way a bar tap selects a bound bar's element — so even a
  /// bar-less element is reachable from the timeline.
  void _labelTapped(String trackId) {
    ref.read(selectionProvider.notifier).click(trackId);
    ref.read(keyframeSelectionProvider.notifier).clear();
    _clearOverlaySelection();
  }

  /// A lane tap: with the playhead inside a keyframes bar of the tapped
  /// track it adds a stop there (values interpolated for continuity);
  /// anywhere else it scrubs. Tracks without a keyframes animation never
  /// grow one here — the Animate panel is the way in.
  void _trackTapped(SlideTimelineModel model, String trackId, double frame) {
    for (final track in model.tracks) {
      if (track.id != trackId) continue;
      for (final bar in track.bars) {
        final binding = model.bindings[bar.id];
        // A reveal bar carries no binding and accepts no keyframe stop.
        if (binding == null ||
            binding.stopFrames == null ||
            _playhead < bar.start ||
            _playhead > bar.end) {
          continue;
        }
        final inserted = insertedStop(
          stops: _animationOf(binding)['keyframes']! as List,
          stopFrames: binding.stopFrames!,
          offset: _playhead - bar.start.round(),
        );
        if (inserted != null) {
          widget.onCommand(
            InsertKeyframeStopCommand(
              id: binding.elementId,
              index: binding.index,
              stop: inserted.stop,
              keyframe: inserted.keyframe,
              positionFrames: inserted.positionFrames,
            ),
          );
        }
        return;
      }
    }
    _scrub(model, frame);
  }

  void _diamondMoved(SlideTimelineModel model, String barId, String diamondId, double frame) {
    final diamond = model.diamondBindings[diamondId];
    final binding = model.bindings[barId];
    if (diamond == null || binding == null) return;
    final moved = movedStopFrames(
      stopFrames: binding.stopFrames!,
      stop: diamond.stop,
      offset: (frame - _barOf(model, barId).start).round(),
      span: binding.durationFrames,
    );
    if (moved == null) return;
    widget.onCommand(
      SetKeyframePositionsCommand(
        id: binding.elementId,
        index: binding.index,
        positionFrames: moved,
        mergeGroup: _dragGroup,
      ),
    );
  }

  void _diamondTapped(SlideTimelineModel model, String barId, String diamondId) {
    final diamond = model.diamondBindings[diamondId];
    final binding = model.bindings[barId];
    if (diamond == null || binding == null) return;
    ref.read(selectionProvider.notifier).click(binding.elementId);
    _clearOverlaySelection();
    ref
        .read(keyframeSelectionProvider.notifier)
        .select(
          SelectedKeyframe(
            elementId: binding.elementId,
            animation: binding.index,
            stop: diamond.stop,
          ),
        );
  }

  /// Deletes the stop; a bar already at the two-stop minimum loses the
  /// whole animation instead (a one-stop keyframes form is invalid).
  void _diamondDeleted(SlideTimelineModel model, String barId, String diamondId) {
    final diamond = model.diamondBindings[diamondId];
    final binding = model.bindings[barId];
    if (diamond == null || binding == null) return;
    if (binding.stopFrames!.length <= 2) {
      widget.onCommand(RemoveAnimationCommand(id: binding.elementId, index: binding.index));
    } else {
      widget.onCommand(
        RemoveKeyframeStopCommand(
          id: binding.elementId,
          index: binding.index,
          stop: diamond.stop,
        ),
      );
    }
    ref.read(keyframeSelectionProvider.notifier).clear();
  }

  TimelineBar _barOf(SlideTimelineModel model, String barId) =>
      model.tracks.expand((track) => track.bars).firstWhere((bar) => bar.id == barId);

  /// The authored JSON of the bound animation — where the edit handlers
  /// check for authored `positions` and read the stop values.
  Map<String, Object?> _animationOf(TimelineBarBinding binding) =>
      ((widget.document.elementJson(binding.elementId)!['animate']! as List)[binding.index]! as Map)
          .cast<String, Object?>();

  /// The topmost element of the slide, or null on an element-less slide —
  /// who the empty state's add-animation action targets.
  String? get _topmostElement {
    final ids = widget.document.elementIdsInScene(widget.slide);
    return ids.isEmpty ? null : ids.last;
  }

  void _addAnimation() {
    final id = _topmostElement;
    if (id == null) return;
    widget.onCommand(AddAnimationCommand(id: id, animation: const {'preset': 'fadeIn'}));
  }
}
