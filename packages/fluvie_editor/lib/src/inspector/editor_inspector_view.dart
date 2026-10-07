part of 'editor_inspector.dart';

/// The right panel: slide and background settings with nothing selected,
/// transform/arrange/style sections for a selection — every control
/// dispatches a command, so every change is undoable.
final class EditorInspector extends ConsumerWidget {
  /// Inspects slide [slide] of [document]; commands land in [onCommand].
  const EditorInspector({
    required this.document,
    required this.slide,
    required this.onCommand,
    super.key,
  });

  /// The deck being edited.
  final EditorDocument document;

  /// The slide on stage.
  final int slide;

  /// Receives every dispatched command.
  final void Function(EditorCommand command) onCommand;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(selectionProvider);
    final colors = context.colors;
    final tokenColors = tokenColorScopeFor(document, ref);
    final Widget body;
    if (selected.isEmpty) {
      body = WorkspaceScope.disclosureOf(context) == DisclosureLevel.minimal
          ? QuickDeckSection(
              document: document,
              slide: slide,
              onCommand: onCommand,
              colors: tokenColors,
            )
          : DeckSection(
              document: document,
              slide: slide,
              onCommand: onCommand,
              colors: tokenColors,
            );
    } else if (selected.length > 1) {
      body = Padding(
        padding: const EdgeInsets.all(12),
        child: OiLabel.body('${selected.length} elements selected', color: colors.textSubtle),
      );
    } else {
      body = _elementSection(
        context,
        selected.single,
        ref.watch(keyframeSelectionProvider),
        tokenColors,
      );
    }
    return ColoredBox(
      color: colors.surface,
      child: SingleChildScrollView(
        child: Padding(padding: const EdgeInsets.all(8), child: body),
      ),
    );
  }

  Widget _header(BuildContext context, String text) => Padding(
    padding: const EdgeInsets.only(top: 12, bottom: 4),
    child: OiLabel.small(text, color: context.colors.textSubtle),
  );

  Widget _elementSection(
    BuildContext context,
    String id,
    SelectedKeyframe? keyframe,
    TokenColorScope tokenColors,
  ) {
    final element = document.elementJson(id);
    if (element == null) {
      return Padding(
        padding: const EdgeInsets.all(12),
        child: OiLabel.body('Nothing here anymore', color: context.colors.textSubtle),
      );
    }
    // A null value in a patch removes its key — how a section clears an
    // optional prop, or scrubs one the spec rejects on a new variant.
    void patch(Map<String, Object?> changes, {String? mergeGroup}) {
      final merged = {...element, ...changes}..removeWhere((_, value) => value == null);
      onCommand(ReplaceElementCommand(id: id, element: merged, mergeGroup: mergeGroup));
    }

    final rawStyle = element['style'];
    final styleToken = rawStyle is Map<String, Object?> ? rawStyle['token'] : null;
    final styleRows = styleRowsFor(
      element,
      patch,
      colors: tokenColors,
      tokenStyle: styleToken is String ? document.spec.theme?.typeScale[styleToken] : null,
    );
    if (WorkspaceScope.disclosureOf(context) == DisclosureLevel.minimal) {
      return QuickElementSection(
        document: document,
        id: id,
        element: element,
        styleRows: styleRows,
        onCommand: onCommand,
      );
    }
    final transform = element['transform'];
    final fillSlot = document.fillSlotOf(id);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (element['type'] == 'Clip') ...[
          _header(context, 'Playback'),
          ClipSpeedSection(document: document, id: id, onCommand: onCommand),
        ],
        if (transform is Map<String, Object?>) ...[
          _header(context, 'Transform'),
          TransformSection(
            id: id,
            transform: transform,
            canvas: document.spec.size,
            onCommand: onCommand,
          ),
        ],
        if (element['type'] == 'Group') ...[
          _header(context, 'Block'),
          BlockSection(document: document, id: id, onCommand: onCommand),
        ],
        _header(context, 'Animate'),
        AnimateSection(document: document, slide: slide, elementId: id, onCommand: onCommand),
        if (keyframe != null && keyframe.elementId == id)
          KeyframeSection(document: document, selection: keyframe, onCommand: onCommand),
        if (slide > 0 && fillSlot == null && document.autoAnimateOn(slide)) ...[
          _header(context, 'Morph'),
          MorphSection(document: document, slide: slide, id: id, onCommand: onCommand),
        ],
        // A fill's z is the master's slot order — no Arrange for it.
        if (fillSlot == null) ...[
          _header(context, 'Arrange'),
          Row(
            children: [
              EditorTip(
                message: 'Bring forward',
                child: OiIconButton(
                  icon: OiIcons.arrowUp,
                  semanticLabel: 'Bring forward',
                  onTap: () => _reorder(id, 1),
                ),
              ),
              EditorTip(
                message: 'Send backward',
                child: OiIconButton(
                  icon: OiIcons.arrowDown,
                  semanticLabel: 'Send backward',
                  onTap: () => _reorder(id, -1),
                ),
              ),
            ],
          ),
        ] else ...[
          _header(context, 'Master'),
          OiLabel.small(
            'Fills slot "$fillSlot" of master "${document.sceneMasterName(slide)}"',
            color: context.colors.textSubtle,
          ),
        ],
        if (styleRows.isNotEmpty) ...[
          _header(context, 'Style'),
          OiPropertyGrid(properties: styleRows),
        ],
        if (element['type'] == 'Chart') ...[
          _header(context, 'Data'),
          ChartDataSection(element: element, patch: patch),
        ],
        if (element['type'] == 'Terminal') ...[
          _header(context, 'Lines'),
          TerminalLinesSection(element: element, patch: patch),
        ],
      ],
    );
  }

  void _reorder(String id, int delta) {
    final scene = document.sceneOfElement(id);
    if (scene == null) return;
    final order = document.elementIdsInScene(scene);
    final to = (order.indexOf(id) + delta).clamp(0, order.length - 1);
    onCommand(ReorderElementCommand(id: id, to: to));
  }
}
