part of 'editor_screen.dart';

extension _EditorScreenVideoStage on _EditorScreenState {
  /// The canvas and timeline share a clock, but the timeline occupies the
  /// shell's full-width bottom band rather than taking room from the canvas.
  Widget _videoStage(int scene) => _previewStage(
    EditorCanvas(
      document: _history.document,
      clipDecoder: _clipDecoder,
      previewMaxEdge: _previewMaxEdge,
      bypassEffects: _bypassEffects,
      scopes: _workspace == EditorWorkspace.colour ? _colourScopes : null,
      slide: scene,
      interactive: true,
      wholeDocument: true,
      transport: _videoTransport,
      settleFrame: _videoTimebase.settleFrameOf(scene),
      onCommand: _history.dispatch,
      onShowSlide: (slide) => _videoTransport!.seek(_videoTimebase.settleFrameOf(slide)),
    ),
  );

  /// The right panel: the inspector tab stack over the audio inspector (when
  /// an audio lane is selected) or the element/slide inspector — with the
  /// Effects tab mounted, so a chip can be dragged straight onto a bar in
  /// the timeline below.
  Widget _videoInspector(int scene) => InspectorTabs(
    request: _selectionScope.read(inspectorTabRequestProvider),
    inspector: Consumer(
      builder: (context, ref, _) {
        final audio = ref.watch(audioSelectionProvider);
        if (audio == null) {
          return EditorInspector(
            document: _history.document,
            slide: scene,
            onCommand: _history.dispatch,
          );
        }
        return ColoredBox(
          color: context.colors.surface,
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: AudioTrackSection(
                document: _history.document,
                selection: audio,
                timebase: _videoTimebase,
                onCommand: _history.dispatch,
              ),
            ),
          ),
        );
      },
    ),
    panels: {
      ..._workspacePanels(video: true),
      InspectorTab.effects: EffectsPanel(
        document: _history.document,
        onCommand: _history.dispatch,
        playheadProgress: _videoEffectPlayheadProgress,
      ),
    },
  );

  /// Where the whole-video playhead sits inside [id]'s alive-window: the
  /// video transport already counts absolute frames.
  double? _videoEffectPlayheadProgress(String id) {
    final transport = _videoTransport;
    if (transport == null) return null;
    return _effectProgressOf(id, transport.frame);
  }
}
