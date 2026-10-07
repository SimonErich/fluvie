part of 'editor_screen.dart';

final class _EditorScreenState extends State<EditorScreen> {
  late final DocumentHistory _history = DocumentHistory(widget.document)..addListener(_onHistory);
  late final FluvieFileSaver _saver = widget.saver ?? FluvieFileSaver.platform();
  late final SessionMediaStore _sessionMedia = widget.sessionMedia ?? sessionMediaStore;
  late final DeckRenderService _render = widget.render ?? DeckRenderService.platform();
  late final SlideImageExporter _images = widget.images ?? SlideImageExporter.platform();
  late final RenderQueue<_QueuedVideo> _renderQueue = RenderQueue(
    render: (job, cancellation, progress) => _render.renderToVideo(
      spec: job.spec,
      suggestedName: job.name,
      options: job.options,
      cancellation: cancellation,
      onProgress: progress,
    ),
  );
  bool _videoTitles = false;
  bool _quickGuideDismissed = false;
  bool _quickExported = false;
  final GlobalKey _quickLibrary = GlobalKey();
  final GlobalKey _quickTimeline = GlobalKey();
  final GlobalKey _quickExport = GlobalKey();
  int? _waveformStamp;
  Map<String, WaveformEnvelope> _waveformCache = const {};
  late final TimelineFilmstrips _filmstrips = TimelineFilmstrips(clipDecoder: _clipDecoder);
  final GlobalKey<DocumentPreviewHostState> _exportStage = GlobalKey();
  late final ProviderContainer _selectionScope = ProviderContainer(
    overrides: [
      mediaImporterProvider.overrideWithValue(
        _GuardedMediaImporter(widget.importer ?? FileMediaImporter(), _showImportRefused),
      ),
      // The canvas key path, menus, and palette read undo/redo through this
      // seam — the same _travel the top bar's buttons run.
      historyActionsProvider.overrideWithValue(
        HistoryActions(
          canUndo: () => _history.canUndo,
          canRedo: () => _history.canRedo,
          undo: () => _travel(_history.undo),
          redo: () => _travel(_history.redo),
        ),
      ),
    ],
  );
  final GlobalKey<DocumentPreviewHostState> _previewHost = GlobalKey();
  late final SlidePreviewService _previews = SlidePreviewService(
    renderSlide: (slide) => _previewHost.currentState!.render(slide),
  );
  late final AutosaveController _autosave = AutosaveController(
    store: widget.autosave ?? AutosaveStore.platform(),
    key: widget.autosaveKey ?? widget.title,
    documentJson: () => _contents,
    documentDigest: () => _history.document.documentDigest,
    isDirty: () => _dirty,
    media: _referencedSessionBytes,
    onChanged: _onAutosave,
  );

  final SlideDeriver _deriver = SlideDeriver();
  late String _name = widget.title;
  late String _savedDigest = widget.savedDigest ?? widget.document.documentDigest;
  bool _saving = false;
  int _slide = 0;
  late SlideTransport _transport = _createTransport(0);
  bool _timelineOpen = true;

  /// Which workspace the editor is showing.
  ///
  /// Chrome, not document data: it lives beside the panel layout rather than
  /// in the deck, so switching cannot move a digest, cannot mark the deck
  /// unsaved, and cannot travel to whoever opens the file next.
  EditorWorkspace _workspace = EditorWorkspace.edit;
  bool _viewChanged = false;
  Future<void> _viewSave = Future.value();
  double _previewScale = 0.5;
  bool _bypassEffects = false;
  final ColourScopesController _colourScopes = ColourScopesController();
  final AudioMonitorController _audioMonitor = AudioMonitorController();
  late final AudioPreviewController _audioPreview = AudioPreviewController(
    monitor: _audioMonitor,
    platform: widget.audioPreviewPlatform,
    bytesFor: _sessionMedia.bytesFor,
    clipDecoder: _clipDecoder,
  );

  late final WebClipDecoder? _clipDecoder = kIsWeb ? createWebClipDecoder() : null;

  _LeftTab _leftTab = _LeftTab.slides;
  String? _editingMaster;
  Video? _presenting;
  SlideTransport? _videoTransport;
  late VideoTimebase _timebaseCache;
  String? _timebaseDigest;

  /// The editor-side digest moved since the last save (or open).
  bool get _dirty => _history.document.documentDigest != _savedDigest;

  /// Enters (or, with null, leaves) master-edit mode. The selection clears
  /// either way — synthetic view ids and document ids never mix.
  void _editMaster(String? name) {
    _selectionScope.read(selectionProvider.notifier).clear();
    setState(() => _editingMaster = name);
  }

  void _onHistory() => _documentChanged();

  void _onQueueChanged() => _queueChanged();

  void _onAutosave() => _autosaveChanged();

  /// The panels part lives outside this class; the shim keeps `setState`
  /// inside it.
  void _refresh(VoidCallback change) => setState(change);

  @override
  void initState() {
    super.initState();
    // A deck remembered in video mode arrives with its whole-video clock.
    _syncVideoTransport();
    _syncAudioPreview();
    _renderQueue.addListener(_onQueueChanged);
    _selectionScope.listen(inspectorTabRequestProvider, (_, _) {
      if (mounted) setState(() {});
    });
    unawaited(_loadViewSettings());
  }

  @override
  void dispose() {
    // Cancels the debounce only: a written autosave must survive anything
    // short of an explicit save or discard — that is the crash protection.
    _autosave.dispose();
    _audioPreview.dispose();
    _transport.dispose();
    _videoTransport?.dispose();
    _history.removeListener(_onHistory);
    _previews.dispose();
    _colourScopes.dispose();
    _renderQueue.dispose();
    _filmstrips.dispose();
    _audioMonitor.dispose();
    _selectionScope.dispose();
    super.dispose();
  }

  /// The shared playhead of [slide]: paused on the slide's settle frame
  /// with the slide's resolved length as its bound.
  SlideTransport _createTransport(int slide) {
    final derived = _deriver.derive(_history.document, slide);
    return SlideTransport(
      fps: _history.document.spec.fps,
      length: derived.totalFrames,
      initialFrame: derived.settleFrame,
    );
  }

  @override
  Widget build(BuildContext context) {
    final presenting = _presenting;
    final editor = _quickGuideOverlay(_editorBody(context));
    final withHost = Stack(
      fit: StackFit.expand,
      children: [
        // The hidden preview stage sits behind the editor, like the
        // presenter's own host sits behind its stage.
        Positioned(
          left: 0,
          top: 0,
          child: DocumentPreviewHost(
            key: _previewHost,
            document: _history.document,
            clipDecoder: _clipDecoder,
          ),
        ),
        // The export stage renders at the full canvas width, so the PNG
        // export ships real-size slides; idle it builds nothing.
        Positioned(
          left: 0,
          top: 0,
          child: DocumentPreviewHost(
            key: _exportStage,
            clipDecoder: _clipDecoder,
            document: _history.document,
            thumbWidth: _history.document.spec.size.width.toDouble(),
          ),
        ),
        editor,
      ],
    );
    if (presenting == null) return withHost;
    return Stack(
      fit: StackFit.expand,
      children: [
        withHost,
        FluvieSlides(presenting, onClose: () => setState(() => _presenting = null)),
      ],
    );
  }
}
