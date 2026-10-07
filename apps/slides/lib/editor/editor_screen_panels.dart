part of 'editor_screen.dart';

/// The editor's chrome: the top bar plus panels around the canvas, and the
/// left side's Slides strip and Layers list, fed by the presenter's preview
/// cache over the hidden document render host.
extension _EditorScreenPanels on _EditorScreenState {
  /// The full edit surface: top bar, toolbar, panels, canvas, inspector —
  /// under the transport's Space key, with the shared playhead kept in
  /// sync with the document (a retime moves the slide's bound in place).
  /// In master-edit mode the canvas column and the inspector swap to the
  /// session's synthetic view; the transport stays out of it. The whole
  /// surface sits under [HistoryKeys], so the undo and redo chords reach
  /// the history from any panel focus — the canvas dispatches them itself
  /// through the registry before they ever bubble here.
  Widget _editorBody(BuildContext context) => HistoryKeys(
    canUndo: _history.canUndo,
    canRedo: _history.canRedo,
    onUndo: () => _travel(_history.undo),
    onRedo: () => _travel(_history.redo),
    child: _modeBody(context),
  );

  /// The mode's own surface: master editing, video mode, or the slide view.
  Widget _modeBody(BuildContext context) {
    final master = _editingMasterName;
    if (master != null) {
      return _editorPanels(context, session: MasterEditSession(_history.document, master));
    }
    if (_videoMode) return _videoBody(context);
    _transport.length = _deriver.derive(_history.document, _slide).totalFrames;
    return TransportKeys(
      transport: _transport,
      panelOpen: _timelineOpen,
      stepBounds: () => slideStepBounds(_history.document, _slide),
      onAdvanceSlide: _stepIntoNextSlide,
      child: _editorPanels(context),
    );
  }

  /// The shared top bar; the mode decides the stage indicator and stepper.
  Widget _topBar({
    required int slide,
    required void Function(int delta) onStep,
    required String mode,
  }) => EditorTopBar(
    name: _name,
    onRenamed: _rename,
    saveStatus: _saveStatus,
    saveAttention: _saveStatus == 'Unsaved',
    canUndo: _history.canUndo,
    canRedo: _history.canRedo,
    slide: slide,
    sceneCount: _history.document.sceneCount,
    onClose: () => unawaited(_close()),
    onUndo: () => _travel(_history.undo),
    onRedo: () => _travel(_history.redo),
    onPresent: _present,
    onSave: () => unawaited(_save()),
    onSaveAs: () => unawaited(_save(pickNew: true)),
    onSaveCopy: () => unawaited(_saveCopy()),
    onExportDart: () => unawaited(_exportDart()),
    onExportImages: () => unawaited(_exportImages()),
    onExportPdf: () => unawaited(_exportPdf()),
    onExportVideo: _render.isAvailable ? () => unawaited(_exportVideo()) : null,
    videoUnavailableNote: _render.isAvailable ? 'needs the desktop app' : _render.unavailableNote,
    onStep: onStep,
    mode: mode,
    onMode: _setMode,
    workspaceControl: WorkspaceControl(
      workspace: _workspace,
      onChanged: _setWorkspace,
    ),
    menuBar: EditorMenuBar(
      scope: _menuScope(),
      files: (
        save: () => unawaited(_save()),
        saveAs: () => unawaited(_save(pickNew: true)),
        saveCopy: () => unawaited(_saveCopy()),
        exportDart: () => unawaited(_exportDart()),
        exportImages: () => unawaited(_exportImages()),
        exportPdf: () => unawaited(_exportPdf()),
        exportVideo: _render.isAvailable ? () => unawaited(_exportVideo()) : null,
        videoExportNote: _render.isAvailable ? null : _render.unavailableNote,
        present: _present,
        close: () => unawaited(_close()),
      ),
    ),
  );

  /// The scope the menu bar's command-backed items run against: the open
  /// document at the current slide, with the history wired so undo and redo
  /// read and act exactly as the keyboard does.
  CommandScope _menuScope() => CommandScope(
    document: _history.document,
    slide: _videoMode ? _videoTimebase.sceneAt(_videoTransport!.frame) : _slide,
    dispatch: _history.dispatch,
    selection: _selectionScope.read(selectionProvider),
    select: _selectionScope.read(selectionProvider.notifier).select,
    clipboard: _selectionScope.read(editorClipboardProvider),
    playhead: _videoMode
        ? _videoTransport!.frame
        : _videoTimebase.sceneSpans[_slide].start + _transport.frame,
    timelineSelection: _selectionScope.read(timelineSelectionProvider),
    activeLane: _selectionScope.read(activeTimelineLaneProvider),
    markIn: _selectionScope.read(timelineMarksProvider).markIn,
    markOut: _selectionScope.read(timelineMarksProvider).markOut,
    setMarks: _selectionScope.read(timelineMarksProvider.notifier).set,
    seek: _videoMode
        ? _videoTransport!.seek
        : (frame) => _transport.seek(frame - _videoTimebase.sceneSpans[_slide].start),
    snapEnabled: _selectionScope.read(snapPreferencesProvider).snapping,
    toggleSnap: _selectionScope.read(snapPreferencesProvider.notifier).toggleSnapping,
    canUndo: _history.canUndo,
    canRedo: _history.canRedo,
    undo: () => _travel(_history.undo),
    redo: () => _travel(_history.redo),
    showSlide: _showSlide,
  );

  Widget _editorPanels(BuildContext context, {MasterEditSession? session}) => ColoredBox(
    color: context.colors.background,
    child: Column(
      children: [
        _topBar(slide: _slide, onStep: _step, mode: 'slides'),
        Expanded(
          child: UncontrolledProviderScope(
            container: _selectionScope,
            child: WorkspaceScope(
              workspace: _workspace,
              child: EditorShell(
                settings: widget.layoutSettings,
                toolbar: EditorToolbar(onAssets: () => unawaited(_openAssets())),
                leftColumn: _leftPanel(context),
                stage: session == null ? _stageCanvas(context) : _masterStage(session),
                inspector: InspectorTabs(
                  request: _selectionScope.read(inspectorTabRequestProvider),
                  inspector: _inspector(session),
                  panels: {
                    ..._workspacePanels(video: false),
                    InspectorTab.effects: EffectsPanel(
                      document: _history.document,
                      onCommand: _history.dispatch,
                      playheadProgress: _effectPlayheadProgress,
                    ),
                  },
                ),
                // Master editing has no timeline, so it takes the whole height
                // rather than reserving a band for nothing.
                bottom: session == null ? _bottomBand(context) : null,
              ),
            ),
          ),
        ),
      ],
    ),
  );

  /// Where the playhead sits inside [id]'s alive-window (0..1), for the
  /// Effects tab's diamond collapsing to the value under the playhead. The
  /// slides transport counts frames inside the current slide, so its frame
  /// offsets by the slide's absolute start.
  double? _effectPlayheadProgress(String id) {
    final timebase = VideoTimebase.of(_history.document);
    if (_slide >= timebase.sceneSpans.length) return null;
    return _effectProgressOf(id, timebase.sceneSpans[_slide].start + _transport.frame);
  }

  /// Where the absolute video frame [absoluteFrame] sits inside [id]'s
  /// alive-window: the introspected window for a windowed element, its whole
  /// scene for a bare one, and the whole video for an overlay — the same
  /// span the render resolves the element's keyframed parameters against.
  double? _effectProgressOf(String id, int absoluteFrame) {
    final document = _history.document;
    final introspection = introspectTimeline(document.spec.build());
    FrameSpan? window;
    for (final scene in introspection.scenes) {
      final element = scene.elementById(id);
      if (element != null) {
        window = element.window;
        break;
      }
      final ids = document.elementIdsInScene(scene.index);
      if (ids.contains(id) ||
          ids.any((groupId) => document.childIdsOfGroup(groupId).contains(id))) {
        window = scene.span;
        break;
      }
    }
    window ??= FrameSpan(0, introspection.totalFrames);
    if (window.durationFrames <= 0) return null;
    return ((absoluteFrame - window.start) / window.durationFrames).clamp(0.0, 1.0);
  }
}
