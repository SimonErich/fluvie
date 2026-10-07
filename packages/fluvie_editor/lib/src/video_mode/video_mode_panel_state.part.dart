part of 'video_mode_panel.dart';

final class _VideoModePanelState extends ConsumerState<VideoModePanel> {
  bool _open = true;
  bool _showTransitions = false;
  bool _rateStretch = false;
  int _dragSeq = 0;
  String? _dragGroup;
  String? _note;
  String? _modelKey;
  TimelineBar? _dragBar;
  String? _selectedDiamondId;
  String? _selectionAnchor;
  double? _lastDragStart;
  Map<String, Object?>? _dragElement;
  Map<String, Map<String, Object?>>? _dragMembers;
  TimelineSnapEngine? _snap;
  double? _snapFrame;
  late VideoLaneModel _model;

  /// Whole videos are long; half the slides zoom keeps a minute in view.
  final TrackTimelineController _zoom = TrackTimelineController(pixelsPerFrame: 2);

  @override
  void initState() {
    super.initState();
    widget.audioMonitor?.addListener(_monitorChanged);
  }

  @override
  void didUpdateWidget(VideoModePanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.audioMonitor != widget.audioMonitor) {
      oldWidget.audioMonitor?.removeListener(_monitorChanged);
      widget.audioMonitor?.addListener(_monitorChanged);
    }
  }

  void _monitorChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.audioMonitor?.removeListener(_monitorChanged);
    _zoom.dispose();
    super.dispose();
  }

  /// [setState] for the header part (the member is protected).
  void _refresh(VoidCallback change) => setState(change);

  VideoLaneModel _buildModel(VideoLanePalette palette) {
    final key = '${widget.document.documentDigest}:${palette.hashCode}';
    if (key != _modelKey) {
      // A document edit shifts stop indices, and a diamond id is positional;
      // carrying the selection across would let Delete hit a stop the user
      // never selected.
      if (_modelKey?.split(':').first != widget.document.documentDigest) {
        _selectedDiamondId = null;
      }
      _modelKey = key;
      _model = VideoLaneModel.build(document: widget.document, palette: palette);
    }
    return _model;
  }

  /// Applies one lane-edit outcome: the command dispatches, the note (a
  /// refusal or clamp explanation) surfaces in the header, and a clean
  /// edit clears any stale note.
  void _apply(VideoLaneEdit? edit) {
    if (edit == null) return;
    if (edit.note != _note) setState(() => _note = edit.note);
    final command = edit.command;
    if (command != null) {
      try {
        if (widget.document.spec.scenes.any((scene) => scene.transitions.isNotEmpty)) {
          command.apply(widget.document);
        }
        widget.onCommand(command);
      } on Object catch (error) {
        setState(() => _note = 'Edit refused: $error');
      }
    }
  }

  void _scrub(VideoLaneModel model, double frame) =>
      widget.transport.seek(frame.round().clamp(0, model.totalFrames));

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final model = _buildModel(
      VideoLanePalette(
        scene: colors.accent.base,
        element: colors.info.base,
        music: colors.success.base,
        sfx: colors.warning.base,
      ),
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
          if (_open && _showTransitions)
            const Padding(padding: EdgeInsets.fromLTRB(12, 2, 12, 8), child: TransitionBrowser()),
          if (_open)
            SizedBox(
              height: widget.height,
              child: ValueListenableBuilder<int>(
                valueListenable: widget.transport.frames,
                builder: (context, _, _) {
                  _pruneSelection(model);
                  final tracks = _quick || model.hasLanes
                      ? _decoratedTracks(model)
                      : const <TimelineTrack>[];
                  final selectedTracks = _selectedTrackIds(model);
                  final selectedBars = ref.watch(timelineSelectionProvider);
                  return _VideoModeTimelineView(
                    owner: this,
                    model: model,
                    tracks: tracks,
                    selectedTrackIds: selectedTracks,
                    selectedBarIds: selectedBars,
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
