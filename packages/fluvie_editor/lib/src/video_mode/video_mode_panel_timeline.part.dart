part of 'video_mode_panel.dart';

final class _VideoModeTimelineView extends StatelessWidget {
  const _VideoModeTimelineView({
    required this.owner,
    required this.model,
    required this.tracks,
    required this.selectedTrackIds,
    required this.selectedBarIds,
  });

  final _VideoModePanelState owner;
  final VideoLaneModel model;
  final List<TimelineTrack> tracks;
  final Set<String> selectedTrackIds;
  final Set<String> selectedBarIds;

  @override
  Widget build(BuildContext context) {
    return TrackTimeline(
      tracks: tracks,
      onFilmstripNeeded: owner.widget.onFilmstripNeeded,
      markers: model.markers,
      controller: owner._zoom,
      fps: model.fps.toDouble(),
      totalFrames: model.totalFrames.toDouble(),
      playhead: owner.widget.transport.frame.clamp(0, model.totalFrames).toDouble(),
      selection: TrackTimelineSelection(
        selectedTrackIds: selectedTrackIds,
        selectedBarIds: selectedBarIds,
        selectedDiamondId: model.effectDiamonds.containsKey(owner._selectedDiamondId)
            ? owner._selectedDiamondId
            : null,
      ),
      snapFrame: owner._snapFrame,
      appearance: const TrackTimelineAppearance(
        emptyMessage: 'Nothing placed in time yet. Import media to lay out clips and audio.',
      ),
      navigation: TrackTimelineNavigation(
        onScrub: (frame) => owner._scrub(model, frame),
        onLabelTapped: owner._labelTapped,
        onBarTapped: (barId, {required additive}) =>
            owner._barTapped(model, barId, additive: additive),
        onBarsMarqueed: (barIds, {required additive}) =>
            owner.ref.read(timelineSelectionProvider.notifier).marquee(barIds, additive: additive),
        onTrackTapped: (trackId, frame) => owner._fxTrackTapped(model, trackId, frame),
      ),
      lanes: TrackTimelineLaneActions(
        onLaneLockToggled: (row) => owner._toggleLane(row, 'locked'),
        onLaneMuteToggled: (row) => owner._toggleLane(row, 'muted'),
        onLaneSoloToggled: owner.widget.audioMonitor == null ? null : owner._soloToggled,
        onLaneReordered: (row, to) => owner._reorderLane(model, row, to),
      ),
      edit: TrackTimelineEditActions(
        onDragStarted: (dragId) => owner._dragStarted(model, dragId),
        onDragEnded: owner._dragEnded,
        onBarMoved: (barId, newStart, targetRow) =>
            owner._barMoved(model, barId, newStart, targetRow),
        onBarResized: (barId, newStart, newEnd) =>
            owner._apply(owner._edgeDrag(model, barId, newStart, newEnd)),
        onEasingTapped: (_) =>
            owner.ref.read(inspectorTabRequestProvider.notifier).reveal(InspectorTab.animation),
        onForeignDrop: (data, barId, frame) => owner._fxDropped(model, data, barId),
        onForeignLaneDrop: (data, row, barId, frame) =>
            owner._foreignLaneDrop(model, data, row, barId, frame),
      ),
      overlays: TrackTimelineOverlayActions(
        onDiamondTapped: (barId, diamondId) => owner._fxDiamondTapped(model, barId, diamondId),
        onDiamondMoved: (barId, diamondId, frame) =>
            owner._fxDiamondMoved(model, barId, diamondId, frame),
        onDiamondDeleted: (barId, diamondId) => owner._fxDiamondDeleted(model, barId, diamondId),
        // The boundary hairlines: dragging one retimes the slide before it.
        // A bar edge is a clip cut and a hairline is a slide boundary; they are
        // different gestures because they have different consequences.
        onMarkerMoved: (id, frame) => owner._boundaryDragged(model, id, frame),
      ),
    );
  }
}
