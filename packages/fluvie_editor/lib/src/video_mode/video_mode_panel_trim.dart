part of 'video_mode_panel.dart';

/// The modified drags: which verb a bar drag actually is.
///
/// Two pairs, each split by one modifier. On a bar body, **Alt** changes what
/// plays and Shift changes when it plays — a slip and a slide are the same
/// gesture asking opposite questions. On an edge, **Alt** lets the rest of the
/// slide follow the trim and Shift moves the cut itself.
///
/// Every one of them reports through the same [_apply], so a refusal or a
/// clamp explains itself in the header exactly like a plain drag.
extension _VideoModeTrim on _VideoModePanelState {
  bool get _altHeld => HardwareKeyboard.instance.isAltPressed;

  bool get _shiftDrag => HardwareKeyboard.instance.isShiftPressed;

  /// The frames moved since the last update of this drag.
  ///
  /// The stream is read against the pointer rather than against the document,
  /// so a verb that clamps does not keep re-applying the whole travel, and
  /// reversing the drag moves back immediately.
  int _step(double next) {
    final from = _lastDragStart ?? next;
    _lastDragStart = next;
    return next.round() - from.round();
  }

  /// One body drag: a move, a slip, or a slide.
  VideoLaneEdit? _bodyDrag(VideoLaneModel model, String barId, double newStart) {
    final baseline = _dragBar;
    if (_altHeld) {
      // A slip never moves the window, so there is nothing for a snap to
      // catch: the guide would point at a frame the bar is not moving to. The
      // travel is measured from the drag's own baseline, so the trim is
      // written once rather than accumulated.
      if (baseline == null) return null;
      final travel = newStart.round() - baseline.start.round();
      return videoSlipped(
        model,
        barId,
        travel,
        document: widget.document,
        baseline: _dragElement,
        baselineMembers: _dragMembers,
        mergeGroup: _dragGroup,
      );
    }
    if (_shiftDrag) {
      final step = _step(_snappedStart(newStart));
      return step == 0
          ? null
          : videoSlid(model, barId, step, document: widget.document, mergeGroup: _dragGroup);
    }
    return videoBarMoved(model, barId, _snappedStart(newStart), mergeGroup: _dragGroup);
  }

  /// One edge drag: a trim, a ripple trim, or a roll.
  VideoLaneEdit? _edgeDrag(VideoLaneModel model, String barId, double newStart, double newEnd) {
    final transition = model.transitionBars[barId];
    if (transition != null) {
      return transitionResized(
        widget.document,
        transition,
        newStart,
        newEnd,
        mergeGroup: _dragGroup,
      );
    }
    final span = _snappedSpan(newStart, newEnd);
    if (_rateStretch) {
      if (_dragBar?.start != newStart) {
        return const VideoLaneEdit.refused('Rate stretch uses the clip’s right edge.');
      }
      return clipRateStretched(widget.document, model, barId, span.end, mergeGroup: _dragGroup);
    }
    if (_altHeld) {
      return videoRippleTrimmed(
        model,
        barId,
        span.start.round(),
        span.end.round(),
        document: widget.document,
        mergeGroup: _dragGroup,
      );
    }
    if (_shiftDrag) return _roll(model, barId, span);
    return videoBarResized(model, barId, span.start, span.end, mergeGroup: _dragGroup);
  }

  /// A roll from whichever edge the pointer took.
  ///
  /// The head's cut belongs to the clip *before* it, so rolling there rolls
  /// that clip's end: one cut, named from either side of it.
  VideoLaneEdit? _roll(VideoLaneModel model, String barId, ({double start, double end}) span) {
    final binding = model.elementBars[barId];
    final baseline = _dragBar;
    if (binding == null || baseline == null) return null;
    if (span.end != baseline.end) {
      return videoRolled(
        model,
        barId,
        span.end.round() - binding.window.end,
        document: widget.document,
        mergeGroup: _dragGroup,
      );
    }
    final before = barsEndingAt(model, binding.scene, binding.window.start, except: barId);
    if (before.length != 1) {
      return const VideoLaneEdit.refused(
        'No single clip ends where this one starts, so there is no cut to roll.',
      );
    }
    return videoRolled(
      model,
      before.single.barId,
      span.start.round() - binding.window.start,
      document: widget.document,
      mergeGroup: _dragGroup,
    );
  }

  /// A boundary hairline dragged to [frame]: the slide before it is retimed so
  /// its end lands there.
  void _boundaryDragged(VideoLaneModel model, String id, double frame) {
    if (!id.startsWith('boundary:')) return;
    final boundary = int.tryParse(id.substring('boundary:'.length));
    if (boundary == null || boundary < 1) return;
    final scene = boundary - 1;
    final span = model.timebase.sceneSpans[scene];
    _apply(
      videoSceneRetimed(
        model,
        scene,
        frame.round() - span.start,
        document: widget.document,
        mergeGroup: _dragGroup ??= 'retime-${_dragSeq++}',
      ),
    );
  }
}
