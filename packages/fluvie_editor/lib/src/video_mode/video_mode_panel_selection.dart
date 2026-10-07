part of 'video_mode_panel.dart';

/// The video timeline's selection <-> lane bridge: which lanes paint as
/// selected, and how a label tap routes back to a selection.
extension _VideoModeSelection on _VideoModePanelState {
  /// Drops selected bar ids this build no longer draws.
  ///
  /// Bars come and go as the document changes — a razored clip becomes two,
  /// a deleted one becomes none — and a selection holding an id nothing draws
  /// would let a verb aim at a bar that is not there. Deferred to after the
  /// frame because a build must not write provider state.
  void _pruneSelection(VideoLaneModel model) {
    final live = {
      for (final row in model.tracks)
        for (final bar in row.bars) bar.id,
    };
    if (ref.read(timelineSelectionProvider).every(live.contains)) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(timelineSelectionProvider.notifier).prune(live);
    });
  }

  /// A tap on a lane's label, mirroring `_barTapped`'s routing: an element
  /// lane selects its element, an audio lane selects its track, and the
  /// scenes lane has no single thing to select.
  void _labelTapped(String trackId) {
    ref.read(activeTimelineLaneProvider.notifier).select(laneIdOfRow(trackId));
    final row = _decoratedTracks(_model).where((row) => row.id == trackId).firstOrNull;
    if (row == null || row.bars.isEmpty || trackId == 'scenes') return;
    _barTapped(_model, row.bars.first.id, additive: false);
  }

  /// Selection follows the row that actually contains the bar, including
  /// overlays and elements assigned to a declared lane.
  Set<String> _selectedTrackIds(VideoLaneModel model) {
    final selected = ref.watch(selectionProvider);
    final audio = ref.watch(audioSelectionProvider);
    final bars = <String>{
      for (final entry in model.elementBars.entries)
        if (selected.contains(entry.value.elementId) ||
            entry.value.members.any((member) => selected.contains(member.elementId)))
          entry.key,
      for (final entry in model.overlayBars.entries)
        if (selected.contains(entry.value.elementId)) entry.key,
      for (final entry in model.audioBars.entries)
        if (audio != null && entry.value.scene == audio.scene && entry.value.index == audio.index)
          entry.key,
    };
    return {
      for (final row in _decoratedTracks(model))
        if (row.bars.any((bar) => bars.contains(bar.id))) row.id,
    };
  }

  void _barTapped(VideoLaneModel model, String barId, {required bool additive}) {
    ref.read(activeTimelineLaneProvider.notifier).select(laneIdOfRow(model.rowOf(barId) ?? ''));
    final selection = ref.read(timelineSelectionProvider.notifier);
    if (HardwareKeyboard.instance.isShiftPressed && _selectionAnchor != null) {
      final ordered = [for (final row in model.tracks) ...row.bars.map((bar) => bar.id)];
      final from = ordered.indexOf(_selectionAnchor!);
      final to = ordered.indexOf(barId);
      if (from >= 0 && to >= 0) {
        selection.select(
          ordered.sublist(from < to ? from : to, (from > to ? from : to) + 1).toSet(),
        );
      } else {
        selection.click(barId, additive: additive);
      }
    } else {
      selection.click(barId, additive: additive);
      _selectionAnchor = barId;
    }
    final overlay = model.overlayBars[barId];
    if (overlay != null) {
      ref.read(selectionProvider.notifier).click(overlay.elementId, additive: additive);
      ref.read(audioSelectionProvider.notifier).clear();
      return;
    }
    final element = model.elementBars[barId];
    if (element != null) {
      final scene = model.timebase.sceneAt(widget.transport.frame);
      final member = element.members.where((member) => member.scene == scene).firstOrNull;
      ref
          .read(selectionProvider.notifier)
          .click(member?.elementId ?? element.elementId, additive: additive);
      ref.read(audioSelectionProvider.notifier).clear();
      return;
    }
    final audio = model.audioBars[barId];
    if (audio != null) {
      ref.read(selectionProvider.notifier).clear();
      ref
          .read(audioSelectionProvider.notifier)
          .select(SelectedAudioTrack(scene: audio.scene, index: audio.index));
      return;
    }
    // An effect bar stands for its element: same selection a bar tap on the
    // element itself would make.
    final effect = model.effectBars[barId];
    if (effect != null) {
      ref.read(selectionProvider.notifier).click(effect.elementId);
      ref.read(audioSelectionProvider.notifier).clear();
      return;
    }
    // A scene block: put the playhead on the scene's settled frame, past any
    // incoming transition — its span start would park mid-blend, where the
    // canvas geometry no longer matches the render.
    if (!barId.startsWith('scene:')) return;
    final scene = int.tryParse(barId.substring('scene:'.length));
    if (scene != null && scene >= 0 && scene < model.timebase.sceneSpans.length) {
      widget.transport.seek(model.timebase.settleFrameOf(scene));
    }
  }
}
