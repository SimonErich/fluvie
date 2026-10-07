part of 'video_mode_panel.dart';

/// The video timeline's snapping: what one drag can catch on, and the guide
/// the lanes draw while it does.
///
/// The engine is built once per drag from the model as it stood before the
/// first move, so the candidates cannot drift under the pointer as the
/// document changes beneath it.
extension _VideoModeSnap on _VideoModePanelState {
  /// Arms the snap engine for the drag on [dragId].
  void _armSnap(VideoLaneModel model, String dragId) {
    _dragBar = videoBarById(model, dragId);
    // The first update is measured from the bar as it was, or a drag would
    // silently swallow its own first move.
    _lastDragStart = _dragBar?.start;
    final binding = model.elementBars[dragId];
    _dragElement = binding == null ? null : widget.document.elementJson(binding.elementId);
    _dragMembers = binding == null || binding.members.isEmpty
        ? null
        : {
            for (final member in binding.members)
              member.elementId: widget.document.elementJson(member.elementId)!,
          };
    _snap = videoLaneSnapEngine(
      model,
      draggedBarId: dragId,
      playhead: widget.transport.frame,
      pixelsPerFrame: _zoom.pixelsPerFrame,
    );
  }

  /// Ends the drag: no engine, no baseline, no guide.
  void _disarmSnap() {
    _dragBar = null;
    _dragElement = null;
    _dragMembers = null;
    _lastDragStart = null;
    _snap = null;
    if (_snapFrame != null) _refresh(() => _snapFrame = null);
  }

  /// Whether this gesture snaps at all.
  ///
  /// Ctrl lets one drag through and the canvas's snapping preference turns it
  /// off for good: the timeline reads the same switch rather than owning a
  /// second one that can disagree with the first, and one modifier means one
  /// thing wherever it is held.
  bool get _snapBypassed =>
      HardwareKeyboard.instance.isControlPressed ||
      HardwareKeyboard.instance.isMetaPressed ||
      !ref.read(snapPreferencesProvider).snapping;

  /// Where a moved bar should start, catching on either of its edges.
  double _snappedStart(double newStart) {
    final engine = _snap;
    final bar = _dragBar;
    if (engine == null || bar == null) return newStart;
    return _landed(
      engine.snapBar(
        newStart.round(),
        length: (bar.end - bar.start).round(),
        bypass: _snapBypassed,
      ),
      newStart,
    );
  }

  /// The span a trimmed bar should take.
  ///
  /// Only the edge that actually moved snaps, measured against the bar as it
  /// was when the drag began. Snapping the other one would pull an edge the
  /// pointer never touched onto a candidate of its own, which reads as the
  /// timeline trimming something it was not asked to.
  ({double start, double end}) _snappedSpan(double newStart, double newEnd) {
    final engine = _snap;
    final bar = _dragBar;
    if (engine == null || bar == null) return (start: newStart, end: newEnd);
    if (newStart != bar.start) {
      return (
        start: _landed(engine.snap(newStart.round(), bypass: _snapBypassed), newStart),
        end: newEnd,
      );
    }
    if (newEnd != bar.end) {
      return (
        start: newStart,
        end: _landed(engine.snap(newEnd.round(), bypass: _snapBypassed), newEnd),
      );
    }
    return (start: newStart, end: newEnd);
  }

  /// Publishes where the guide belongs and answers with the frame to write:
  /// the candidate's when one caught the drag, [free] when none did.
  double _landed(TimelineSnap snap, double free) {
    final guide = snap.candidate?.frame.toDouble();
    if (guide != _snapFrame) _refresh(() => _snapFrame = guide);
    return snap.snapped ? snap.frame.toDouble() : free;
  }
}
