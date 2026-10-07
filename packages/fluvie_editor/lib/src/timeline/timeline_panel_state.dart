part of 'timeline_panel.dart';

final class _TimelinePanelState extends ConsumerState<TimelinePanel> {
  // The concept calls the timeline the centerpiece, so it starts open.
  bool _open = true;
  int _playhead = 0;
  FrameRange? _range;
  int _dragSeq = 0;
  String? _dragGroup;
  String? _selectedLinkId;
  String? _selectedMarkerId;
  String? _modelKey;
  late SlideTimelineModel _model;

  @override
  void didUpdateWidget(TimelinePanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.slide != oldWidget.slide) {
      _playhead = 0;
      _range = null;
      _selectedLinkId = null;
      _selectedMarkerId = null;
    }
  }

  SlideTimelineModel _buildModel(TimelinePhasePalette palette, TimelineLinkPalette linkPalette) {
    final key =
        '${widget.document.documentDigest}:${widget.slide}:${palette.hashCode}:${linkPalette.hashCode}';
    if (key != _modelKey) {
      _modelKey = key;
      _model = SlideTimelineModel.build(
        document: widget.document,
        slide: widget.slide,
        palette: palette,
        linkPalette: linkPalette,
      );
    }
    return _model;
  }

  /// [setState] for the transport part (the member is protected).
  void _refresh(VoidCallback change) => setState(change);

  /// Bar and diamond selections drop any selected link or marker — one
  /// selected thing at a time.
  void _clearOverlaySelection() {
    if (_selectedLinkId == null && _selectedMarkerId == null) return;
    _selectOverlay();
  }

  /// Selects [link] or [marker] (or neither), exclusively.
  void _selectOverlay({String? link, String? marker}) => setState(() {
    _selectedLinkId = link;
    _selectedMarkerId = marker;
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final model = _buildModel(
      TimelinePhasePalette(
        enter: colors.success.base,
        during: colors.warning.base,
        exit: colors.error.base,
      ),
      TimelineLinkPalette(ends: colors.accent.base, starts: colors.info.base),
    );
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(top: BorderSide(color: colors.borderSubtle)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          _header(context, model),
          if (_open) SizedBox(height: widget.height, child: _body(context, model)),
        ],
      ),
    );
  }

  /// The body: the track timeline on the shared playhead when a transport
  /// exists (rebuilding per frame), on the panel's own otherwise.
  Widget _body(BuildContext context, SlideTimelineModel model) {
    final transport = widget.transport;
    if (transport == null) return _timeline(context, model);
    return ValueListenableBuilder<int>(
      valueListenable: transport.frames,
      builder: (context, _, _) => _timeline(context, model),
    );
  }

  Widget _timeline(BuildContext context, SlideTimelineModel model) {
    final selectedKeyframe = ref.watch(keyframeSelectionProvider);
    final empty = !model.hasBars;
    final range = _range;
    return TrackTimeline(
      tracks: empty ? const [] : model.tracks,
      links: model.links,
      markers: model.markers,
      fps: model.fps.toDouble(),
      totalFrames: model.totalFrames.toDouble(),
      playhead: _playheadFrame().clamp(0, model.totalFrames).toDouble(),
      selection: TrackTimelineSelection(
        selectedDiamondId: selectedKeyframe == null
            ? null
            : '${selectedKeyframe.elementId}:${selectedKeyframe.animation}:k${selectedKeyframe.stop}',
        selectedLinkId: _selectedLinkId,
        selectedMarkerId: _selectedMarkerId,
        selectedTrackIds: ref.watch(selectionProvider),
        rangeSelection: range == null
            ? null
            : (start: range.start.toDouble(), end: range.end.toDouble()),
      ),
      navigation: TrackTimelineNavigation(
        onLabelTapped: _labelTapped,
        onScrub: (frame) => _scrub(model, frame),
        onRangeSelected: _rangeSelected,
        onRangeCleared: _rangeCleared,
        onBarTapped: (barId, {required additive}) => _barTapped(model, barId, additive: additive),
        onTrackTapped: (trackId, frame) => _trackTapped(model, trackId, frame),
      ),
      appearance: TrackTimelineAppearance(
        emptyMessage: _topmostElement == null
            ? 'Add an element to animate it.'
            : 'No animations on this slide yet.',
        emptyAction: _topmostElement == null
            ? null
            : OiButton.secondary(label: 'Add an animation', onTap: _addAnimation),
      ),
      edit: TrackTimelineEditActions(
        onDragStarted: (_) => _dragGroup = 'timeline-drag-${_dragSeq++}',
        onDragEnded: (_) => _dragGroup = null,
        // The lane is ignored here: an animation lane is one element phase
        // row, not a place a bar can be moved to.
        onBarMoved: (barId, newStart, _) => _barMoved(model, barId, newStart),
        onBarResized: (barId, newStart, newEnd) => _barResized(model, barId, newStart, newEnd),
        onEasingTapped: (_) =>
            ref.read(inspectorTabRequestProvider.notifier).reveal(InspectorTab.animation),
      ),
      overlays: TrackTimelineOverlayActions(
        onDiamondTapped: (barId, diamondId) => _diamondTapped(model, barId, diamondId),
        onDiamondMoved: (barId, diamondId, frame) => _diamondMoved(model, barId, diamondId, frame),
        onDiamondDeleted: (barId, diamondId) => _diamondDeleted(model, barId, diamondId),
        onLinkDropped: (fromBarId, toBarId) => _linkDropped(model, fromBarId, toBarId),
        onLinkTapped: _linkTapped,
        onLinkDeleted: (linkId) => _linkDeleted(model, linkId),
        onMarkerMoved: (id, frame) => _markerMoved(model, id, frame),
        onMarkerInserted: (frame) => _markerInserted(model, frame),
        onMarkerRemoved: (id) => _markerRemoved(model, id),
        onMarkerTapped: _markerTapped,
      ),
    );
  }
}
