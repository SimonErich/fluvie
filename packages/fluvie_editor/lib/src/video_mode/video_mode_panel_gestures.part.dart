part of 'video_mode_panel.dart';

extension _VideoModeGestures on _VideoModePanelState {
  void _soloToggled(String row) {
    final lane = laneIdOfRow(row);
    if (lane != null) widget.audioMonitor!.toggleSolo(lane);
  }

  void _dragStarted(VideoLaneModel model, String dragId) {
    _dragGroup = 'video-drag-${_dragSeq++}';
    _armSnap(model, dragId);
  }

  void _dragEnded(String _) {
    _dragGroup = null;
    _disarmSnap();
  }

  void _barMoved(VideoLaneModel model, String barId, double newStart, String targetRow) {
    final relaned = videoBarRelaned(
      model,
      barId,
      targetRow,
      document: widget.document,
      mergeGroup: _dragGroup,
    );
    // Refuse an incoming locked lane before changing either space or time.
    if (relaned?.command == null && relaned?.note != null) {
      _apply(relaned);
      return;
    }
    final original = videoBarById(model, barId);
    final moved = original?.start == newStart && !_altHeld
        ? null
        : _bodyDrag(model, barId, newStart);
    if (moved?.command == null && moved?.note != null && relaned == null) {
      _apply(moved);
      return;
    }
    final commands = <EditorCommand>[?moved?.command, ?relaned?.command];
    if (commands.isEmpty) return;
    final command = SequenceCommand(
      commands,
      label: 'Move timeline material',
      mergeGroup: _dragGroup,
    );
    final note = moved?.note;
    _apply(note == null ? VideoLaneEdit.command(command) : VideoLaneEdit.clamped(command, note));
  }

  void _foreignLaneDrop(
    VideoLaneModel model,
    Object data,
    String row,
    String? barId,
    double frame,
  ) {
    if (data is TransitionDragData) {
      _apply(
        transitionDropped(
          widget.document,
          model,
          _sourceRow(model, row, audio: false),
          frame,
          data,
        ),
      );
    } else if (data is SourceMonitorPlacement) {
      final isAudio = data.entry.kind == MediaStoreKind.audio;
      if (_quick && ((row == 'quick:audio') != isAudio)) {
        _apply(
          const VideoLaneEdit.refused(
            'Audio belongs on the Audio lane; picture sources belong on the Picture lane.',
          ),
        );
        return;
      }
      final targetRow = _sourceRow(model, row, audio: isAudio);
      if (model.tracks.any((track) => track.id == targetRow && track.locked)) {
        _apply(const VideoLaneEdit.refused('Unlock the lane before placing media.'));
        return;
      }
      final lane = widget.document.spec.lanes
          .where((lane) => lane.id == laneIdOfRow(targetRow))
          .firstOrNull;
      if (lane != null &&
          ((lane.kind.name == 'audio') != (data.entry.kind == MediaStoreKind.audio))) {
        _apply(
          const VideoLaneEdit.refused(
            'Audio belongs on an audio lane; picture sources belong on a video lane.',
          ),
        );
        return;
      }
      if (widget.onSourceDropped == null) {
        _apply(
          const VideoLaneEdit.refused('This timeline host does not support source placement.'),
        );
        return;
      }
      if (_note != null) _refresh(() => _note = null);
      widget.onSourceDropped?.call(data, targetRow, frame.round());
    } else {
      _fxDropped(model, data, barId);
    }
  }
}
