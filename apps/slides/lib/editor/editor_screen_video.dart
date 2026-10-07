part of 'editor_screen.dart';

/// The video-mode surface: the same document on an absolute clock — the
/// whole-video canvas, the lane timeline under it, the media store on the
/// left, and an inspector that follows the scene under the playhead.
extension _EditorScreenVideo on _EditorScreenState {
  /// Whether the document remembers video mode (`editor.deck.mode`).
  bool get _videoMode => _history.document.deckMeta['mode'] == 'video';

  /// The whole-video clock reference, rebuilt when the render digest moves.
  VideoTimebase get _videoTimebase {
    final digest = _history.document.renderDigest;
    if (digest != _timebaseDigest) {
      _timebaseDigest = digest;
      _timebaseCache = VideoTimebase.of(_history.document);
    }
    return _timebaseCache;
  }

  /// Keeps the whole-video transport in step with the mode: entering video
  /// mode creates it, leaving retires it after the frame that unmounts its
  /// player.
  void _syncVideoTransport() {
    if (_videoMode &&
        (_videoTransport == null || _videoTransport!.fps != _history.document.spec.fps)) {
      final retired = _videoTransport;
      final fps = _history.document.spec.fps;
      final timebase = _videoTimebase;
      _videoTransport = SlideTransport(
        fps: _history.document.spec.fps,
        length: timebase.totalFrames,
        // Open on the current scene settled, like the slides transport — not
        // at frame zero, where an entrance or transition still displaces it.
        initialFrame: retired == null
            ? timebase.settleFrameOf(_slide)
            : (retired.frame * fps / retired.fps).round(),
      );
      if (retired != null) WidgetsBinding.instance.addPostFrameCallback((_) => retired.dispose());
    } else if (!_videoMode && _videoTransport != null) {
      final retired = _videoTransport!;
      WidgetsBinding.instance.addPostFrameCallback((_) => retired.dispose());
      _videoTransport = null;
    }
  }

  /// The top bar's mode pick: one undoable step writing `editor.deck.mode`
  /// through the 9.4 deck-meta channel. Both clocks pause across the swap.
  void _setMode(String mode) {
    if ((_videoMode ? 'video' : 'slides') == mode) return;
    _editMaster(null);
    _transport.pause();
    _videoTransport?.pause();
    _history.dispatch(SetDeckMetaCommand(meta: {'mode': mode}));
  }

  /// The stepper in video mode: the playhead jumps to each scene's settled
  /// frame on the one shared clock — past any incoming transition, where the
  /// scene's geometry matches the render.
  void _stepVideoScene(int delta) {
    final timebase = _videoTimebase;
    final transport = _videoTransport!;
    final scene = (timebase.sceneAt(transport.frame) + delta).clamp(
      0,
      timebase.sceneSpans.length - 1,
    );
    transport.seek(timebase.settleFrameOf(scene));
  }

  Widget _videoBody(BuildContext context) {
    // A retime moves the bound in place, like the slides transport.
    final transport = _videoTransport!..length = _videoTimebase.totalFrames;
    return TransportKeys(
      transport: transport,
      panelOpen: true,
      stepBounds: () => const [],
      child: SceneUnderPlayhead(
        transport: transport,
        timebase: _videoTimebase,
        builder: _videoPanels,
      ),
    );
  }

  Widget _videoPanels(BuildContext context, int scene) => ColoredBox(
    color: context.colors.background,
    child: Column(
      children: [
        KeyedSubtree(
          key: _quickExport,
          child: _topBar(slide: scene, onStep: _stepVideoScene, mode: 'video'),
        ),
        Expanded(
          child: UncontrolledProviderScope(
            container: _selectionScope,
            child: WorkspaceScope(
              workspace: _workspace,
              child: EditorShell(
                settings: widget.layoutSettings,
                toolbar: EditorToolbar(onAssets: () => unawaited(_openAssets(scene: scene))),
                leftColumn: KeyedSubtree(
                  key: _quickLibrary,
                  child: _videoAssetsPanel(context, scene),
                ),
                stage: _videoStage(scene),
                inspector: _videoInspector(scene),
                bottom: LayoutBuilder(
                  key: _quickTimeline,
                  builder: (context, constraints) => ListenableBuilder(
                    listenable: Listenable.merge([_filmstrips, _audioPreview, _audioMonitor]),
                    builder: (context, _) => VideoModePanel(
                      document: _history.document,
                      thumbnailsByBar: _filmstrips.thumbnails,
                      laneEnvelopes: _timelineWaveforms,
                      onFilmstripNeeded: (from, to) =>
                          _filmstrips.request(_history.document, from, to),
                      transport: _videoTransport!,
                      onCommand: _history.dispatch,
                      audioMonitor: _audioMonitor,
                      onSourceDropped: (source, row, frame) => _placeSourceRange(
                        source,
                        lane: row.startsWith('lane:') ? row.substring(5) : null,
                        atFrame: frame,
                      ),
                      height: (constraints.maxHeight - 48).clamp(40, 600),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    ),
  );

  /// Video mode's left panel: the media store, ready for reuse — the 9.4
  /// assets surface as a fixture instead of a dialog.
  Widget _videoAssetsPanel(BuildContext context, int scene) => _workspace == EditorWorkspace.deliver
      ? _deliveryPanel()
      : ColoredBox(
          color: context.colors.surface,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.all(8),
                child: OiSegmentedControl<bool>(
                  selected: _videoTitles,
                  semanticLabel: 'Library',
                  segments: const [
                    OiSegment(value: false, label: 'Assets'),
                    OiSegment(value: true, label: 'Titles'),
                  ],
                  onChanged: (value) => _refresh(() => _videoTitles = value),
                ),
              ),
              Expanded(
                child: _videoTitles
                    ? _titles(
                        scene,
                        _videoTransport!.frame - _videoTimebase.sceneSpans[scene].start,
                      )
                    : OiFileDropTarget(
                        dropMessage: 'Drop media to add it to the deck',
                        onInternalDrop: (_, _) {},
                        onExternalDrop: (files) {
                          if (files.isNotEmpty) {
                            unawaited(_dropIntoBin(files.first.name, files.first.bytes));
                          }
                        },
                        child: MediaBinPanel(
                          entries: _history.document.mediaEntries,
                          onEntryChanged: (entry) =>
                              _history.dispatch(UpdateMediaEntryCommand(entry: entry)),
                          onPlace: _placeSourceRange,
                          previewBuilder: (context, entry, frame) => _sourcePreview(entry, frame),
                          onImport: () => unawaited(_importIntoBin()),
                        ),
                      ),
              ),
            ],
          ),
        );
}
