part of 'editor_screen.dart';

extension _EditorScreenWorkspaces on _EditorScreenState {
  int? get _previewMaxEdge {
    if (_previewScale == 1) return null;
    final size = _history.document.spec.size;
    final edge = size.width > size.height ? size.width : size.height;
    return (edge * _previewScale).round().clamp(2, 8192);
  }

  Widget _previewStage(Widget canvas) => Column(
    children: [
      if (_workspace == EditorWorkspace.quick && !_quickGuideDismissed)
        QuickStartHint(
          step: quickStartStep(_history.document, exported: _quickExported),
          onDismiss: () {
            _viewChanged = true;
            _refresh(() => _quickGuideDismissed = true);
            unawaited(_saveViewSettings());
          },
        ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Wrap(
          spacing: 8,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            OiSegmentedControl<double>(
              semanticLabel: 'Preview quality',
              selected: _previewScale,
              segments: const [
                OiSegment(value: 1, label: 'Full'),
                OiSegment(value: 0.5, label: 'Half'),
                OiSegment(value: 0.25, label: 'Quarter'),
              ],
              onChanged: (scale) {
                _viewChanged = true;
                _refresh(() => _previewScale = scale);
                unawaited(_saveViewSettings());
              },
            ),
            OiButton.ghost(
              label: _bypassEffects ? 'Draft · effects bypassed' : 'Effects on',
              onTap: () {
                _viewChanged = true;
                _refresh(() => _bypassEffects = !_bypassEffects);
                unawaited(_saveViewSettings());
              },
            ),
          ],
        ),
      ),
      _audioStatus(),
      if (_videoMode) _filmstripStatus(),
      Expanded(child: canvas),
    ],
  );

  Map<InspectorTab, Widget> _workspacePanels({required bool video}) => {
    InspectorTab.animation: AnimationPanel(
      document: _history.document,
      onCommand: _history.dispatch,
    ),
    InspectorTab.colour: ColourPanel(
      document: _history.document,
      onCommand: _history.dispatch,
      playheadProgress: video ? _videoEffectPlayheadProgress : _effectPlayheadProgress,
      scopes: _colourScopes,
      onImportLut: _importLut,
    ),
    InspectorTab.audio: ValueListenableBuilder<int>(
      valueListenable: (video ? _videoTransport! : _transport).frames,
      builder: (context, frame, _) => ListenableBuilder(
        listenable: _audioPreview,
        builder: (context, _) => AudioWorkspacePanel(
          document: _history.document,
          envelopes: _audioPreview.envelopes,
          clipMetadata: _audioPreview.clipMetadata,
          timebase: _videoTimebase,
          currentFrame: video ? frame : _videoTimebase.sceneSpans[_slide].start + frame,
          onCommand: _history.dispatch,
          monitor: _audioMonitor,
        ),
      ),
    ),
  };

  Widget _quickGuideOverlay(Widget child) {
    if (_workspace != EditorWorkspace.quick || _quickGuideDismissed || !_videoMode) return child;
    final step = quickStartStep(_history.document, exported: _quickExported);
    if (step == QuickStartStep.complete) return child;
    final target = switch (step) {
      QuickStartStep.importMedia || QuickStartStep.place => _quickLibrary,
      QuickStartStep.trim => _quickTimeline,
      QuickStartStep.export || QuickStartStep.complete => _quickExport,
    };
    return Stack(
      fit: StackFit.expand,
      children: [
        child,
        // OiSpotlight's stock overlay intercepts clicks; guidance must leave all
        // editing actions reachable, including the action that advances its gate.
        IgnorePointer(
          child: OiSpotlight(
            target: target,
            overlayColor: const Color(0x10000000),
            child: const SizedBox.expand(),
          ),
        ),
      ],
    );
  }

  Map<String, WaveformEnvelope> get _timelineWaveforms {
    final envelopes = _audioPreview.envelopes;
    final metadata = _audioPreview.clipMetadata;
    final stamp = Object.hash(
      _history.document.renderDigest,
      Object.hashAll(envelopes.entries.map((entry) => (entry.key, entry.value))),
      Object.hashAll(metadata.entries.map((entry) => (entry.key, entry.value))),
      Object.hashAll(_audioMonitor.soloLaneIds),
    );
    if (stamp != _waveformStamp) {
      _waveformStamp = stamp;
      _waveformCache = timelineAudioEnvelopes(
        _history.document,
        _videoTimebase,
        envelopes,
        clipMetadata: metadata,
        monitor: _audioMonitor,
      );
    }
    return _waveformCache;
  }

  Widget _sourcePreview(MediaStoreEntry entry, int frame) => Column(
    children: [
      Expanded(
        child: entry.kind == MediaStoreKind.audio
            ? Center(child: OiLabel.body(entry.name))
            : SourceMediaPreview(entry: entry, frame: frame, clipDecoder: _clipDecoder),
      ),
      if (entry.kind != MediaStoreKind.image)
        ListenableBuilder(
          listenable: _audioPreview,
          builder: (context, _) => Padding(
            padding: const EdgeInsets.all(4),
            child: Column(
              children: [
                OiLabel.small(_audioPreview.channelLabel),
                OiButton.secondary(
                  fullWidth: true,
                  label: _audioPreview.auditioning ? 'Stop listening' : 'Listen from playhead',
                  onTap: _audioPreview.auditioning
                      ? _audioPreview.stopAudition
                      : () => unawaited(_audioPreview.audition(entry, frame: frame)),
                ),
              ],
            ),
          ),
        ),
    ],
  );

  Widget _titles(int scene, int localFrame) => TitlesPanel(
    document: _history.document,
    scene: scene,
    frame: localFrame,
    lane: _selectionScope.read(activeTimelineLaneProvider),
    onCommand: _history.dispatch,
    onInserted: _selectionScope.read(selectionProvider.notifier).select,
  );
}
