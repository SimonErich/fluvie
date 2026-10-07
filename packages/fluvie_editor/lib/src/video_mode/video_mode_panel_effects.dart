part of 'video_mode_panel.dart';

/// The effect-keyframe gestures: a track tap with the playhead inside the
/// bar inserts a stop there, a diamond drag repositions one, and Delete
/// removes the selected stop (collapsing to a literal at the two-stop
/// minimum — the command's own law).
extension _VideoEffectEdits on _VideoModePanelState {
  /// A lane tap: with the playhead inside an effect bar of the tapped row it
  /// adds a stop there (the value the ramp already reads, for continuity);
  /// anywhere else it scrubs. A still parameter never grows stops here — the
  /// Effects tab is the way in.
  void _fxTrackTapped(VideoLaneModel model, String trackId, double frame) {
    if (trackId.startsWith('fx-track:')) {
      final binding = model.effectBars['fx:${trackId.substring('fx-track:'.length)}'];
      final playhead = widget.transport.frame;
      if (binding != null &&
          binding.stopFramesByParam.isNotEmpty &&
          playhead >= binding.window.start &&
          playhead <= binding.window.end) {
        final param = binding.stopFramesByParam.keys.first;
        final effect = _fxJson(binding.elementId, binding.effectIndex);
        final inserted = insertedEffectStop(
          param: (effect[param]! as Map).cast<String, Object?>(),
          stopFrames: binding.stopFramesByParam[param]!,
          offset: playhead - binding.window.start,
          spanFrames: binding.window.durationFrames,
          fps: model.fps,
        );
        if (inserted != null) {
          widget.onCommand(
            InsertEffectStopCommand(
              id: binding.elementId,
              index: binding.effectIndex,
              param: param,
              stop: inserted.stop,
              // An overshooting easing reads past the range mid-segment; the
              // written stop faces the same range a literal would, so it
              // lands clamped rather than refused.
              value: _clampedToParam(effect['kind'], param, inserted.value),
              positionFrames: inserted.positionFrames,
            ),
          );
        }
        return;
      }
    }
    _scrub(model, frame);
  }

  void _fxDiamondMoved(VideoLaneModel model, String barId, String diamondId, double frame) {
    final diamond = model.effectDiamonds[diamondId];
    final binding = model.effectBars[barId];
    final stopFrames = binding?.stopFramesByParam[diamond?.param];
    if (diamond == null || binding == null || stopFrames == null) return;
    final moved = movedStopFrames(
      stopFrames: stopFrames,
      stop: diamond.stop,
      offset: (frame - binding.window.start).round(),
      span: binding.window.durationFrames,
    );
    if (moved == null) return;
    widget.onCommand(
      SetEffectStopPositionsCommand(
        id: diamond.elementId,
        index: diamond.effectIndex,
        param: diamond.param,
        positionFrames: moved,
        mergeGroup: _dragGroup,
      ),
    );
  }

  void _fxDiamondTapped(VideoLaneModel model, String barId, String diamondId) {
    final diamond = model.effectDiamonds[diamondId];
    if (diamond == null) return;
    ref.read(selectionProvider.notifier).click(diamond.elementId);
    _refresh(() => _selectedDiamondId = diamondId);
  }

  void _fxDiamondDeleted(VideoLaneModel model, String barId, String diamondId) {
    final diamond = model.effectDiamonds[diamondId];
    if (diamond == null) return;
    widget.onCommand(
      RemoveEffectStopCommand(
        id: diamond.elementId,
        index: diamond.effectIndex,
        param: diamond.param,
        stop: diamond.stop,
      ),
    );
    _refresh(() => _selectedDiamondId = null);
  }

  /// An effect chip dropped on a bar: its element gains the effect, through
  /// exactly the command a browser tap dispatches. Between bars the drop is
  /// a no-op — there is nothing to put it on.
  void _fxDropped(VideoLaneModel model, Object data, String? barId) {
    if (data is! EffectDragData || barId == null) return;
    final id =
        model.elementBars[barId]?.elementId ??
        model.overlayBars[barId]?.elementId ??
        model.effectBars[barId]?.elementId;
    if (id == null) return;
    widget.onCommand(AddEffectCommand(id: id, effect: data.effect));
  }

  /// The current JSON of one effect — what an insert reads to interpolate
  /// the value the ramp already shows, and to find the parameter's range.
  Map<String, Object?> _fxJson(String id, int index) {
    final effects = widget.document.elementJson(id)!['effects']! as List;
    return (effects[index]! as Map).cast<String, Object?>();
  }
}

/// [value] clamped to the declared range of [param] on the effect [kind].
double _clampedToParam(Object? kind, String param, double value) {
  for (final specKind in EffectSpecKind.values) {
    if (specKind.name != kind) continue;
    for (final declared in specKind.params) {
      if (declared.name == param) return value.clamp(declared.min, declared.max);
    }
  }
  return value;
}
