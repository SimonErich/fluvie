part of 'editor_screen.dart';

extension _EditorScreenStage on _EditorScreenState {
  /// The normal deck stage: the interactive canvas over the current slide.
  Widget _stageCanvas(BuildContext context) => OiFileDropTarget(
    dropMessage: 'Drop media to insert it',
    onInternalDrop: (_, _) {},
    // coverage:ignore-start external drops need a real platform drag event and the pick and insert halves are unit tested via mediaPickFor and the asset panel
    onExternalDrop: (files) {
      if (files.isEmpty) return;
      unawaited(_insertDropped(files.first.name, files.first.bytes));
    },
    // coverage:ignore-end
    child: _previewStage(
      EditorCanvas(
        document: _history.document,
        clipDecoder: _clipDecoder,
        previewMaxEdge: _previewMaxEdge,
        bypassEffects: _bypassEffects,
        scopes: _workspace == EditorWorkspace.colour ? _colourScopes : null,
        slide: _slide,
        interactive: true,
        transport: _transport,
        onCommand: _history.dispatch,
        onShowSlide: _showSlide,
      ),
    ),
  );

  /// The band under the stage: the timeline and the speaker-notes strip, both
  /// spanning the surface rather than the stage column.
  ///
  /// Both size themselves — the timeline is a header strip until it is opened —
  /// so the band scrolls rather than stretching them. A user who drags the
  /// divider down to a sliver then sees less of the band instead of an overflow.
  Widget _bottomBand(BuildContext context) => SingleChildScrollView(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        TimelinePanel(
          document: _history.document,
          slide: _slide,
          transport: _transport,
          onCommand: _history.dispatch,
          onOpenChanged: (open) => _refresh(() => _timelineOpen = open),
        ),
        NotesEditor(document: _history.document, slide: _slide, onCommand: _history.dispatch),
      ],
    ),
  );

  /// Master-edit mode's stage: the same canvas machinery over the
  /// session's synthetic view.
  Widget _masterStage(MasterEditSession session) => MasterEditor(
    session: session,
    onCommand: _history.dispatch,
    onClose: () => _editMaster(null),
  );

  /// The right panel: the document inspector, or — in master-edit mode —
  /// the same inspector over the synthetic view with translated dispatch.
  Widget _inspector(MasterEditSession? session) {
    if (session == null) {
      return EditorInspector(
        document: _history.document,
        slide: _slide,
        onCommand: _history.dispatch,
      );
    }
    return EditorInspector(
      document: session.view,
      slide: 0,
      onCommand: (command) {
        final translated = session.translate(command);
        if (translated != null) _history.dispatch(translated);
      },
    );
  }

  /// The tile menu's template inserts: one item per gallery template, each
  /// inserting that template's first slide after the tile — tokens and
  /// masters the deck lacks merge in additively, as one undo step.
  List<OiMenuItem> _templateMenuItems(CommandScope scope) => [
    for (final template in builtinDeckTemplates)
      OiMenuItem(
        label: 'Insert template: ${template.name}',
        onTap: () {
          final scene = (template.deck['scenes']! as List).first! as Map<String, Object?>;
          final theme = template.deck['theme'];
          final masters = template.deck['masters'];
          scope.dispatch(
            InsertTemplateSlideCommand(
              scene: preparedTemplateScene(scope.document, scene),
              at: scope.slide + 1,
              theme: theme is Map<String, Object?> ? theme : null,
              masters: masters is Map<String, Object?> ? masters : null,
            ),
          );
          scope.showSlide(scope.slide + 1);
        },
      ),
  ];

  Widget _tab(BuildContext context, String label, _LeftTab tab) {
    final colors = context.colors;
    final active = _leftTab == tab;
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _refresh(() => _leftTab = tab),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: OiLabel.small(
            label,
            textAlign: TextAlign.center,
            color: active ? colors.text : colors.textSubtle,
          ),
        ),
      ),
    );
  }

  Widget _leftPanel(BuildContext context) {
    if (_workspace == EditorWorkspace.deliver) return _deliveryPanel();
    final colors = context.colors;
    return ColoredBox(
      color: colors.surface,
      child: SizedBox(
        width: 200,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                _tab(context, 'Slides', _LeftTab.slides),
                _tab(context, 'Layers', _LeftTab.layers),
                _tab(context, 'Theme', _LeftTab.theme),
                _tab(context, 'Titles', _LeftTab.titles),
              ],
            ),
            Expanded(
              child: switch (_leftTab) {
                _LeftTab.slides => SlideStrip(
                  document: _history.document,
                  current: _slide,
                  service: _previews,
                  // The canvas's clipboard, so a copied slide pastes
                  // across decks and app instances the same way.
                  clipboard: _selectionScope.read(editorClipboardProvider),
                  onSelect: _showSlide,
                  onCommand: _history.dispatch,
                  onEditMaster: _editMaster,
                  extraMenuItems: _templateMenuItems,
                ),
                _LeftTab.layers => LayersPanel(
                  document: _history.document,
                  slide: _slide,
                  onCommand: _history.dispatch,
                ),
                _LeftTab.titles => _titles(_slide, _transport.frame),
                _LeftTab.theme => ThemePanel(
                  document: _history.document,
                  onCommand: _history.dispatch,
                ),
              },
            ),
          ],
        ),
      ),
    );
  }
}
